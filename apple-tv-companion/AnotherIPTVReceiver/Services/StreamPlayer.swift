import Foundation
import AVKit
import Combine

@MainActor
class StreamPlayer: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var currentInfo: StreamInfo?
    @Published var player: AVPlayer?

    private var playerItemObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?

    func play(server: DiscoveredServer) async {
        guard let streamURL = server.streamURL else {
            error = "Invalid stream URL"
            return
        }

        isLoading = true
        error = nil

        // Fetch stream info first
        await fetchStreamInfo(from: server)

        // Create and configure player
        let playerItem = AVPlayerItem(url: streamURL)
        let avPlayer = AVPlayer(playerItem: playerItem)

        // Observe player item status
        playerItemObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    self?.isLoading = false
                    self?.isPlaying = true
                case .failed:
                    self?.isLoading = false
                    self?.error = item.error?.localizedDescription ?? "Playback failed"
                default:
                    break
                }
            }
        }

        // Observe time control status
        timeControlObserver = avPlayer.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                switch player.timeControlStatus {
                case .playing:
                    self?.isPlaying = true
                case .paused:
                    self?.isPlaying = false
                case .waitingToPlayAtSpecifiedRate:
                    self?.isLoading = true
                @unknown default:
                    break
                }
            }
        }

        player = avPlayer
        avPlayer.play()
    }

    func play(url: URL) async {
        isLoading = true
        error = nil

        let playerItem = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: playerItem)

        playerItemObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    self?.isLoading = false
                    self?.isPlaying = true
                case .failed:
                    self?.isLoading = false
                    self?.error = item.error?.localizedDescription ?? "Playback failed"
                default:
                    break
                }
            }
        }

        player = avPlayer
        avPlayer.play()
    }

    func stop() {
        player?.pause()
        player = nil
        playerItemObserver?.invalidate()
        timeControlObserver?.invalidate()
        isPlaying = false
        isLoading = false
        currentInfo = nil
    }

    func togglePlayPause() {
        guard let player = player else { return }

        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    private func fetchStreamInfo(from server: DiscoveredServer) async {
        guard let infoURL = server.infoURL else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: infoURL)
            let info = try JSONDecoder().decode(StreamInfo.self, from: data)
            currentInfo = info
        } catch {
            // Info fetch is optional, don't fail playback
            print("Failed to fetch stream info: \(error)")
        }
    }

    deinit {
        playerItemObserver?.invalidate()
        timeControlObserver?.invalidate()
    }
}
