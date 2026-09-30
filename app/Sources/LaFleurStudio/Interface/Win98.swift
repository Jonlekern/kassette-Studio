import SwiftUI

/// Les briques visuelles Windows 98, comme sur lafleurstudio.ch.
enum W98 {
    static let gris = Color(red: 0.753, green: 0.753, blue: 0.753)       // #c0c0c0
    static let grisFonce = Color(red: 0.502, green: 0.502, blue: 0.502)  // #808080
    static let ombre = Color(red: 0.251, green: 0.251, blue: 0.251)      // #404040
    static let clair = Color(red: 0.875, green: 0.875, blue: 0.875)      // #dfdfdf
    static let bleu = Color(red: 0, green: 0, blue: 0.502)               // #000080
    static let bleuClair = Color(red: 0.063, green: 0.518, blue: 0.816)  // #1084d0
    static let bureau = Color(red: 0, green: 0.502, blue: 0.502)         // #008080
    static let bulle = Color(red: 1, green: 1, blue: 0.882)              // #ffffe1
    static let rouge = Color(red: 0.8, green: 0, blue: 0)
    static let vert = Color(red: 0, green: 0.392, blue: 0)
    static let orange = Color(red: 0.702, green: 0.42, blue: 0)
    static let police = Font.custom("Arial", size: 12)
    static let policeGras = Font.custom("Arial", size: 12).bold()
    static let lcd = Font.system(size: 26, weight: .regular, design: .monospaced)
}

/// Bord en relief (bouton, fenêtre) ou en creux (champ, liste).
struct Biseau: View {
    var creux = false
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Path { p in p.move(to: CGPoint(x: 0, y: h)); p.addLine(to: .zero); p.addLine(to: CGPoint(x: w, y: 0)) }
                    .stroke(creux ? W98.grisFonce : .white, lineWidth: 1)
                Path { p in p.move(to: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h)) }
                    .stroke(creux ? .white : W98.ombre, lineWidth: 1)
                Path { p in p.move(to: CGPoint(x: 1, y: h - 1)); p.addLine(to: CGPoint(x: 1, y: 1)); p.addLine(to: CGPoint(x: w - 1, y: 1)) }
                    .stroke(creux ? W98.ombre : W98.clair, lineWidth: 1)
                Path { p in p.move(to: CGPoint(x: w - 1, y: 1)); p.addLine(to: CGPoint(x: w - 1, y: h - 1)); p.addLine(to: CGPoint(x: 1, y: h - 1)) }
                    .stroke(creux ? W98.clair : W98.grisFonce, lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    func relief() -> some View { background(W98.gris).overlay(Biseau()) }
    func creux(_ fond: Color = .white) -> some View { background(fond).overlay(Biseau(creux: true)) }
    func w98() -> some View { font(W98.police).foregroundStyle(.black) }
}

struct BoutonW98: ButtonStyle {
    var gras = false
    @Environment(\.isEnabled) private var actif
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(gras ? W98.policeGras : W98.police)
            .foregroundStyle(actif ? Color.black : W98.grisFonce)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .frame(minHeight: 24)
            .background(W98.gris)
            .overlay(Biseau(creux: configuration.isPressed))
            .offset(x: configuration.isPressed ? 1 : 0, y: configuration.isPressed ? 1 : 0)
    }
}

extension ButtonStyle where Self == BoutonW98 {
    static var w98: BoutonW98 { BoutonW98() }
    static var w98Gras: BoutonW98 { BoutonW98(gras: true) }
}

/// Cadre gravé avec légende, comme les « group box » de Windows.
struct Groupe<Contenu: View>: View {
    let titre: LocalizedStringKey
    @ViewBuilder var contenu: Contenu
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { contenu }
            .padding(.horizontal, 8).padding(.top, 14).padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 0).stroke(W98.grisFonce, lineWidth: 1).padding(.top, 6))
            .overlay(alignment: .topLeading) {
                Text(titre).font(W98.police).padding(.horizontal, 4).background(W98.gris).padding(.leading, 8)
            }
    }
}

/// Fenêtre avec barre de titre bleue.
struct Fenetre<Contenu: View>: View {
    let titre: String
    var fermer: (() -> Void)?
    @ViewBuilder var contenu: Contenu
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(LocalizedStringKey(titre)).font(W98.policeGras).foregroundStyle(.white)
                Spacer()
                if let fermer {
                    Button(action: fermer) { Text("×").font(.system(size: 11, weight: .bold)).foregroundStyle(W98.rouge) }
                        .buttonStyle(.plain).frame(width: 16, height: 14).relief().accessibilityLabel("Fermer")
                }
            }
            .padding(.horizontal, 6).frame(height: 20)
            .background(LinearGradient(colors: [W98.bleu, W98.bleuClair], startPoint: .leading, endPoint: .trailing))
            contenu
        }
        .padding(3).relief()
    }
}

/// Onglets Windows 98.
struct Onglets<Valeur: Hashable>: View {
    let onglets: [(Valeur, String)]
    @Binding var selection: Valeur
    var body: some View {
        HStack(spacing: 2) {
            ForEach(onglets.indices, id: \.self) { i in
                let (valeur, titre) = onglets[i]
                let actif = valeur == selection
                Button { selection = valeur } label: {
                    Text(LocalizedStringKey(titre)).font(actif ? W98.policeGras : W98.police).foregroundStyle(.black)
                        .padding(.horizontal, 16).padding(.vertical, actif ? 5 : 4)
                        .relief().offset(y: actif ? 1 : 2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Barre de progression en petits blocs.
struct Blocs: View {
    let valeur: Double
    let total: Double
    var couleur: Color = W98.bleu
    var body: some View {
        GeometryReader { g in
            let n = max(1, Int((g.size.width - 2) / 10))
            let pleins = total > 0 ? min(n, Int((Double(n) * valeur / total).rounded())) : 0
            HStack(spacing: 2) {
                ForEach(0..<pleins, id: \.self) { _ in Rectangle().fill(couleur).frame(width: 8) }
                Spacer(minLength: 0)
            }
            .padding(2)
        }
        .frame(height: 16).creux()
    }
}

/// Bulle de Claude (fond jaune pâle). `texte` : réponse de Claude, affichée telle quelle ; `cle` : texte de l'app, traduit.
struct BulleClaude: View {
    private let contenu: Text
    init(texte: String) { contenu = Text(verbatim: texte) }
    init(cle: LocalizedStringKey) { contenu = Text(cle) }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Claude").font(W98.policeGras)
            contenu.font(W98.police).fixedSize(horizontal: false, vertical: true)
        }
        .padding(8).frame(maxWidth: .infinity, alignment: .leading).creux(W98.bulle)
    }
}

/// Champ de texte au style Windows 98.
struct Champ: View {
    let invite: String
    @Binding var texte: String
    var secret = false
    var body: some View {
        Group {
            if secret { SecureField(LocalizedStringKey(invite), text: $texte) } else { TextField(LocalizedStringKey(invite), text: $texte) }
        }
        .textFieldStyle(.plain).font(W98.police).padding(.horizontal, 5).frame(height: 22).creux()
    }
}

/// Traduit un texte connu seulement à l'exécution (noms des réglages, panneaux…), clé = texte français.
func tr(_ s: String) -> String { Bundle.main.localizedString(forKey: s, value: s, table: nil) }
