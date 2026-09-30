import LaFleurCore
import SwiftUI

struct EcranEnregistrer: View {
    @EnvironmentObject var etat: EtatApp
    @EnvironmentObject var moteur: MoteurEnregistrement
    @State private var face: Face = .a
    @State private var checklist = [false, false, false, false, false]

    private var pistes: [Piste] { etat.projet.pistes(face) }
    private var enCours: Bool {
        switch moteur.etat { case .lecture, .compteARebours, .pause: true; default: false }
    }
    private var pisteCourante: Int? { if case .piste(let i) = moteur.segment?.genre { i } else { nil } }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Platine(face: moteur.face, pisteCourante: pisteCourante)
                bande
                listePistes
            }
            VStack(alignment: .leading, spacing: 14) {
                Groupe(titre: "Face") {
                    Picker("", selection: $face) {
                        Text("Face A").tag(Face.a); Text("Face B").tag(Face.b)
                    }
                    .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden().disabled(enCours)
                }
                Groupe(titre: "Avant de lancer") {
                    let c = etat.projet.cassette
                    Toggle("Sortie du Mac → LINE IN de la platine", isOn: $checklist[0]).toggleStyle(.checkbox)
                    Toggle("Niveau réglé avec la tonalité", isOn: $checklist[1]).toggleStyle(.checkbox)
                    Toggle("Bande rembobinée", isOn: $checklist[2]).toggleStyle(.checkbox)
                    Toggle("Platine sur \([c.bande.nom, c.reducteur == .aucun ? nil : c.reducteur.nom].compactMap { $0 }.joined(separator: ", "))", isOn: $checklist[3]).toggleStyle(.checkbox)
                    Toggle("Mode Concentration activé", isOn: $checklist[4]).toggleStyle(.checkbox)
                    Button(moteur.tonaliteActive ? "Couper la tonalité" : "Tonalité 1 kHz") { moteur.basculerTonalite() }
                        .buttonStyle(.w98).disabled(enCours)
                }
                Groupe(titre: "Déroulé") {
                    Text("1. Compte à rebours \(etat.prefs.platine.compteARebours) s : relâche la pause")
                    Text("2. Blanc de début : \(Int(etat.prefs.platine.amorce)) s")
                    Text("3. Les morceaux, \(Int(etat.prefs.platine.blanc)) s de blanc entre chacun")
                    Text("4. Arrêt net à la fin de la face")
                    Text(etat.prefs.platine.type == .autoReverse ? "5. Fin de bande, inversion, face B automatique" : "5. « Retourne la cassette »")
                }
                message
            }
            .frame(width: 290)
        }
        .onAppear(perform: charger)
        .onChange(of: face) { charger() }
        .onChange(of: etat.projet) { if !enCours { charger() } }
        .onChange(of: moteur.face) { face = moteur.face }
    }

    private func charger() {
        guard !enCours else { return }
        moteur.charger(etat.projet, face: face, reglages: etat.prefs.platine, sortieUID: etat.prefs.sortieAudioUID,
                       egaliser: etat.prefs.egaliserVolume)
    }

    private var bande: some View {
        let total = Double(etat.projet.cassette.longueur.minutesParFace * 60)
        return VStack(alignment: .leading, spacing: 4) {
            HStack { Text("Bande utilisée").bold(); Spacer(); Text("\(formaterDuree(moteur.position)) / \(formaterDuree(total))") }
            Blocs(valeur: moteur.position, total: total)
        }
    }

    private var listePistes: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(pistes.enumerated()), id: \.element.id) { i, p in
                    let fait = (pisteCourante.map { i < $0 } ?? false) || moteur.etat == .finDeFace
                    let actif = pisteCourante == i
                    HStack {
                        Text(actif ? "En cours" : fait ? "Fait" : "À venir").frame(width: 70, alignment: .leading)
                        Text("\(i + 1). \(p.morceau.titre)").lineLimit(1)
                        Spacer()
                        if p.fichier == nil { Text("pas de fichier").foregroundStyle(W98.rouge) }
                        Text(formaterDuree(p.duree)).monospacedDigit()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .foregroundStyle(actif ? .white : fait ? W98.grisFonce : .black)
                    .background(actif ? W98.bleu : .clear)
                }
            }
        }
        .frame(maxHeight: .infinity).creux()
    }

    @ViewBuilder private var message: some View {
        switch moteur.etat {
        case .compteARebours(let s):
            BulleClaude(cle: "Relâche la pause de la platine… \(s)")
        case .finDeFace:
            VStack(alignment: .leading, spacing: 8) {
                BulleClaude(cle: moteur.face == .a
                    ? "Face A terminée. Arrête la platine, retourne la cassette, puis remets-la en ENREGISTREMENT + PAUSE."
                    : "Face B terminée. C'est dans la boîte ✿ Arrête la platine.")
                if moteur.face == .a && !etat.projet.faceB.isEmpty {
                    Button("Préparer la face B") { etat.projet.enregistree.insert(.a); face = .b; moteur.arreter(); charger() }.buttonStyle(.w98Gras)
                } else {
                    Button("Terminer") { etat.projet.enregistree.insert(moteur.face); moteur.arreter() }.buttonStyle(.w98Gras)
                }
            }
        case .erreur(let m):
            Text("⚠︎ " + m).foregroundStyle(W98.rouge).fixedSize(horizontal: false, vertical: true)
        default:
            if pistes.contains(where: { $0.fichier == nil }) {
                Text("⚠︎ Des morceaux n'ont pas de fichier audio : associe-les dans l'écran Mixtape.").foregroundStyle(W98.rouge)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !Faces.tient(pistes, etat.projet.cassette, etat.prefs.platine) {
                Text("⚠︎ Cette face dépasse la bande : la fin serait coupée.").foregroundStyle(W98.rouge)
            }
        }
    }
}

