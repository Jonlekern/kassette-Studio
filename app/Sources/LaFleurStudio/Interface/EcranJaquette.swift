import LaFleurCore
import SwiftUI

enum FormatApercu: Hashable { case jcard, verso, ocard, etiquettes, obi }

enum ActionExport: String, Identifiable {
    case pdf, png, imprimer
    var id: String { rawValue }
    var nom: String { switch self { case .pdf: "Exporter le PDF"; case .png: "Exporter les PNG"; case .imprimer: "Imprimer" } }
}

/// Écran 2 : jaquette (J-card, O-card, étiquettes, obi), codes, direction artistique de Claude, export.
struct EcranJaquette: View {
    @EnvironmentObject var etat: EtatApp
    @State private var apercu: FormatApercu = .jcard
    @State private var zoom: CGFloat = 4
    /// Zoom automatique : l'objet entier tient dans l'aperçu.
    @State private var ajuster = true
    @State private var demande = ""
    @State private var montrer3D = false
    @State private var action: ActionExport?

    private func lien<T>(_ kp: WritableKeyPath<Design, T>) -> Binding<T> {
        Binding(get: { etat.design[keyPath: kp] }, set: { v in var d = etat.design; d[keyPath: kp] = v; etat.design = d })
    }
    private func couleur(_ kp: WritableKeyPath<Design, String>) -> Binding<Color> {
        Binding(get: { Color(hex: etat.design[keyPath: kp]) },
                set: { c in var d = etat.design; d[keyPath: kp] = NSColor(c).hex; etat.design = d })
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Marge à droite = largeur de la barre de défilement de macOS, pour qu'elle ne passe pas sur les menus.
            ScrollView { colonneReglages.padding(.trailing, 15).frame(width: 280, alignment: .leading) }.frame(width: 280)
            VStack(alignment: .leading, spacing: 6) {
                barreApercu
                GeometryReader { g in
                    let t = tailleApercu
                    let u = ajuster ? max(1, min((g.size.width - 48) / t.0, (g.size.height - 48) / t.1)) : zoom
                    ScrollView([.horizontal, .vertical]) {
                        apercuVue(u).environment(\.editionJaquette, etat.edition)
                            .padding(24).shadow(color: .black.opacity(0.35), radius: 4, x: 2, y: 3)
                            .frame(minWidth: g.size.width, minHeight: g.size.height)
                            // Clic à côté de la jaquette : plus rien de sélectionné.
                            .background(Color.clear.contentShape(Rectangle()).onTapGesture { etat.elementSelectionne = nil })
                    }
                    .onChange(of: u) { _, nouveau in if ajuster { zoom = nouveau } }
                    .onAppear { if ajuster { zoom = u } }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(W98.grisFonce).creux(W98.grisFonce)
                Text(dimensions).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            ScrollView { colonneClaude.padding(.trailing, 15).frame(width: 310, alignment: .leading) }.frame(width: 310)
        }
        .onAppear {
            if etat.projet.design == nil { etat.design = etat.designParDefaut }
            if !etat.design.jcard && apercu == .jcard { apercu = etat.design.etiquettes ? .etiquettes : .ocard }
            // Cassette sans pochette (ex. faite depuis le dossier) : on va chercher la vraie.
            if etat.projet.pochetteURL == nil { Task { await etat.chercherVraiePochette() } }
        }
        .sheet(isPresented: $montrer3D) { Apercu3D(mise: etat.mise) { montrer3D = false } }
        .alert(action?.nom ?? "", isPresented: Binding(get: { action != nil }, set: { if !$0 { action = nil } }), presenting: action) { a in
            if !etat.alertesBloquantes.isEmpty {
                Button("Tout corriger") { etat.toutCorriger() }
            }
            if a == .imprimer && etat.calibration == nil {
                Button("Imprimer la règle d'abord") { etat.imprimerCalibrage() }
            }
            Button(etat.alertesBloquantes.isEmpty ? "Continuer" : (a == .imprimer ? "Imprimer quand même" : "Exporter quand même")) { lancer(a) }
            Button("Annuler", role: .cancel) {}
        } message: { _ in
            Text(messageExport)
        }
    }

    private var messageExport: String {
        let b = etat.alertesBloquantes
        let rappel = "Rappel : usage personnel et non commercial. Tu es seul responsable de ce que tu imprimes (droits d'auteur, marques). Imprime toujours à 100 %."
        let regle = action == .imprimer && etat.calibration == nil
            ? "Ton imprimante (\(etat.imprimanteCourante)) n'est pas encore calibrée : imprime d'abord la règle pour vérifier que la jaquette sort à la bonne taille (Réglages → Impression).\n\n" : ""
        if b.isEmpty { return regle + rappel }
        let liste = b.prefix(4).map { "• " + $0.message }.joined(separator: "\n")
        return "\(b.count) alerte\(b.count > 1 ? "s" : "") ouverte\(b.count > 1 ? "s" : "") :\n\(liste)\n\n\(regle)\(rappel)"
    }

    private func lancer(_ a: ActionExport) {
        switch a {
        case .pdf: etat.exporterPDF()
        case .png: etat.exporterPNG()
        case .imprimer: etat.imprimer()
        }
    }

    // MARK: Aperçu

    private var formatsCoches: [(FormatApercu, String)] {
        let d = etat.design
        var f: [(FormatApercu, String)] = []
        if d.jcard { f.append((.jcard, "J-card")); if etat.mise.aUnVerso { f.append((.verso, "J-card verso")) } }
        if d.ocard { f.append((.ocard, "O-card")) }
        if d.etiquettes { f.append((.etiquettes, "Étiquettes")) }
        if d.obi { f.append((.obi, "Obi")) }
        return f
    }

    private var barreApercu: some View {
        // Formats sur une ligne, zoom sur la suivante : ça tient même en russe ou en allemand.
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(formatsCoches, id: \.0) { f in
                    Button(LocalizedStringKey(f.1)) { apercu = f.0 }.buttonStyle(apercu == f.0 ? .w98Gras : .w98).fixedSize()
                }
            }
            HStack(spacing: 4) {
                Text("Zoom").fixedSize()
                Slider(value: Binding(get: { zoom }, set: { zoom = $0; ajuster = false }), in: 1.5...8).frame(width: 110)
                Text("\(Int(zoom / Typo.ptParMM * 100)) %").fixedSize()
                Button("Ajuster") { ajuster = true }.buttonStyle(ajuster ? .w98Gras : .w98).fixedSize().help("Tout l'objet dans l'aperçu")
                Spacer(minLength: 4)
                Button("↶ Annuler") { etat.annuler() }.buttonStyle(.w98).fixedSize()
                    .keyboardShortcut("z", modifiers: .command).disabled(etat.annulations.isEmpty).help("Annuler la dernière modification (⌘Z)")
                Button("Aperçu 3D") { montrer3D = true }.buttonStyle(.w98).fixedSize().disabled(!etat.design.jcard)
            }
        }
    }

    /// Taille de l'objet affiché (mm).
    private var tailleApercu: (CGFloat, CGFloat) {
        switch apercu {
        case .jcard, .verso: let g = etat.mise.gabaritJ; return (g.largeur, g.hauteur)
        case .ocard: return (Gabarits.ocard.largeur, Gabarits.ocard.hauteur)
        case .etiquettes: return (89, 42 * 2 + 6)
        case .obi: return (Gabarits.obi.largeur, Gabarits.obi.hauteur)
        }
    }

    @ViewBuilder private func apercuVue(_ u: CGFloat) -> some View {
        let m = etat.mise
        switch apercu {
        case .jcard: JCardVue(mise: m, guides: true, deplacerCode: { x, y in
            var d = etat.design; d.codeX = x; d.codeY = y; etat.design = d
        }, u: u)
        case .verso: JCardVue(mise: m, cote: .verso, guides: true, u: u)
        case .ocard: OCardVue(mise: m, guides: true, u: u)
        case .etiquettes:
            VStack(spacing: 6 * u) {
                EtiquetteVue(mise: m, face: .a, u: u)
                EtiquetteVue(mise: m, face: .b, u: u)
            }
        case .obi: ObiVue(mise: m, guides: true, u: u)
        }
    }

    private var dimensions: String {
        let m = etat.mise
        let g: Gabarit
        switch apercu {
        case .jcard, .verso: g = m.gabaritJ
        case .ocard: g = Gabarits.ocard
        case .etiquettes: g = Gabarits.etiquette
        case .obi: g = Gabarits.obi
        }
        let mm = { (x: Double) in x.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(x)) mm" : String(format: "%.1f mm", x).replacingOccurrences(of: ".", with: ",") }
        let panneaux = g.panneaux.count > 1 ? g.panneaux.map { "\(tr(nomPanneau($0))) \(mm($0.largeur))" }.joined(separator: " · ") + " · " : "\(mm(g.largeur)) × "
        let papier = Papier.pour(largeur: g.largeur, hauteur: g.hauteur)
        return "\(panneaux)\(tr("Hauteur")) \(mm(g.hauteur)) · \(tr("Papier")) \(papier.nom) · 600 DPI\(apercu == .verso ? " · " + tr("recto verso, retourner sur le grand côté") : "")"
    }

    /// Nom d'un panneau sans numéro (pour la traduction), puis le numéro.
    private func nomPanneau(_ p: Panneau) -> String {
        if case .interieur(let i) = p.genre { return tr("Intérieur") + " \(i)" }
        return p.nom
    }

    // MARK: Colonne de gauche : réglages

    private var colonneReglages: some View {
        VStack(alignment: .leading, spacing: 10) {
            Groupe(titre: "Format") {
                Toggle("J-card", isOn: lien(\.jcard))
                Toggle("O-card cassingle", isOn: lien(\.ocard))
                Toggle("Étiquettes de K7", isOn: lien(\.etiquettes))
                Toggle("Obi strip", isOn: lien(\.obi))
            }
            .toggleStyle(.checkbox)

            Groupe(titre: "Mise en page") {
                Picker("Volets", selection: lien(\.volets)) { ForEach(3...8, id: \.self) { Text("\($0)").tag($0) } }
                Picker("Dos", selection: lien(\.dos)) { ForEach(FormeDos.allCases, id: \.self) { Text(tr($0.nom)).tag($0) } }
                Toggle("Coupe, pliage, fond perdu", isOn: lien(\.reperes)).toggleStyle(.checkbox)
                if etat.mise.aUnVerso {
                    Text("Avec \(etat.design.volets) volets, une partie va au verso : impression recto verso. Ajoute des volets pour tout imprimer d'un côté.")
                        .foregroundStyle(W98.ombre).fixedSize(horizontal: false, vertical: true)
                }
            }

            Groupe(titre: "Recto") {
                Picker("Orientation", selection: lien(\.orientation)) {
                    ForEach(OrientationRecto.allCases, id: \.self) { Text(tr($0.nom)).tag($0) }
                }
                .pickerStyle(.segmented)
                // Libellé au-dessus : à côté, il se coupait en deux (« Cadra-ge »).
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cadrage")
                    Picker("Cadrage", selection: lien(\.cadrage)) {
                        ForEach(CadrageRecto.allCases, id: \.self) { Text(tr($0.nom)).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                // Recadrage de l'image (demande 1) : utile quand elle est rognée (pleine hauteur ou paysage).
                if etat.design.cadrage == .pleineHauteur || etat.design.orientation == .paysage {
                    curseur("Position horizontale", etat.design.cadrageX) { v in etat.modifierDesign { $0.cadrageX = v } }
                    curseur("Position verticale", etat.design.cadrageY) { v in etat.modifierDesign { $0.cadrageY = v } }
                }
                HStack {
                    Text("Zoom de l'image")
                    Slider(value: Binding(get: { etat.design.ajustement("recto-image").echelle },
                                          set: { v in etat.ajuster("recto-image") { $0.echelle = (v * 20).rounded() / 20 } }), in: 1...3)
                }
                Picker("Style", selection: lien(\.variante.style)) { ForEach(StyleRecto.allCases, id: \.self) { Text(tr($0.nom)).tag($0) } }
                HStack {
                    Button("Choisir une image…") { etat.choisirImagePerso() }.buttonStyle(.w98)
                    if etat.design.imagePerso != nil {
                        Button("×") { var d = etat.design; d.imagePerso = nil; etat.design = d }.buttonStyle(.w98).help("Retirer l'image")
                    }
                }
                HStack { Text("Opacité"); Slider(value: lien(\.variante.opaciteImage), in: 0.1...1) }
                ForEach(etat.design.imagesPosees) { img in
                    HStack(spacing: 4) {
                        ImageCache(url: img.url, remplir: false).frame(width: 24, height: 24)
                        Text(img.source).lineLimit(1).truncationMode(.middle).help(img.source)
                        Spacer(minLength: 0)
                        Button("×") { var d = etat.design; d.imagesPosees.removeAll { $0.id == img.id }; etat.design = d }
                            .buttonStyle(.w98).help("Retirer cette image")
                    }
                }
            }

            Groupe(titre: "Couleurs et polices") {
                ColorPicker("Fond", selection: couleur(\.variante.palette.fond), supportsOpacity: false)
                ColorPicker("Texte", selection: couleur(\.variante.palette.texte), supportsOpacity: false)
                ColorPicker("Accent", selection: couleur(\.variante.palette.accent), supportsOpacity: false)
                Picker("Titre", selection: lien(\.variante.policeTitre)) { polices }
                Picker("Texte", selection: lien(\.variante.policeTexte)) { polices }
                Toggle("Titre en italique", isOn: lien(\.variante.titreItalique)).toggleStyle(.checkbox)
                Button("Importer une police…") { etat.importerPolice() }.buttonStyle(.w98)
            }

            if etat.design.etiquettes { GroupeEtiquettes() }
            GroupeTailles()

            Groupe(titre: "Textes") {
                Text("Maison de disque")
                Champ(invite: "LAFLEURSTUDIO", texte: $etat.projet.maisonDeDisque)
                HStack {
                    Text("Tranche")
                    Spacer()
                    Button("Auto") { var d = etat.design; d.texteTranche = nil; etat.design = d }.buttonStyle(.w98)
                }
                // Sur deux lignes si besoin : le texte de tranche entier reste visible (42 caractères).
                TextField(etat.projet.trancheAuto, text: Binding(
                    get: { etat.design.texteTranche ?? "" },
                    set: { t in var d = etat.design; d.texteTranche = t.isEmpty ? nil : t; etat.design = d }), axis: .vertical)
                    .lineLimit(1...2).textFieldStyle(.plain).font(W98.police)
                    .padding(.horizontal, 5).padding(.vertical, 4).creux()
                Text("Notes (volet intérieur)")
                TextEditor(text: lien(\.notes)).font(W98.police).frame(height: 60).creux()
                Text("Crédits")
                TextEditor(text: lien(\.credits)).font(W98.police).frame(height: 60).creux()
                Toggle("Lien vers les paroles (genius.com)", isOn: lien(\.lienParoles)).toggleStyle(.checkbox)
                    .help("Jamais les paroles complètes (droits d'auteur) : seulement où les trouver.")
                if etat.design.obi {
                    Text("Texte de l'obi")
                    Champ(invite: etat.mise.texteTranche, texte: lien(\.obiTexte))
                }
                Toggle("Logo de la maison de disque", isOn: lien(\.afficherLogoMaison)).toggleStyle(.checkbox)
                if etat.projet.maisonDeDisque.uppercased() != "LAFLEURSTUDIO" {
                    HStack {
                        Button("Importer un logo…") { etat.importerLogo() }.buttonStyle(.w98)
                        if etat.design.logoMaison != nil {
                            Button("×") { var d = etat.design; d.logoMaison = nil; etat.design = d }.buttonStyle(.w98).help("Retirer le logo")
                        }
                    }
                    Text("Sans logo importé, le nom est écrit en texte.").foregroundStyle(W98.ombre)
                }
            }

            groupeCodes

            if etat.projet.mode == .album {
                Groupe(titre: "Vraies éditions cassette") {
                    Text("Claude part de leurs scans pour la première proposition.").foregroundStyle(W98.ombre)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(etat.jetonDiscogs.isEmpty ? "Chercher sur MusicBrainz" : "Chercher sur MusicBrainz et Discogs") { etat.chercherEditionsK7() }
                        .buttonStyle(.w98).disabled(etat.occupe)
                    if etat.editionsK7.contains(where: { !$0.cassette }) {
                        Text("Jamais sorti en cassette : Claude part du dos de l'édition CD ou vinyle.").foregroundStyle(W98.ombre)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(etat.editionsK7) { e in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(e.titre).bold().lineLimit(1)
                            Text(e.detail).foregroundStyle(W98.ombre).lineLimit(1)
                            ScrollView(.horizontal) {
                                HStack(spacing: 3) {
                                    ForEach(e.images, id: \.self) { u in ImageCache(url: u).frame(width: 46, height: 46).clipped() }
                                }
                            }
                            Link("Source : \(e.source)", destination: e.page).foregroundStyle(W98.bleu)
                            if !e.credits.isEmpty || !e.notes.isEmpty {
                                Button("Reprendre crédits et notes") {
                                    var d = etat.design
                                    if !e.credits.isEmpty { d.credits = e.credits }
                                    if !e.notes.isEmpty && d.notes.isEmpty { d.notes = e.notes }
                                    etat.design = d
                                }
                                .buttonStyle(.w98)
                            }
                        }
                        .padding(4).creux()
                    }
                }
            }
        }
    }

    @ViewBuilder private var polices: some View {
        ForEach(etat.policesDisponibles, id: \.self) { Text($0).tag($0) }
        let d = etat.design.variante
        ForEach([d.policeTitre, d.policeTexte].filter { !etat.policesDisponibles.contains($0) }, id: \.self) {
            Text("\($0) (absente)").tag($0)
        }
    }

    private var groupeCodes: some View {
        let d = etat.design
        let m = etat.mise
        let alertesCode = etat.alertes.filter { $0.zone == "code" }
        return Groupe(titre: "Codes") {
            HStack {
                Toggle("Barres", isOn: lien(\.codeBarres))
                Toggle("QR", isOn: lien(\.qr))
                Toggle("Spotify", isOn: lien(\.codeSpotify))
            }
            .toggleStyle(.checkbox)
            if d.codeBarres {
                Picker("Type", selection: lien(\.genreCode)) { ForEach(CodeBarres1D.Genre.allCases, id: \.self) { Text(tr($0.nom)).tag($0) } }
                Text("Numéro")
                Champ(invite: d.genreCode == .code128 ? etat.projet.numeroCatalogue : m.numeroCode, texte: lien(\.numeroCode))
                if let c = CodesBarres.generer(d.genreCode, m.numeroCode), c.numero != d.numeroCode, !d.numeroCode.isEmpty {
                    Text("Clé de contrôle calculée : \(c.numero)").foregroundStyle(W98.ombre)
                }
                Text("Texte au-dessus")
                Champ(invite: etat.projet.texteCodeAuto, texte: Binding(
                    get: { d.texteCode ?? "" },
                    set: { t in var n = etat.design; n.texteCode = t.isEmpty ? nil : t; etat.design = n }))
                Picker("Place", selection: lien(\.placeCode)) { ForEach(PlaceCode.allCases, id: \.self) { Text(tr($0.nom)).tag($0) } }
                Toggle("Chiffres sous les barres", isOn: lien(\.chiffresCode)).toggleStyle(.checkbox)
                // Taille réelle en mm (demande 2) ; vide = automatique.
                let t = m.tailleCodeBarres()
                HStack(spacing: 4) {
                    Text("Taille")
                    ChampNombre(invite: t.map { ChampNombre.format(($0.largeur * 10).rounded() / 10) } ?? "auto", valeur: lien(\.largeurCodeMM))
                    Text("×")
                    ChampNombre(invite: t.map { ChampNombre.format(($0.hauteur * 10).rounded() / 10) } ?? "auto", valeur: lien(\.hauteurCodeMM))
                    Text("mm")
                    if d.largeurCodeMM > 0 || d.hauteurCodeMM > 0 {
                        Button("Auto") { etat.modifierDesign { $0.largeurCodeMM = 0; $0.hauteurCodeMM = 0 } }.buttonStyle(.w98)
                    }
                }
                if d.largeurCodeMM == 0 { HStack { Text("Échelle"); Slider(value: lien(\.echelleCode), in: 0.6...1.4) } }
            }
            if d.qr {
                Picker("QR code", selection: lien(\.contenuQR)) { ForEach(ContenuQR.allCases, id: \.self) { Text(tr($0.nom)).tag($0) } }
                if d.contenuQR != .spotify {
                    Champ(invite: d.contenuQR == .lienPerso ? "https://bandcamp.com/…" : "Texte du QR code", texte: lien(\.texteQR))
                }
                HStack(spacing: 4) {
                    Text("Côté du QR")
                    ChampNombre(invite: "15", valeur: lien(\.coteQRMM))
                    Text("mm")
                }
                Picker("Place du QR", selection: lien(\.placeQR)) {
                    Text(tr(PlaceCode.rabat.nom)).tag(PlaceCode.rabat)
                    Text(tr(PlaceCode.interieur.nom)).tag(PlaceCode.interieur)
                    Text(tr(PlaceCode.libre.nom)).tag(PlaceCode.libre)
                }
            }
            if d.codeSpotify {
                HStack(spacing: 4) {
                    Text("Largeur du code Spotify")
                    ChampNombre(invite: "auto", valeur: lien(\.largeurSpotifyMM))
                    Text("mm")
                }
            }
            if d.placeCode == .libre || d.placeQR == .libre {
                Picker("Rotation", selection: lien(\.rotationCode)) {
                    ForEach([0.0, 90, 180, 270], id: \.self) { Text("\(Int($0))°").tag($0) }
                }
                Text("Glisse les codes dans l'aperçu de la J-card.").foregroundStyle(W98.ombre)
            }
            if d.codeBarres || d.qr || d.codeSpotify {
                Text("Couleurs")
                HStack(spacing: 4) {
                    ForEach(CouleursCode.allCases, id: \.self) { c in
                        Button(tr(c.nom)) { var n = etat.design; n.couleursCode = c; etat.design = n }
                            .buttonStyle(d.couleursCode == c ? .w98Gras : .w98)
                    }
                }
                if d.couleursCode == .perso {
                    ColorPicker("Barres", selection: couleur(\.barresPerso), supportsOpacity: false)
                    ColorPicker("Fond", selection: couleur(\.fondPerso), supportsOpacity: false)
                }
                if alertesCode.isEmpty {
                    Text(d.codeBarres ? "✓ \(d.genreCode.nom) valide · scannable · les chiffres suivent les barres" : "✓ Codes scannables").foregroundStyle(W98.vert)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(alertesCode) { a in
                        Text("⚠︎ " + a.message).foregroundStyle(a.gravite == .bloquante ? W98.rouge : W98.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: Colonne de droite : Claude, vérification, export

    private var colonneClaude: some View {
        let d = etat.design
        return VStack(alignment: .leading, spacing: 10) {
            PanneauElement()
            Groupe(titre: "Direction artistique · \(etat.fournisseurIA.nom)") {
                if etat.conversation.isEmpty {
                    BulleClaude(cle: etat.projet.mode == .album
                                ? "Je pars des vraies éditions cassette si j'en trouve, sinon de ta pochette. Dis-moi l'ambiance, ou clique sur « Proposer »."
                                : "Pour ta mixtape je propose d'abord un collage des covers, puis ta propre image, le style K7 maison, ou un design dessiné. Dis-moi l'ambiance.")
                }
                ForEach(etat.conversation) { m in
                    if m.deClaude {
                        BulleClaude(texte: m.texte)
                    } else {
                        Text(m.texte).padding(6).frame(maxWidth: .infinity, alignment: .trailing).creux()
                    }
                }
                if !d.propositions.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        ForEach(d.propositions) { v in
                            VStack(spacing: 3) {
                                Button { etat.choisirVariante(v) } label: {
                                    RectoVue(mise: Mise(projet: etat.projet, design: { var x = d; x.variante = v; return x }()),
                                             largeur: Gabarits.recto, hauteur: Gabarits.hauteurJ, u: 1.3)
                                        .overlay(Rectangle().stroke(d.variante.id == v.id ? W98.bleu : Color.clear, lineWidth: 3))
                                }
                                .buttonStyle(.plain).help(v.commentaire)
                                HStack(spacing: 2) {
                                    Text(v.nom).bold()
                                    Button("↻") { etat.dirigerDesign("", regenerer: v.nom) }.buttonStyle(.w98)
                                        .help("Régénérer seulement la variante \(v.nom)").disabled(etat.occupe)
                                }
                            }
                        }
                    }
                }
                HStack(spacing: 4) {
                    Button(d.propositions.isEmpty ? "Proposer" : "Régénérer tout") { etat.dirigerDesign(d.propositions.isEmpty ? "" : "Régénère les 3 variantes.") }
                        .buttonStyle(.w98Gras).disabled(etat.occupe)
                    if !d.historique.isEmpty {
                        Menu("Versions (\(d.historique.count))") {
                            ForEach(d.historique.reversed()) { v in
                                Button("\(v.nom) · \(v.creeLe.formatted(date: .omitted, time: .shortened)) · \(tr(v.style.nom))") { etat.choisirVariante(v) }
                            }
                        }
                        .fixedSize()
                    }
                }
                HStack(spacing: 4) {
                    Champ(invite: "Demande à Claude…", texte: $demande)
                        .onSubmit(envoyer)
                        .help("Ex. « plus sombre », « plus 90s », « mets la vraie pochette », « mets le logo Sony »")
                    Button("Envoyer", action: envoyer).buttonStyle(.w98).disabled(demande.isEmpty || etat.occupe)
                }
                if etat.projet.mode == .album {
                    Button("Chercher les infos de l'album sur le web") { etat.chercherInfosWeb() }
                        .buttonStyle(.w98).disabled(etat.occupe || !etat.prefs.rechercheWebClaude)
                }
            }

            Groupe(titre: "Vérification avant impression") {
                let a = etat.alertes
                if a.isEmpty {
                    Text("✓ Textes lisibles, rien ne déborde, codes scannables.").foregroundStyle(W98.vert)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(a) { al in
                    HStack(alignment: .top, spacing: 4) {
                        Text(al.gravite == .bloquante ? "⛔" : "⚠︎")
                        Text(al.message).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button("Ignorer") { etat.ignorer(al) }.buttonStyle(.w98).help("Imprimer quand même avec ce défaut")
                    }
                    .padding(4).creux(al.gravite == .bloquante ? Color(red: 1, green: 0.92, blue: 0.92) : W98.bulle)
                }
                if let avis = etat.avisClaude {
                    BulleClaude(texte: avis.message + (avis.corrections.isEmpty ? "" : "\n" + avis.corrections.map { "• \($0.zone) : \($0.explication)" }.joined(separator: "\n")))
                    if !avis.corrections.isEmpty {
                        Button("Appliquer les corrections de Claude") { etat.appliquer(avis.corrections) }.buttonStyle(.w98)
                    }
                }
                HStack(spacing: 4) {
                    Button("Tout corriger") { etat.toutCorriger() }.buttonStyle(.w98).disabled(a.isEmpty && etat.avisClaude == nil)
                    Button("Vérifier avec Claude") { etat.verifierAvecClaude() }.buttonStyle(.w98).disabled(etat.occupe)
                }
                if !d.alertesForcees.isEmpty {
                    Button("Réafficher les alertes ignorées (\(d.alertesForcees.count))") {
                        var n = etat.design; n.alertesForcees = []; etat.design = n
                    }
                    .buttonStyle(.w98)
                }
            }

            Groupe(titre: "Exporter") {
                HStack(spacing: 4) {
                    Button("PDF") { action = .pdf }.buttonStyle(.w98)
                    Button("PNG 600 DPI") { action = .png }.buttonStyle(.w98)
                    Button("Imprimer…") { action = .imprimer }.buttonStyle(.w98Gras)
                }
                let n = formatsCoches.filter { $0.0 != .verso }.count
                Text(n > 1 ? "\(n) formats cochés · papier 170 à 250 g/m² · étiquettes sur papier autocollant"
                           : "\(n) format coché · papier 170 à 250 g/m² · étiquettes sur papier autocollant")
                    .foregroundStyle(W98.ombre).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func envoyer() {
        guard !demande.isEmpty, !etat.occupe else { return }
        etat.dirigerDesign(demande)
        demande = ""
    }
}

/// Aperçu du boîtier : la J-card pliée dans une K7, qu'on fait tourner à la souris.
struct Apercu3D: View {
    let mise: Mise
    let fermer: () -> Void
    var body: some View {
        Fenetre(titre: "Aperçu 3D", fermer: fermer) {
            VStack(spacing: 12) {
                // Vrai boîtier en 3D : jaquette pliée dans la coque en plastique.
                Boitier3DVue(mise: mise).frame(width: 520, height: 470).creux(W98.gris)
                Text("Glisse pour tourner le boîtier, molette pour zoomer").foregroundStyle(W98.ombre)
            }
            .padding(12)
        }
        .w98()
    }
}
