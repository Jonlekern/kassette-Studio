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

        // La J-card pliée : un pavé dont la face avant est le recto et le côté gauche la tranche.
        let carte = SCNBox(width: papier.l, height: papier.h, length: papier.e, chamferRadius: 0)
        carte.materials = [
            matiere(texture(RectoVue(mise: mise, largeur: Gabarits.recto, hauteur: Gabarits.hauteurJ, u: Typo.ptParMM)), fond),
            matiere(fond),
            matiere(fond.blended(withFraction: 0.35, of: .black), fond),
            matiere(texture(TrancheVue(mise: mise, longueur: Gabarits.hauteurJ, epaisseur: Gabarits.tranche, u: Typo.ptParMM)
                .background(Color(hex: mise.design.variante.palette.fond))), fond),
            matiere(fond),
            matiere(fond),
        ]
        let noeudCarte = SCNNode(geometry: carte)
        // Calée contre l'avant et la charnière (côté gauche) du boîtier.
        noeudCarte.position = SCNVector3(-b.largeur / 2 + 1.2 + papier.l / 2, 0, b.epaisseur / 2 - 0.9 - papier.e / 2)
        boitier.addChildNode(noeudCarte)

        // La cassette derrière la jaquette, à peine visible à travers le plastique.
        let k7 = SCNBox(width: 63, height: 100, length: 3, chamferRadius: 1)
        k7.materials = [matiere(NSColor(white: 0.18, alpha: 1))]
        let noeudK7 = SCNNode(geometry: k7)
        noeudK7.position = SCNVector3(0, 0, -b.epaisseur / 2 + 2)
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
