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
    var holdKey: HoldKey = .fn
    var toggleModifier: String = "option"
    var toggleKey: String = "v"
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
}