// MARK: - La platine : cassette, VU-mètres, compteur, touches

private struct Platine: View {
    @EnvironmentObject var etat: EtatApp
    @EnvironmentObject var moteur: MoteurEnregistrement
    let face: Face
    let pisteCourante: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                CassetteDessin(projet: etat.projet, face: face, tourne: moteur.etat == .lecture,
                               progression: moteur.deroule.fin > 0 ? moteur.position / moteur.deroule.fin : 0)
                    .frame(width: 281, height: 179).padding(8).creux(Color(white: 0.12))
                VUMetre(canal: String(localized: "GAUCHE"), dbfs: moteur.niveaux.gauche)
                VUMetre(canal: String(localized: "DROITE"), dbfs: moteur.niveaux.droite)
            }
            HStack(spacing: 16) {
                Text(String(format: "%04d", Int(moteur.position)))
                    .font(W98.lcd).foregroundStyle(Color(red: 0.49, green: 1, blue: 0.42))
                    .padding(.horizontal, 12).padding(.vertical, 2).creux(Color(red: 0.05, green: 0.1, blue: 0.05))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(formaterDuree(moteur.position)) / \(formaterDuree(moteur.deroule.fin)) · FACE \(face.rawValue)")
                    Text(ligneEtat).lineLimit(1)
                }
                .font(.system(size: 14, design: .monospaced))
                Spacer()
                Touche(symbole: "circle.fill", couleur: W98.rouge, aide: "Enregistrer (démarrer la face)", enfoncee: moteur.etat == .lecture) { moteur.demarrer() }
                    .disabled(moteur.etat != .pret || moteur.pistes.isEmpty)
                Touche(symbole: "pause.fill", aide: moteur.etat == .pause ? "Reprendre" : "Pause", enfoncee: moteur.etat == .pause) {
                    moteur.etat == .pause ? moteur.reprendre() : moteur.pause()
                }
                Touche(symbole: "stop.fill", aide: "Stop") { moteur.arreter() }
            }
        }
        .padding(16).relief()
    }

    private var ligneEtat: String {
        let pistes = etat.projet.pistes(face)
        switch moteur.segment?.genre {
        case .piste(let i)?:
            let p = pistes.indices.contains(i) ? pistes[i] : nil
            let debut = moteur.deroule.debut(piste: i) ?? 0
            return "\(i + 1)/\(pistes.count) \(p?.morceau.titre.uppercased() ?? "")  \(formaterDuree(moteur.position - debut)) / \(formaterDuree(p?.duree ?? 0))"
        case .amorce?: return String(localized: "BLANC DE DÉBUT DE BANDE")
        case .blanc?: return String(localized: "BLANC ENTRE LES MORCEAUX")
        case .finDeBande?: return String(localized: "BOUT DE BANDE DANS \(formaterDuree((moteur.segment?.fin ?? 0) - moteur.position))")
        case .inversion?: return String(localized: "INVERSION DE LA PLATINE…")
        case nil:
            switch moteur.etat {
            case .compteARebours(let s): return String(localized: "RELÂCHE LA PAUSE… \(s)")
            case .pause: return "PAUSE"
            case .finDeFace: return String(localized: "FACE \(face.rawValue) TERMINÉE")
            default: return String(localized: "PRÊT · \(pistes.count) MORCEAUX")
            }
        }
    }
}

