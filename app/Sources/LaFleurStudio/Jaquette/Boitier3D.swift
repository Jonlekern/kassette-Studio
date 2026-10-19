import AppKit
import LaFleurCore
import SceneKit
import SwiftUI

/// Boîtier de K7 en 3D (SceneKit) : la J-card pliée (recto devant, tranche sur le côté),
/// dans une coque en plastique transparent. Tourne dans tous les sens à la souris.
@MainActor
enum Boitier3D {
    // Boîtier standard (Norelco), debout : largeur × hauteur × épaisseur, en mm.
    static let boite: (largeur: CGFloat, hauteur: CGFloat, epaisseur: CGFloat) = (69.6, 109.2, 17)

    /// Construit la scène et renvoie aussi la caméra (pour les captures).
    static func scene(_ mise: Mise) -> (SCNScene, SCNNode) {
        let scene = SCNScene()
        let fond = NSColor(Color(hex: mise.design.variante.palette.fond))
        let b = boite
        let papier = (l: CGFloat(Gabarits.recto), h: CGFloat(Gabarits.hauteurJ), e: CGFloat(Gabarits.tranche))

        let boitier = SCNNode()
        boitier.eulerAngles = SCNVector3(0.12, 0.5, 0)  // tourné pour montrer la tranche, côté charnière
        scene.rootNode.addChildNode(boitier)

        // La J-card pliée, comme dans un vrai boîtier : le recto devant, la tranche côté charnière, le rabat au dos.
        let gauche = -b.largeur / 2 + 1.2, avant = b.epaisseur / 2 - 0.9, mince: CGFloat = 0.3
        let rabat = CGFloat(mise.gabaritJ.panneaux.first { $0.genre == .rabat }?.largeur ?? 15)
        func panneau(_ l: CGFloat, _ h: CGFloat, _ e: CGFloat, _ x: CGFloat, _ z: CGFloat, faces: [SCNMaterial]) {
            let n = SCNNode(geometry: { let g = SCNBox(width: l, height: h, length: e, chamferRadius: 0); g.materials = faces; return g }())
            n.position = SCNVector3(x, 0, z)
            boitier.addChildNode(n)
        }
        // Ordre des faces d'un SCNBox : avant, droite, arrière, gauche, haut, bas.
        panneau(papier.l, papier.h, mince, gauche + papier.l / 2, avant - mince / 2, faces: [
            matiere(texture(RectoVue(mise: mise, largeur: Gabarits.recto, hauteur: Gabarits.hauteurJ, u: Typo.ptParMM)), fond),
            matiere(fond), matiere(fond), matiere(fond), matiere(fond), matiere(fond)])
        panneau(mince, papier.h, papier.e, gauche, avant - papier.e / 2, faces: [
            matiere(fond), matiere(fond), matiere(fond),
            matiere(texture(TrancheVue(mise: mise, longueur: Gabarits.hauteurJ, epaisseur: Gabarits.tranche, u: Typo.ptParMM)
                .background(Color(hex: mise.design.variante.palette.fond))), fond),
            matiere(fond), matiere(fond)])
        // Le rabat se voit par le dos du boîtier (avant, le dos était un bloc noir).
        panneau(rabat, papier.h, mince, gauche + rabat / 2, avant - papier.e + mince / 2, faces: [
            matiere(fond), matiere(fond),
            matiere(texture(RabatVue(mise: mise, largeur: rabat, hauteur: Gabarits.hauteurJ, u: Typo.ptParMM)
                .background(Color(hex: mise.design.variante.palette.fond))), fond),
            matiere(fond), matiere(fond), matiere(fond)])

        // La cassette entre le recto et le rabat, debout, avec ses étiquettes (face A devant, face B derrière).
        let k: CGFloat = 4
        let dessin = { (f: Face) in
            texture(CassetteDessin(projet: mise.projet, face: f, tourne: false, progression: 0.3, u: k)
                .frame(width: 100.4 * k, height: 63.8 * k)
                .rotationEffect(.degrees(-90)).frame(width: 63.8 * k, height: 100.4 * k))
        }
        let plastiqueK7 = NSColor(white: mise.projet.cassette.coque == .noire ? 0.1 : mise.projet.cassette.coque == .blanche ? 0.92 : 0.4, alpha: 1)
        let k7 = SCNBox(width: 63.8, height: 100.4, length: 11, chamferRadius: 1)
        k7.materials = [matiere(dessin(.a), plastiqueK7), matiere(plastiqueK7), matiere(dessin(.b), plastiqueK7),
                        matiere(plastiqueK7), matiere(plastiqueK7), matiere(plastiqueK7)]
        let noeudK7 = SCNNode(geometry: k7)
        noeudK7.position = SCNVector3(gauche + 0.6 + 63.8 / 2, 0, avant - papier.e / 2)
        boitier.addChildNode(noeudK7)

        // La coque : plastique clair, reflets sur les arêtes.
        let coque = SCNBox(width: b.largeur, height: b.hauteur, length: b.epaisseur, chamferRadius: 1.5)
        let plastique = SCNMaterial()
        plastique.lightingModel = .blinn
        plastique.diffuse.contents = NSColor(white: 1, alpha: 0.08)
        plastique.specular.contents = NSColor(white: 1, alpha: 0.9)
        plastique.shininess = 0.9
        plastique.transparencyMode = .dualLayer
        plastique.blendMode = .alpha
        plastique.isDoubleSided = true
        coque.materials = [plastique]
        let noeudCoque = SCNNode(geometry: coque)
        noeudCoque.renderingOrder = 10
        boitier.addChildNode(noeudCoque)

        // Lumières : ambiance douce + une lampe en haut à gauche pour les reflets.
        let ambiance = SCNNode()
        ambiance.light = SCNLight()
        ambiance.light!.type = .ambient
        ambiance.light!.intensity = 650
        scene.rootNode.addChildNode(ambiance)
        let lampe = SCNNode()
        lampe.light = SCNLight()
        lampe.light!.type = .directional
        lampe.light!.intensity = 700
        lampe.eulerAngles = SCNVector3(-0.6, -0.5, 0)
        scene.rootNode.addChildNode(lampe)

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera!.fieldOfView = 32
        camera.camera!.zNear = 1
        camera.camera!.zFar = 2000
        camera.position = SCNVector3(0, 0, 230)
        scene.rootNode.addChildNode(camera)
        return (scene, camera)
    }

