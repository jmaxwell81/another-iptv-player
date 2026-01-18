import SwiftUI

struct ManualEntryView: View {
    @ObservedObject var player: StreamPlayer
    @Binding var showPlayer: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var ipAddress: String = ""
    @State private var port: String = "8080"
    @State private var fullURL: String = ""
    @State private var useFullURL: Bool = false
    @State private var isConnecting: Bool = false
    @State private var errorMessage: String?
    @State private var navigateToPlayer: Bool = false
    @State private var streamURL: URL?

    // Recently used addresses
    @AppStorage("recentAddresses") private var recentAddressesData: Data = Data()

    private var recentAddresses: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: recentAddressesData)) ?? []
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 40) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)

                            Text("Manual Connection")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Enter the IP address shown in the desktop app")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)

                        // Input mode toggle
                        Picker("Input Mode", selection: $useFullURL) {
                            Text("IP + Port").tag(false)
                            Text("Full URL").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 400)

                        if useFullURL {
                            // Full URL input
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Stream URL")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                TextField("http://192.168.1.100:8080/stream", text: $fullURL)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            }
                            .frame(maxWidth: 500)
                        } else {
                            // IP + Port input
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("IP Address")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    TextField("192.168.1.100", text: $ipAddress)
                                        .textFieldStyle(.roundedBorder)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .frame(width: 300)
                                }

                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Port")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    TextField("8080", text: $port)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.numberPad)
                                        .frame(width: 100)
                                }
                            }
                        }

                        // Error message
                        if let error = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.red.opacity(0.1))
                            )
                        }

                        // Connect button
                        Button(action: connect) {
                            HStack {
                                if isConnecting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "play.fill")
                                }
                                Text(isConnecting ? "Connecting..." : "Connect")
                            }
                            .frame(minWidth: 200)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isConnecting || !isValidInput)

                        // Recent addresses
                        if !recentAddresses.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Recent")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                ForEach(recentAddresses, id: \.self) { address in
                                    Button(action: {
                                        applyRecentAddress(address)
                                    }) {
                                        HStack {
                                            Image(systemName: "clock")
                                                .foregroundColor(.secondary)
                                            Text(address)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color(white: 0.15))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: 500)
                        }

                        Spacer()
                    }
                    .padding(40)
                }
            }
            .navigationTitle("Manual Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToPlayer) {
                if let url = streamURL {
                    URLPlayerView(url: url, player: player)
                }
            }
        }
    }

    private var isValidInput: Bool {
        if useFullURL {
            return URL(string: fullURL) != nil && fullURL.hasPrefix("http")
        } else {
            return !ipAddress.isEmpty && !port.isEmpty && Int(port) != nil
        }
    }

    private func connect() {
        errorMessage = nil
        isConnecting = true

        let urlString: String
        if useFullURL {
            urlString = fullURL
        } else {
            urlString = "http://\(ipAddress):\(port)/stream"
        }

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL format"
            isConnecting = false
            return
        }

        // Validate connection by checking health endpoint
        Task {
            do {
                let healthURL = URL(string: "http://\(url.host ?? ""):\(url.port ?? 8080)/health")!
                let (_, response) = try await URLSession.shared.data(from: healthURL)

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    // Save to recent addresses
                    saveRecentAddress(urlString)

                    await MainActor.run {
                        streamURL = url
                        isConnecting = false
                        navigateToPlayer = true
                        dismiss()
                        showPlayer = true
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "Server not responding correctly"
                        isConnecting = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Could not connect: \(error.localizedDescription)"
                    isConnecting = false
                }
            }
        }
    }

    private func saveRecentAddress(_ address: String) {
        var addresses = recentAddresses
        addresses.removeAll { $0 == address }
        addresses.insert(address, at: 0)
        if addresses.count > 5 {
            addresses = Array(addresses.prefix(5))
        }
        if let data = try? JSONEncoder().encode(addresses) {
            recentAddressesData = data
        }
    }

    private func applyRecentAddress(_ address: String) {
        if address.hasPrefix("http") {
            useFullURL = true
            fullURL = address
        } else {
            useFullURL = false
            let components = address.split(separator: ":")
            if components.count >= 2 {
                ipAddress = String(components[0])
                port = String(components[1])
            }
        }
    }
}

#Preview {
    ManualEntryView(player: StreamPlayer(), showPlayer: .constant(false))
}