private struct Touche: View {
    let symbole: String
    var couleur: Color = .black
    let aide: String
    var enfoncee = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbole).font(.system(size: 20)).foregroundStyle(couleur)
                .frame(width: 60, height: 44).background(W98.gris).overlay(Biseau(creux: enfoncee))
        }
        .buttonStyle(.plain).help(aide).accessibilityLabel(aide)
    }
}

/// VU-mètre à aiguille : 0 VU = −12 dBFS RMS (le niveau de la tonalité de réglage).
private struct VUMetre: View {
    let canal: String
    let dbfs: Float

    /// Graduations : valeur VU → angle en degrés.
    private static let echelle: [(Double, Double)] = [(-20, -50), (-10, -35), (-7, -24), (-5, -14), (-3, -4), (-1, 8), (0, 16), (1, 26), (2, 36), (3, 50)]

    private static func angle(_ vu: Double) -> Double {
        let v = min(3, max(-20, vu))
        for (a, b) in zip(echelle, echelle.dropFirst()) where v <= b.0 {
            return a.1 + (v - a.0) / (b.0 - a.0) * (b.1 - a.1)
        }
        return 50
    }

    var body: some View {
        VStack(spacing: 4) {
            Canvas { ctx, taille in
                let c = CGPoint(x: taille.width / 2, y: taille.height - 12), r = min(taille.width / 2 - 20, taille.height - 30)
                func point(_ deg: Double, _ rr: Double) -> CGPoint {
                    let t = (deg - 90) * .pi / 180
                    return CGPoint(x: c.x + rr * cos(t), y: c.y + rr * sin(t))
                }
                for (v, a) in Self.echelle {
                    var p = Path(); p.move(to: point(a, r)); p.addLine(to: point(a, r + 8))
                    let coul: Color = v > 0 ? W98.rouge : .black
                    ctx.stroke(p, with: .color(coul), lineWidth: 1.5)
                    ctx.draw(Text(v > 0 ? "+\(Int(v))" : "\(Int(v))").font(.system(size: 9)).foregroundColor(coul), at: point(a, r + 17))
                }
                var arc = Path()
                arc.addArc(center: c, radius: r, startAngle: .degrees(-140), endAngle: .degrees(-74), clockwise: false)
                ctx.stroke(arc, with: .color(.black), lineWidth: 2)
                var rouge = Path()
                rouge.addArc(center: c, radius: r, startAngle: .degrees(-74), endAngle: .degrees(-40), clockwise: false)
                ctx.stroke(rouge, with: .color(W98.rouge), lineWidth: 5)
                ctx.draw(Text("VU").font(.system(size: 16, weight: .bold)), at: CGPoint(x: c.x, y: c.y - r * 0.35))
                var aiguille = Path(); aiguille.move(to: c); aiguille.addLine(to: point(Self.angle(Double(dbfs) + 12), r + 4))
                ctx.stroke(aiguille, with: .color(.black), lineWidth: 2)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)), with: .color(.black))
            }
            .frame(width: 220, height: 150).creux(Color(red: 0.957, green: 0.925, blue: 0.824))
            
            Text(canal).bold()
        }
    }
}

