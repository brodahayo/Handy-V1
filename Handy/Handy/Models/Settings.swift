import SwiftUI

// Legacy enum kept for Codable compatibility during migration
enum HotkeyMode: String, Codable, CaseIterable {
    case holdFn = "hold_fn"
    case holdModifier = "hold_modifier"
    case toggle
}

enum HoldKey: String, Codable, CaseIterable {
    case fn
    case option
    case optionShift = "option_shift"
    case command
    case control
}

enum CleanupStyle: String, Codable, CaseIterable, Identifiable {
    case casual
    case professional
    case minimal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .casual: "Casual"
        case .professional: "Professional"
        case .minimal: "Minimal"
        }
    }

    var prompt: String {
        switch self {
        case .casual:
            "You are a text cleanup tool. The user will provide transcribed speech enclosed in <transcription> tags. Clean it into natural, conversational text. Remove filler words (um, uh, like, you know). Fix grammar and punctuation. Keep the tone casual and natural. Do not add information. Do not explain what you did. Return ONLY the cleaned text with no tags, no preamble, and no commentary."
        case .professional:
            "You are a text cleanup tool. The user will provide transcribed speech enclosed in <transcription> tags. Clean it into polished, professional text suitable for emails and documents. Remove filler words. Fix grammar, punctuation, and sentence structure. Make it clear and concise. Do not explain what you did. Return ONLY the cleaned text with no tags, no preamble, and no commentary."
        case .minimal:
            "You are a text cleanup tool. The user will provide transcribed speech enclosed in <transcription> tags. Lightly clean it up, preserving the original wording as much as possible. Only fix obvious grammar errors and remove filler words (um, uh). Do not explain what you did. Return ONLY the cleaned text with no tags, no preamble, and no commentary."
        }
    }
}

enum OverlayStyle: String, Codable, CaseIterable {
    case mini
    case classic
    case none
}

enum OverlayPosition: String, Codable, CaseIterable {
    case topCenter = "top_center"
    case topLeft = "top_left"
    case topRight = "top_right"
    case bottomCenter = "bottom_center"
    case bottomLeft = "bottom_left"
    case bottomRight = "bottom_right"
}

enum SoundPack: String, Codable, CaseIterable, Identifiable {
    case woody
    case crystal
    case bubble
    case chirp
    case synth
    case bloom
    case droplet
    case petal

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

enum TranscriptionMode: String, Codable, CaseIterable {
    case cloud
    case local
    case auto
}

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct AppSettings: Codable {
    var hotkeyMode: HotkeyMode = .holdFn // legacy, kept for Codable
    // Hold-to-dictate: supports modifier-only (holdKeyCode == 65535) or regular key + optional modifiers
    var holdKeyCode: UInt16 = 65535 // 65535 = modifier-only mode
    var holdModifierFlags: UInt = 8388608 // .function (Fn/Globe)
    // Raw key code and modifier flags for toggle shortcut
    var toggleKeyCode: UInt16 = 9 // V
    var toggleModifierFlags: UInt = 524288 // .option
    var holdToDictateEnabled: Bool = true
    var toggleRecordingEnabled: Bool = true

    var cloudProvider: CloudProvider = .groq
    var language: String = "auto"
    var transcriptionMode: TranscriptionMode = .cloud
    var localModelSize: String = "base"

    var cleanupEnabled: Bool = true
    var cleanupStyle: CleanupStyle = .casual
    var contextAware: Bool = true

    var overlayStyle: OverlayStyle = .mini
    var overlayPosition: OverlayPosition = .bottomCenter

    var soundEnabled: Bool = true
    var soundPack: SoundPack = .droplet

    var launchAtLogin: Bool = false
    var dailyGoal: Int = 500

    var appearanceMode: AppearanceMode = .dark

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hotkeyMode = try container.decodeIfPresent(HotkeyMode.self, forKey: .hotkeyMode) ?? .holdFn

        // Migrate from old holdKey/toggleModifier/toggleKey if new fields are missing
        let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
        holdKeyCode = try container.decodeIfPresent(UInt16.self, forKey: .holdKeyCode) ?? 65535
        if let flags = try container.decodeIfPresent(UInt.self, forKey: .holdModifierFlags) {
            holdModifierFlags = flags
        } else if let oldKey = try legacy.decodeIfPresent(HoldKey.self, forKey: .holdKey) {
            holdModifierFlags = Self.migrateHoldKey(oldKey)
        }
        if let code = try container.decodeIfPresent(UInt16.self, forKey: .toggleKeyCode) {
            toggleKeyCode = code
        } else if let oldKey = try legacy.decodeIfPresent(String.self, forKey: .toggleKey) {
            toggleKeyCode = Self.migrateToggleKey(oldKey)
        }
        if let flags = try container.decodeIfPresent(UInt.self, forKey: .toggleModifierFlags) {
            toggleModifierFlags = flags
        } else if let oldMod = try legacy.decodeIfPresent(String.self, forKey: .toggleModifier) {
            toggleModifierFlags = Self.migrateToggleModifier(oldMod)
        }

        holdToDictateEnabled = try container.decodeIfPresent(Bool.self, forKey: .holdToDictateEnabled) ?? true
        toggleRecordingEnabled = try container.decodeIfPresent(Bool.self, forKey: .toggleRecordingEnabled) ?? true
        cloudProvider = try container.decodeIfPresent(CloudProvider.self, forKey: .cloudProvider) ?? .groq
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? "auto"
        transcriptionMode = try container.decodeIfPresent(TranscriptionMode.self, forKey: .transcriptionMode) ?? .cloud
        localModelSize = try container.decodeIfPresent(String.self, forKey: .localModelSize) ?? "base"
        cleanupEnabled = try container.decodeIfPresent(Bool.self, forKey: .cleanupEnabled) ?? true
        cleanupStyle = try container.decodeIfPresent(CleanupStyle.self, forKey: .cleanupStyle) ?? .casual
        contextAware = try container.decodeIfPresent(Bool.self, forKey: .contextAware) ?? true
        overlayStyle = try container.decodeIfPresent(OverlayStyle.self, forKey: .overlayStyle) ?? .mini
        overlayPosition = try container.decodeIfPresent(OverlayPosition.self, forKey: .overlayPosition) ?? .bottomCenter
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        soundPack = try container.decodeIfPresent(SoundPack.self, forKey: .soundPack) ?? .droplet
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        dailyGoal = try container.decodeIfPresent(Int.self, forKey: .dailyGoal) ?? 500
        appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .dark
    }

    // MARK: - Migration helpers (old enum/string fields → raw flags)

    private static func migrateHoldKey(_ key: HoldKey) -> UInt {
        switch key {
        case .fn: return 8388608        // .function
        case .option: return 524288     // .option
        case .optionShift: return 655360 // .option | .shift
        case .command: return 1048576   // .command
        case .control: return 262144    // .control
        }
    }

    private static func migrateToggleModifier(_ name: String) -> UInt {
        switch name.lowercased() {
        case "option", "alt": return 524288
        case "command", "cmd": return 1048576
        case "control", "ctrl": return 262144
        default: return 524288
        }
    }

    private static func migrateToggleKey(_ name: String) -> UInt16 {
        switch name.lowercased() {
        case "v": return 9
        case "d": return 2
        case "r": return 15
        case "t": return 17
        case "space": return 49
        default: return 9
        }
    }

    // Legacy keys used only for migration from old settings format
    private enum LegacyCodingKeys: String, CodingKey {
        case holdKey, toggleModifier, toggleKey
    }
}
