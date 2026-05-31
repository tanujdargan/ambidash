#if os(iOS)
import Foundation
import AVFoundation

/// A tiny, optional looping-soundscape wrapper for the FOCUS SESSION timer.
///
/// Design constraints (intentionally conservative — audio is brand-new to the repo):
/// - Uses `AVAudioSession` category `.ambient`, so it MIXES with whatever the user is
///   already playing and RESPECTS the silent switch. It must never hijack the user's
///   music or play through a muted phone.
/// - Loops a single short bundled sound (`numberOfLoops = -1`) when present; if no
///   asset is bundled it is a SAFE NO-OP (the timer still works, just silent). This
///   keeps the feature greenfield-safe without requiring an audio asset to ship.
/// - Stops on session end / app backgrounding (the caller wires `scenePhase`).
///
/// Gated behind `UserPreferences.focusSoundEnabled` by the caller, so existing users
/// who never opt in have zero audio-session activity.
@MainActor
final class FocusSoundService {
    private var player: AVAudioPlayer?
    private var activated = false

    /// Candidate bundled loop assets, in preference order. None are required to exist;
    /// the first one found is used. (Greenfield: the repo ships no audio today, so this
    /// resolves to nil and `start()` becomes a calm no-op until an asset is added.)
    private static let candidates: [(name: String, ext: String)] = [
        ("focus_ambient", "m4a"),
        ("focus_ambient", "mp3"),
        ("focus_ambient", "caf"),
        ("brown_noise", "m4a"),
        ("rain", "m4a"),
    ]

    /// Whether a bundled soundscape asset is actually available. The UI uses this to
    /// avoid offering a toggle that would silently do nothing — honest affordance.
    static var hasBundledSound: Bool { resolvedURL() != nil }

    private static func resolvedURL() -> URL? {
        for c in candidates {
            if let url = Bundle.main.url(forResource: c.name, withExtension: c.ext) {
                return url
            }
        }
        return nil
    }

    /// Begin the looping soundscape. Safe to call repeatedly. No-ops (without error)
    /// when no asset is bundled or audio can't be configured — the timer never depends
    /// on this succeeding.
    func start() {
        guard player == nil else {
            player?.play()
            return
        }
        guard let url = Self.resolvedURL() else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            // .ambient = obeys the silent switch AND mixes with other audio. Crucial so
            // we never interrupt the user's own music or play in silent mode.
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            activated = true

            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 0.6
            p.prepareToPlay()
            p.play()
            player = p
        } catch {
            // Audio is a delight extra, never load-bearing. Fail silent.
            player = nil
            deactivateSession()
        }
    }

    /// Pause without tearing down, for a paused timer.
    func pause() { player?.pause() }

    /// Stop and release everything, deactivating the audio session so we leave no
    /// footprint when the user isn't actively focusing.
    func stop() {
        player?.stop()
        player = nil
        deactivateSession()
    }

    private func deactivateSession() {
        guard activated else { return }
        // Notify others so a paused music app can resume; ignore any error.
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        activated = false
    }

    // No deinit teardown: the owning view stops the soundscape on session end and on
    // scenePhase change, so the player/session are already released before this object
    // goes away. (A nonisolated deinit can't touch the main-actor-isolated player.)
}
#endif
