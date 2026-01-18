import SwiftUI
import AVKit

struct PlayerView: View {
    let server: DiscoveredServer
    @ObservedObject var player: StreamPlayer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let avPlayer = player.player {
                VideoPlayer(player: avPlayer)
                    .ignoresSafeArea()
                    .onAppear {
                        // Enable background audio
                        try? AVAudioSession.sharedInstance().setCategory(.playback)
                        try? AVAudioSession.sharedInstance().setActive(true)
                    }
            }

            // Loading overlay
            if player.isLoading {
                loadingOverlay
            }

            // Error overlay
            if let error = player.error {
                errorOverlay(error)
            }

            // Info overlay (shown briefly on focus)
            VStack {
                infoBar
                Spacer()
            }
        }
        .task {
            await player.play(server: server)
        }
        .onDisappear {
            player.stop()
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(2)

            Text("Connecting to stream...")
                .font(.headline)
                .foregroundColor(.white)

            if let info = player.currentInfo, let title = info.title {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.8))
        )
    }

    private func errorOverlay(_ error: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text("Playback Error")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 20) {
                Button("Go Back") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Retry") {
                    Task {
                        await player.play(server: server)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.9))
        )
    }

    private var infoBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let info = player.currentInfo {
                    if let title = info.title {
                        Text(title)
                            .font(.headline)
                    }
                    if let type = info.type {
                        Text(type.capitalized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(server.name)
                        .font(.headline)
                }
            }

            Spacer()

            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(player.isPlaying ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)

                Text(player.isPlaying ? "Live" : "Buffering")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(30)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.8), Color.clear]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// Separate view for URL-based playback (from manual entry)
struct URLPlayerView: View {
    let url: URL
    @ObservedObject var player: StreamPlayer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let avPlayer = player.player {
                VideoPlayer(player: avPlayer)
                    .ignoresSafeArea()
                    .onAppear {
                        try? AVAudioSession.sharedInstance().setCategory(.playback)
                        try? AVAudioSession.sharedInstance().setActive(true)
                    }
            }

            if player.isLoading {
                VStack(spacing: 24) {
                    ProgressView()
                        .scaleEffect(2)
                    Text("Connecting...")
                        .font(.headline)
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.8))
                )
            }

            if let error = player.error {
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)

                    Text("Error: \(error)")
                        .multilineTextAlignment(.center)

                    Button("Go Back") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.9))
                )
            }
        }
        .task {
            await player.play(url: url)
        }
        .onDisappear {
            player.stop()
        }
    }
}

#Preview {
    PlayerView(
        server: DiscoveredServer(name: "Test Server", host: "192.168.1.100", port: 8080),
        player: StreamPlayer()
    )
}
