import AVFoundation
import AudioToolbox
import Foundation
import LaFleurCore

/// Joue une face de cassette sur la sortie choisie, au millième de seconde près :
/// blanc de début, morceaux, blancs entre eux, arrêt net à la fin (et, en auto-reverse, attente de
/// la fin de bande puis enchaînement de la face B). C'est l'app qui joue les fichiers : rien ne dépasse.
@MainActor
final class MoteurEnregistrement: ObservableObject {
    enum Etat: Equatable {
        case pret
        case compteARebours(Int)
        case lecture
        case pause
        case finDeFace
        case erreur(String)
    }

    @Published private(set) var etat: Etat = .pret
    @Published private(set) var face: Face = .a
    /// Temps écoulé sur la face, en secondes.
    @Published private(set) var position: TimeInterval = 0
    @Published private(set) var segment: Deroule.Segment?
    /// Niveaux crête gauche / droite en dBFS.
    @Published private(set) var niveaux: (gauche: Float, droite: Float) = (-90, -90)
    @Published private(set) var tonaliteActive = false

    private(set) var deroule = Deroule([], ReglagesPlatine(), cassette: Cassette())
    private(set) var pistes: [Piste] = []
    private var projet: Projet?
    private var reglages = ReglagesPlatine()

    private let moteur = AVAudioEngine()
    private var lecteurs: [AVAudioPlayerNode] = []
    private var fichiers: [AVAudioFile] = []
    private var source: AVAudioSourceNode?
    private var origineHote: UInt64 = 0
    private var originePosition: TimeInterval = 0
    private var horloge: Task<Void, Never>?
    private var decompte: Task<Void, Never>?
    private var tapInstalle = false

    // MARK: Préparation

    /// Charge une face : ouvre les fichiers, règle la sortie audio et démarre le moteur (silencieux).
    func charger(_ projet: Projet, face: Face, reglages: ReglagesPlatine, sortieUID: String?, egaliser: Bool) {
        arreterTout()
        self.projet = projet; self.face = face; self.reglages = reglages
        sortieCourante = sortieUID; egalisation = egaliser
        pistes = projet.pistes(face)
        let enchainer = reglages.type == .autoReverse && face == .a && !projet.faceB.isEmpty
        deroule = Deroule(pistes, reglages, cassette: projet.cassette, enchainerFaceB: enchainer)
        position = 0; segment = nil
        do {
            moteur.stop()
            try choisirSortie(sortieUID)
            for n in lecteurs { moteur.detach(n) }
            lecteurs = []; fichiers = []
            for p in pistes {
                guard let url = p.fichier else { throw ErreurMoteur.fichierManquant(p.morceau.titre) }
                let f = try AVAudioFile(forReading: url)
                let n = AVAudioPlayerNode()
                moteur.attach(n)
                moteur.connect(n, to: moteur.mainMixerNode, format: f.processingFormat)
                fichiers.append(f); lecteurs.append(n)
            }
            if egaliser { egaliserVolumes() }
            installerTap()
            moteur.prepare()
            try moteur.start()
            etat = .pret
        } catch {
            etat = .erreur(error.localizedDescription)
        }
    }

    enum ErreurMoteur: LocalizedError {
        case fichierManquant(String), sortie
        var errorDescription: String? {
            switch self {
            case .fichierManquant(let t): "Pas de fichier audio pour « \(t) ». Associe-le dans l'écran Mixtape."
            case .sortie: "Impossible d'utiliser cette sortie audio."
            }
        }
    }

    private func choisirSortie(_ uid: String?) throws {
        guard var id = SortiesAudio.trouver(uid: uid), let unite = moteur.outputNode.audioUnit else { return }
        let st = AudioUnitSetProperty(unite, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                                      &id, UInt32(MemoryLayout<AudioDeviceID>.size))
        if st != noErr { throw ErreurMoteur.sortie }
    }

    /// Option « égaliser le volume » : baisse les morceaux les plus forts au niveau du plus calme (−12 dB au plus).
    private func egaliserVolumes() {
        let niveaux = fichiers.map(Self.niveauMoyen)
        guard let cible = niveaux.min() else { return }
        for (n, db) in zip(lecteurs, niveaux) { n.volume = powf(10, max(-12, cible - db) / 20) }
    }