/// La K7 dessinée avec l'étiquette du projet ; les bobines tournent pendant l'enregistrement.
/// La K7 de la platine : la même étiquette que dans l'écran Jaquette, bobines visibles par la fenêtre.
/// Les bobines tournent pendant l'enregistrement et la bande passe de gauche à droite au fil de la face.
struct CassetteDessin: View {
    let projet: Projet
    let face: Face
    let tourne: Bool
    let progression: Double
    var u: CGFloat = 2.8

    // Positions en mm dans la coque (100,4 × 63,8 mm).
    private let etiquette = CGPoint(x: 5.7, y: 4.5)
    private var fenetre: CGRect {
        let f = Gabarits.fenetreEtiquette
        return CGRect(x: etiquette.x + f.x, y: etiquette.y + f.y, width: f.largeur, height: f.hauteur)
    }

    var body: some View {
        let mise = Mise(projet: projet, design: projet.design ?? Design())
        let p = max(0, min(1, progression))
        ZStack(alignment: .topLeading) {
            // Coque
            RoundedRectangle(cornerRadius: 3 * u).fill(Color(red: 0.07, green: 0.08, blue: 0.1))
            // Fenêtre : la bande vue à travers le plastique fumé
            TimelineView(.animation(paused: !tourne)) { contexte in
                let angle = tourne ? contexte.date.timeIntervalSinceReferenceDate * 200 : 0
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(Color(red: 0.16, green: 0.13, blue: 0.11))
                    Bobine(angle: angle, remplissage: 1 - p, u: u).offset(x: (29 - fenetre.minX) * u, y: (fenetre.height / 2) * u)
                    Bobine(angle: angle, remplissage: p, u: u).offset(x: (71.4 - fenetre.minX) * u, y: (fenetre.height / 2) * u)
                }
                .frame(width: fenetre.width * u, height: fenetre.height * u, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 2 * u))
            }
            .offset(x: fenetre.minX * u, y: fenetre.minY * u)
            EtiquetteVue(mise: mise, face: face, fenetreADecouper: false, u: u)
                .offset(x: etiquette.x * u, y: etiquette.y * u)
            // Bas de la coque (trapèze avec les trous des cabestans)
            Path { c in
                c.move(to: CGPoint(x: 17 * u, y: 50 * u)); c.addLine(to: CGPoint(x: 83.4 * u, y: 50 * u))
                c.addLine(to: CGPoint(x: 87 * u, y: 63.8 * u)); c.addLine(to: CGPoint(x: 13.4 * u, y: 63.8 * u)); c.closeSubpath()
            }
            .fill(Color(red: 0.11, green: 0.12, blue: 0.14))
            ForEach([27.0, 73.4], id: \.self) { x in
                Circle().fill(Color.black).frame(width: 3.5 * u, height: 3.5 * u).offset(x: (x - 1.75) * u, y: 55 * u)
            }
            ForEach([CGPoint(x: 3, y: 3), CGPoint(x: 97.4, y: 3), CGPoint(x: 3, y: 60.8), CGPoint(x: 97.4, y: 60.8), CGPoint(x: 50.2, y: 57)], id: \.x) { v in
                Circle().fill(Color(white: 0.3)).frame(width: 1.8 * u, height: 1.8 * u).offset(x: (v.x - 0.9) * u, y: (v.y - 0.9) * u)
            }
        }
        .frame(width: 100.4 * u, height: 63.8 * u, alignment: .topLeading)
        .accessibilityLabel("Cassette face \(face.rawValue)")
    }
}

/// Une bobine : moyeu blanc à 6 dents qui tourne, bande brune qui grossit ou diminue (dimensions en mm).
private struct Bobine: View {
    let angle: Double
    let remplissage: Double
    let u: CGFloat
    var body: some View {
        let r = 5.5 + 15 * max(0, min(1, remplissage))
        ZStack {
            Circle().fill(Color(red: 0.353, green: 0.231, blue: 0.133)).frame(width: 2 * r * u, height: 2 * r * u)
            Circle().fill(Color(white: 0.96)).frame(width: 9 * u, height: 9 * u)
            ForEach(0..<6) { i in
                Rectangle().fill(Color(white: 0.25)).frame(width: 1 * u, height: 2.2 * u).offset(y: -2.6 * u)
                    .rotationEffect(.degrees(Double(i) * 60 + angle))
            }
        }
        .frame(width: 0, height: 0)
    }
}
