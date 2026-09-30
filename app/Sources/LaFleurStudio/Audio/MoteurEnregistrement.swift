import AVFoundation
import AudioToolbox
import os
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
            case .fichierManquant(let t): String(localized: "Pas de fichier audio pour « \(t) ». Associe-le dans l'écran Mixtape.")
            case .sortie: String(localized: "Impossible d'utiliser cette sortie audio.")
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
        Programmation.programmer(lecteurs: lecteurs, fichiers: fichiers, deroule: deroule, depuis: t0) {
            AVAudioTime(hostTime: debut + Self.secondesVersHote($0))
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

    /// Niveaux mesurés sur le fil audio (RMS en dBFS), lus par l'affichage à 30 images/s.
    private let mesure = MesureNiveaux()
    private var affichageVU: Timer?

    private func installerTap() {
        if affichageVU == nil {
            affichageVU = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.rafraichirVU() }
            }
        }
        guard !tapInstalle else { return }
        tapInstalle = true
        let mesure = self.mesure
        moteur.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { tampon, _ in
            guard let canaux = tampon.floatChannelData, tampon.frameLength > 0 else { return }
            let n = Int(tampon.frameLength), nc = Int(tampon.format.channelCount)
            func rms(_ c: Int) -> Float {
                var somme: Float = 0
                for i in 0..<n { somme += canaux[c][i] * canaux[c][i] }
                let v = (somme / Float(n)).squareRoot()
                return v > 0 ? 20 * log10(v) : -90
            }
            mesure.ecrire(rms(0), nc > 1 ? rms(1) : rms(0))
        }
    }

    /// Balistique d'un vrai VU-mètre (~300 ms) ; aiguilles au repos quand rien ne joue.
    private func rafraichirVU() {
        let actif = etat == .lecture || tonaliteActive
        let (g, d) = actif ? mesure.lire() : (-90, -90)
        let k: Float = 1 - exp(-1.0 / 30 / 0.3)
        let ng = niveaux.gauche + (max(g, -60) - niveaux.gauche) * k
        let nd = niveaux.droite + (max(d, -60) - niveaux.droite) * k
        if abs(ng - niveaux.gauche) > 0.05 || abs(nd - niveaux.droite) > 0.05 { niveaux = (ng, nd) }
    }

    // MARK: Sortie audio

    /// Change la sortie (réglages) : le moteur est redirigé tout de suite, sauf pendant un enregistrement.
    func changerSortie(_ uid: String?) {
        sortieCourante = uid
        switch etat { case .lecture, .compteARebours: return; default: break }
        let relancer = moteur.isRunning
        moteur.stop()
        try? choisirSortie(uid)
        if relancer { moteur.prepare(); try? moteur.start() }
    }

    // MARK: Tonalité de réglage

    /// Signal à 1 kHz, −12 dBFS RMS (0 VU sur l'app), pour régler le niveau d'entrée de la platine.
    func basculerTonalite() {
        if source == nil {
            var phase = 0.0
            let taux = 48000.0
            let pas = 2 * Double.pi * 1000 / taux
            // Amplitude crête 0,355 → −12 dBFS RMS.
            let s = AVAudioSourceNode { _, _, nb, liste -> OSStatus in
                let tampons = UnsafeMutableAudioBufferListPointer(liste)
                for i in 0..<Int(nb) {
                    let v = Float(0.355 * sin(phase))
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
        if !moteur.isRunning {
            try? choisirSortie(sortieCourante)
            moteur.prepare(); try? moteur.start()
        }
        tonaliteActive.toggle()
        source?.volume = tonaliteActive ? 1 : 0
    }
}

/// Dernières mesures du fil audio, partagées avec l'affichage (protégées par un verrou).
final class MesureNiveaux: @unchecked Sendable {
    private var verrou = os_unfair_lock()
    private var gauche: Float = -90, droite: Float = -90
    func ecrire(_ g: Float, _ d: Float) { os_unfair_lock_lock(&verrou); gauche = g; droite = d; os_unfair_lock_unlock(&verrou) }
    func lire() -> (Float, Float) { os_unfair_lock_lock(&verrou); defer { os_unfair_lock_unlock(&verrou) }; return (gauche, droite) }
}
