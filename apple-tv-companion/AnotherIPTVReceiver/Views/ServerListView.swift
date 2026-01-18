import SwiftUI

struct ServerListView: View {
    @StateObject private var browser = BonjourBrowser()
    @StateObject private var player = StreamPlayer()
    @State private var showManualEntry = false
    @State private var showPlayer = false
    @State private var selectedServer: DiscoveredServer?

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color(white: 0.1)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 40) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "tv.and.mediabox")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)

                        Text("Another IPTV Receiver")
                            .font(.title)
                            .fontWeight(.bold)

                        if browser.isSearching {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Searching for desktop app...")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Server list or empty state
                    if browser.servers.isEmpty && !browser.isSearching {
                        emptyState
                    } else {
                        serverList
                    }

                    // Manual entry button
                    Button(action: { showManualEntry = true }) {
                        HStack {
                            Image(systemName: "keyboard")
                            Text("Enter IP Manually")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(60)
            }
            .navigationDestination(isPresented: $showPlayer) {
                if let server = selectedServer {
                    PlayerView(server: server, player: player)
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualEntryView(player: player, showPlayer: $showPlayer)
            }
            .onAppear {
                browser.startBrowsing()
            }
            .onDisappear {
                browser.stopBrowsing()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Desktop Apps Found")
                .font(.headline)

            Text("Make sure your desktop app is running\nand streaming is enabled")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button(action: { browser.startBrowsing() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var serverList: some View {
        VStack(spacing: 24) {
            Text("Available Streams")
                .font(.headline)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 30) {
                    ForEach(browser.servers) { server in
                        ServerCard(server: server) {
                            selectedServer = server
                            showPlayer = true
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct ServerCard: View {
    let server: DiscoveredServer
    let onTap: () -> Void

    @State private var isFocused = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }

                VStack(spacing: 8) {
                    Text(server.name)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text("\(server.host):\(server.port)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 200, height: 220)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 4)
                    )
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .buttonStyle(.plain)
        .focusable(true) { focused in
            isFocused = focused
        }
    }
}

#Preview {
    ServerListView()
}
