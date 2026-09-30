import CoreAudio
import Foundation

/// Une sortie audio vue par le Mac (prise jack, carte son USB, HDMI…).
struct SortieAudio: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let nom: String
    let transport: UInt32

    /// Bluetooth et AirPlay : retard et compression, déconseillés pour enregistrer une cassette.
    var deconseillee: Bool {
        [kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE, kAudioDeviceTransportTypeAirPlay].contains(transport)
    }
}

enum SortiesAudio {
    private static func adresse(_ selecteur: AudioObjectPropertySelector,
                                _ portee: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selecteur, mScope: portee, mElement: kAudioObjectPropertyElementMain)
    }

    private static func chaine(_ id: AudioObjectID, _ selecteur: AudioObjectPropertySelector) -> String? {
        var a = adresse(selecteur)
        var valeur: Unmanaged<CFString>?
        var taille = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &taille, &valeur) == noErr, let v = valeur else { return nil }
        return v.takeRetainedValue() as String
    }

    private static func entier(_ id: AudioObjectID, _ selecteur: AudioObjectPropertySelector) -> UInt32 {
        var a = adresse(selecteur)
        var valeur: UInt32 = 0
        var taille = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(id, &a, 0, nil, &taille, &valeur)
        return valeur
    }

    private static func aDesSorties(_ id: AudioObjectID) -> Bool {
        var a = adresse(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput)
        var taille: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &a, 0, nil, &taille) == noErr && taille > 0
    }

    /// Toutes les sorties audio du Mac.
    static func lister() -> [SortieAudio] {
        var a = adresse(kAudioHardwarePropertyDevices)
        let systeme = AudioObjectID(kAudioObjectSystemObject)
        var taille: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systeme, &a, 0, nil, &taille) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(taille) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(systeme, &a, 0, nil, &taille, &ids) == noErr else { return [] }
        return ids.filter(aDesSorties).compactMap { id in
            guard let uid = chaine(id, kAudioDevicePropertyDeviceUID) else { return nil }
            return SortieAudio(id: id, uid: uid, nom: chaine(id, kAudioObjectPropertyName) ?? uid,
                               transport: entier(id, kAudioDevicePropertyTransportType))
        }
    }

    /// La sortie par défaut du Mac.
    static func parDefaut() -> AudioDeviceID? {
        var a = adresse(kAudioHardwarePropertyDefaultOutputDevice)
        var id: AudioDeviceID = 0
        var taille = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &taille, &id) == noErr else { return nil }
        return id
    }

    static func trouver(uid: String?) -> AudioDeviceID? {
        guard let uid else { return parDefaut() }
        return lister().first { $0.uid == uid }?.id ?? parDefaut()
    }
}