    /// Niveau moyen (RMS) d'un fichier en dBFS, lu par blocs d'une seconde.
    private static func niveauMoyen(_ f: AVAudioFile) -> Float {
        let bloc = AVAudioFrameCount(f.processingFormat.sampleRate)
        guard let tampon = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: bloc) else { return -20 }
        var somme: Double = 0, total: Double = 0
        f.framePosition = 0
        while f.framePosition < f.length, (try? f.read(into: tampon)) != nil, tampon.frameLength > 0 {
            guard let canaux = tampon.floatChannelData else { break }
            for c in 0..<Int(tampon.format.channelCount) {
                for i in stride(from: 0, to: Int(tampon.frameLength), by: 4) { let v = Double(canaux[c][i]); somme += v * v; total += 1 }
            }
        }
        f.framePosition = 0
        return total > 0 ? Float(10 * log10(max(somme / total, 1e-10))) : -20
    }

    // MARK: Commandes

    /// Compte à rebours (pour relâcher la pause de la platine), puis lecture depuis le début.
    func demarrer() { lancerApresDecompte(depuis: 0) }

    func pause() {
        guard etat == .lecture else { return }
        let p = positionActuelle()
        arreterLecteurs()
        position = p
        etat = .pause
    }

    func reprendre() { if etat == .pause { lancerApresDecompte(depuis: position) } }

    func arreter() {
        arreterTout()
        etat = .pret
        position = 0; segment = nil
    }

    private func lancerApresDecompte(depuis t: TimeInterval) {
        decompte?.cancel()
        let n = reglages.compteARebours
        decompte = Task { [weak self] in
            for s in stride(from: n, to: 0, by: -1) {
                self?.etat = .compteARebours(s)
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            self?.programmer(depuis: t)
        }
    }

    // MARK: Programmation précise

    private static func secondesVersHote(_ s: TimeInterval) -> UInt64 {
        var info = mach_timebase_info_data_t(); mach_timebase_info(&info)
        return UInt64(s * 1_000_000_000 * Double(info.denom) / Double(info.numer))
    }

    private static func hoteVersSecondes(_ h: UInt64) -> TimeInterval {
        var info = mach_timebase_info_data_t(); mach_timebase_info(&info)
        return Double(h) * Double(info.numer) / Double(info.denom) / 1_000_000_000
    }

    /// Programme toutes les pistes restantes à partir de l'instant `t0` de la face.
    private func programmer(depuis t0: TimeInterval) {
        arreterLecteurs()
        if !moteur.isRunning { try? moteur.start() }
        // Petite avance pour que tout soit programmé avant le premier son.
        let debut = mach_absolute_time() + Self.secondesVersHote(0.3)
        for (i, (n, f)) in zip(lecteurs, fichiers).enumerated() {
            guard let seg = deroule.segments.first(where: { $0.genre == .piste(i) }), seg.fin > t0 else { continue }
            let taux = f.processingFormat.sampleRate
            let decalage = max(0, t0 - seg.debut)
            let premiere = AVAudioFramePosition(decalage * taux)
            guard premiere < f.length else { continue }
            n.scheduleSegment(f, startingFrame: premiere, frameCount: AVAudioFrameCount(f.length - premiere), at: nil)
            n.play(at: AVAudioTime(hostTime: debut + Self.secondesVersHote(max(0, seg.debut - t0))))
        }
        origineHote = debut; originePosition = t0
        position = t0
        etat = .lecture
        lancerHorloge()
    }

    private func positionActuelle() -> TimeInterval {
        let maintenant = mach_absolute_time()
        guard maintenant > origineHote else { return originePosition }
        return originePosition + Self.hoteVersSecondes(maintenant - origineHote)
    }

    private func lancerHorloge() {
        horloge?.cancel()
        horloge = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.etat == .lecture else { return }
                let t = self.positionActuelle()
                self.position = min(t, self.deroule.fin)
                self.segment = self.deroule.segment(a: t)
                if t >= self.deroule.fin { self.finDeFace(); return }
                try? await Task.sleep(for: .milliseconds(30))
            }
        }
    }

    private func finDeFace() {
        arreterLecteurs()
        position = deroule.fin; segment = nil
        // Auto-reverse : la platine vient de se retourner, la face B part toute seule.
        if let projet, face == .a, reglages.type == .autoReverse, !projet.faceB.isEmpty {
            let uid = sortieCourante
            charger(projet, face: .b, reglages: reglages, sortieUID: uid, egaliser: egalisation)
            programmer(depuis: 0)
            return
        }
        etat = .finDeFace
    }

    /// Mémorisés pour l'enchaînement automatique de la face B.
    var sortieCourante: String?
    var egalisation = false

    private func arreterLecteurs() {
        horloge?.cancel(); horloge = nil
        for n in lecteurs { n.stop() }
        niveaux = (-90, -90)
    }

    private func arreterTout() {
        decompte?.cancel(); decompte = nil
        arreterLecteurs()
    }

    // MARK: VU-mètre

    private func installerTap() {
        guard !tapInstalle else { return }
        tapInstalle = true
        moteur.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] tampon, _ in
            guard let canaux = tampon.floatChannelData else { return }
            let n = Int(tampon.frameLength), nc = Int(tampon.format.channelCount)
            func crete(_ c: Int) -> Float {
                var m: Float = 0
                for i in 0..<n { m = max(m, abs(canaux[c][i])) }
                return m > 0 ? 20 * log10(m) : -90
            }
            let g = crete(0), d = nc > 1 ? crete(1) : g
            Task { @MainActor [weak self] in self?.niveaux = (g, d) }
        }
    }

    // MARK: Tonalité de réglage

    /// Signal à 1 kHz, −12 dBFS, pour régler le niveau d'entrée de la platine.
    func basculerTonalite() {
        if source == nil {
            var phase = 0.0
            let taux = moteur.outputNode.outputFormat(forBus: 0).sampleRate > 0 ? moteur.outputNode.outputFormat(forBus: 0).sampleRate : 48000
            let pas = 2 * Double.pi * 1000 / taux
            let s = AVAudioSourceNode { _, _, nb, liste -> OSStatus in
                let tampons = UnsafeMutableAudioBufferListPointer(liste)
                for i in 0..<Int(nb) {
                    let v = Float(0.25 * sin(phase))
                    phase += pas
                    if phase > 2 * Double.pi { phase -= 2 * Double.pi }
                    for t in tampons { t.mData?.assumingMemoryBound(to: Float.self)[i] = v }
                }
                return noErr
            }
            moteur.attach(s)
            moteur.connect(s, to: moteur.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: taux, channels: 2))
            s.volume = 0
            source = s
            installerTap()
        }
        if !moteur.isRunning { moteur.prepare(); try? moteur.start() }
        tonaliteActive.toggle()
        source?.volume = tonaliteActive ? 1 : 0
    }
}
