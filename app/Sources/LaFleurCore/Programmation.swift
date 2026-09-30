import AVFoundation

/// Programme les pistes d'une face sur des lecteurs audio, au sample près, d'après le déroulé.
/// Chaque piste est coupée net à la fin de son segment : rien ne déborde sur le blanc suivant.
public enum Programmation {
    /// - Parameters:
    ///   - t0: instant de la face à partir duquel on joue (0 = début, ou la position de reprise après une pause).
    ///   - heure: l'instant de départ réel pour un décalage donné (en secondes) après le départ.
    public static func programmer(lecteurs: [AVAudioPlayerNode], fichiers: [AVAudioFile], deroule: Deroule,
                                  depuis t0: TimeInterval, heure: (TimeInterval) -> AVAudioTime) {
        for (i, (n, f)) in zip(lecteurs, fichiers).enumerated() {
            guard let seg = deroule.segments.first(where: { $0.genre == .piste(i) }), seg.fin > t0 else { continue }
            let taux = f.processingFormat.sampleRate
            let premiere = AVAudioFramePosition(max(0, t0 - seg.debut) * taux)
            let restant = AVAudioFramePosition((seg.fin - max(t0, seg.debut)) * taux)
            let nombre = min(f.length - premiere, restant)
            guard nombre > 0 else { continue }
            n.scheduleSegment(f, startingFrame: premiere, frameCount: AVAudioFrameCount(nombre), at: nil)
            n.play(at: heure(max(0, seg.debut - t0)))
        }
    }
}
