import Foundation
import Network
import Combine

@MainActor
class BonjourBrowser: ObservableObject {
    @Published var servers: [DiscoveredServer] = []
    @Published var isSearching: Bool = false
    @Published var error: String?

    private var browser: NWBrowser?
    private var connections: [NWConnection] = []
    private let serviceType = "_iptv-stream._tcp"

    func startBrowsing() {
        stopBrowsing()
        isSearching = true
        error = nil
        servers = []

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browserDescriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: "local.")
        browser = NWBrowser(for: browserDescriptor, using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .failed(let err):
                    self?.error = "Browse failed: \(err.localizedDescription)"
                    self?.isSearching = false
                case .cancelled:
                    self?.isSearching = false
                case .ready:
                    self?.isSearching = true
                default:
                    break
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
                self?.handleBrowseResults(results)
            }
        }

        browser?.start(queue: .main)
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        isSearching = false
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            switch result.endpoint {
            case .service(let name, let type, let domain, _):
                resolveService(name: name, type: type, domain: domain)
            default:
                break
            }
        }
    }

    private func resolveService(name: String, type: String, domain: String) {
        let endpoint = NWEndpoint.service(name: name, type: type, domain: domain, interface: nil)
        let connection = NWConnection(to: endpoint, using: .tcp)

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                       case .hostPort(let host, let port) = innerEndpoint {
                        let hostString: String
                        switch host {
                        case .ipv4(let addr):
                            hostString = self?.ipv4AddressString(addr) ?? "unknown"
                        case .ipv6(let addr):
                            hostString = self?.ipv6AddressString(addr) ?? "unknown"
                        case .name(let hostname, _):
                            hostString = hostname
                        @unknown default:
                            hostString = "unknown"
                        }

                        let server = DiscoveredServer(
                            name: name,
                            host: hostString,
                            port: Int(port.rawValue)
                        )

                        // Avoid duplicates
                        if self?.servers.contains(where: { $0.host == hostString && $0.port == Int(port.rawValue) }) == false {
                            self?.servers.append(server)
                        }
                    }
                    connection.cancel()
                case .failed, .cancelled:
                    if let index = self?.connections.firstIndex(where: { $0 === connection }) {
                        self?.connections.remove(at: index)
                    }
                default:
                    break
                }
            }
        }

        connections.append(connection)
        connection.start(queue: .main)
    }

    private func ipv4AddressString(_ addr: IPv4Address) -> String {
        let data = addr.rawValue
        return "\(data[0]).\(data[1]).\(data[2]).\(data[3])"
    }

    private func ipv6AddressString(_ addr: IPv6Address) -> String {
        // For IPv6, use the debugDescription or format manually
        return addr.debugDescription
    }

    deinit {
        browser?.cancel()
        connections.forEach { $0.cancel() }
    }
}
