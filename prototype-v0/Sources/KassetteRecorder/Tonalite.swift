import AVFoundation

/// Signal de réglage à 1 kHz pour caler le niveau d'enregistrement de la platine.
@MainActor
final class Tonalite: ObservableObject {
    @Published private(set) var active = false
    private let moteur = AVAudioEngine()
    private var source: AVAudioSourceNode?

    /// Signal à −12 dBFS, à peu près le niveau moyen d'une musique masterisée.
    func basculer() {
        if active { moteur.stop(); active = false; return }
        let format = moteur.outputNode.inputFormat(forBus: 0)
        let frequence = 1000.0, echantillonnage = format.sampleRate, amplitude: Float = 0.25
        var phase = 0.0
        let pas = 2 * Double.pi * frequence / echantillonnage
        if source == nil {
            let s = AVAudioSourceNode { _, _, nbImages, liste -> OSStatus in
                let tampons = UnsafeMutableAudioBufferListPointer(liste)
                for i in 0..<Int(nbImages) {
                    let v = amplitude * Float(sin(phase))
                    phase += pas
                    if phase > 2 * Double.pi { phase -= 2 * Double.pi }
                    for t in tampons { t.mData?.assumingMemoryBound(to: Float.self)[i] = v }
                }
                return noErr
            }
            moteur.attach(s)
            moteur.connect(s, to: moteur.mainMixerNode,
                           format: AVAudioFormat(standardFormatWithSampleRate: echantillonnage, channels: max(1, format.channelCount)))
            source = s
        }
        do { try moteur.start(); active = true } catch { active = false }
    }
}
