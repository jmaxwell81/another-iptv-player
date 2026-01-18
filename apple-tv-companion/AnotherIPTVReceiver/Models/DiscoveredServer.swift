import Foundation

struct DiscoveredServer: Identifiable, Hashable {
    let id: UUID
    let name: String
    let host: String
    let port: Int
    let txtRecord: [String: String]

    var streamURL: URL? {
        URL(string: "http://\(host):\(port)/stream")
    }

    var infoURL: URL? {
        URL(string: "http://\(host):\(port)/info")
    }

    var healthURL: URL? {
        URL(string: "http://\(host):\(port)/health")
    }

    init(id: UUID = UUID(), name: String, host: String, port: Int, txtRecord: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.txtRecord = txtRecord
    }
}

struct StreamInfo: Codable {
    let title: String?
    let type: String?
    let image: String?
}
