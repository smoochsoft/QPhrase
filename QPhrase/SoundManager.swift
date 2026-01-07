import Foundation
import AppKit
import AVFoundation

// MARK: - Sound Manager
class SoundManager {
    static let shared = SoundManager()

    private var successPlayer: AVAudioPlayer?
    private var errorPlayer: AVAudioPlayer?
    private var clickPlayer: AVAudioPlayer?

    private init() {
        setupSounds()
    }

    private func setupSounds() {
        // Use system sounds as fallback
        // These provide a consistent, native feel
    }

    func playSuccess() {
        // Soft, pleasant confirmation sound
        NSSound(named: "Glass")?.play()
    }

    func playError() {
        // Gentle error indication
        NSSound(named: "Basso")?.play()
    }

    func playClick() {
        // Subtle click for interactions
        NSSound(named: "Tink")?.play()
    }

    func playRecordStart() {
        // Indicate hotkey recording started
        NSSound(named: "Pop")?.play()
    }

    func playRecordEnd() {
        // Indicate hotkey recorded
        NSSound(named: "Morse")?.play()
    }
}