    /// Image fixe de la scène (captures automatiques), sans fenêtre.
    static func image(_ mise: Mise, taille: CGSize) -> NSImage? {
        let (scene, camera) = scene(mise)
        scene.background.contents = NSColor(W98.gris)
        let r = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        r.scene = scene
        r.pointOfView = camera
        return r.snapshot(atTime: 0, with: taille, antialiasingMode: .multisampling4X)
    }

    private static func matiere(_ contenu: Any?, _ defaut: NSColor? = nil) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = contenu ?? defaut
        m.lightingModel = .lambert
        return m
    }

    /// Une vue de la jaquette rendue en image à 300 DPI, pour l'appliquer sur une face.
    private static func texture(_ vue: some View) -> NSImage? {
        let r = ImageRenderer(content: vue.environment(\.colorScheme, .light))
        r.scale = 300 / 72
        return r.nsImage
    }
}

/// Vue SwiftUI du boîtier : glisser pour tourner, pincer ou molette pour zoomer.
struct Boitier3DVue: View {
    let mise: Mise
    @State private var scene: (SCNScene, SCNNode)?

    var body: some View {
        Group {
            if let sc = scene {
                SceneView(scene: sc.0, pointOfView: sc.1, options: [.allowsCameraControl])
            } else {
                Color.clear
            }
        }
        .onAppear {
            let r = Boitier3D.scene(mise)
            r.0.background.contents = NSColor(W98.gris)
            scene = r
        }
    }
}
