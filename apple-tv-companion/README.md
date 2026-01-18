# Another IPTV Receiver - tvOS Companion App

A tvOS companion app for Another IPTV Player that allows you to receive and play streams from the desktop application on your Apple TV.

## Features

- **Auto-Discovery**: Automatically discovers desktop apps streaming on the local network using Bonjour/mDNS
- **Simple Playback**: One-click to start watching streams from your desktop
- **Manual Entry**: Enter IP address manually if auto-discovery doesn't work
- **Stream Info**: Displays current stream title and type
- **Recent Connections**: Remembers recently used addresses for quick reconnection

## Requirements

- **tvOS 15.0+**
- **Xcode 15+**
- Desktop app running with streaming enabled on the same local network

## Setup Instructions

### Creating the Xcode Project

1. Open Xcode
2. Create a new tvOS App project:
   - File > New > Project
   - Select tvOS > App
   - Product Name: `AnotherIPTVReceiver`
   - Interface: SwiftUI
   - Language: Swift
   - Deployment Target: tvOS 15.0

3. Copy the Swift files from this directory into your Xcode project:
   ```
   AnotherIPTVReceiver/
   ├── App/
   │   ├── AnotherIPTVReceiverApp.swift
   │   └── ContentView.swift
   ├── Services/
   │   ├── BonjourBrowser.swift
   │   └── StreamPlayer.swift
   ├── Views/
   │   ├── ServerListView.swift
   │   ├── PlayerView.swift
   │   └── ManualEntryView.swift
   └── Models/
       └── DiscoveredServer.swift
   ```

4. Configure capabilities:
   - Select your project in the navigator
   - Go to "Signing & Capabilities"
   - No additional capabilities needed (Network access is automatic for tvOS)

5. Build and run on Apple TV simulator or device

### Network Setup

The app uses Bonjour (mDNS) to discover desktop apps on the local network. For this to work:

1. Both devices must be on the same local network (WiFi/Ethernet)
2. The desktop app must be running with streaming enabled
3. mDNS/Bonjour traffic must not be blocked by your router

If auto-discovery doesn't work, use the "Enter IP Manually" option.

## Usage

1. **On Desktop App**:
   - Open any stream in the player
   - Click the cast button (📡) in the player controls
   - The server will start and show you the URL/QR code

2. **On Apple TV**:
   - Open Another IPTV Receiver
   - Your desktop app should appear in the list automatically
   - Select it to start playback
   - Or use "Enter IP Manually" and enter the IP address shown in the desktop app

## Architecture

```
┌─────────────────────────────────────────┐
│  Desktop App (macOS/Windows/Linux)      │
│  ┌─────────────────────────────────┐   │
│  │  HTTP Streaming Server          │   │
│  │  - /stream (proxies IPTV)       │   │
│  │  - /info (stream metadata)      │   │
│  │  - /health (connection check)   │   │
│  └─────────────────────────────────┘   │
│           │                             │
│  ┌────────┴────────────────────────┐   │
│  │  mDNS/Bonjour Registration      │   │
│  │  _iptv-stream._tcp              │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
                    │
          Local Network (WiFi)
                    │
                    ▼
┌─────────────────────────────────────────┐
│  Apple TV (tvOS App)                    │
│  ┌─────────────────────────────────┐   │
│  │  Bonjour Browser                │   │
│  │  Discovers _iptv-stream._tcp    │   │
│  └─────────────────────────────────┘   │
│           │                             │
│  ┌────────┴────────────────────────┐   │
│  │  AVPlayer                       │   │
│  │  Plays stream from server       │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

## Troubleshooting

### Desktop app not appearing

1. Check both devices are on the same network
2. Try refreshing the server list
3. Use manual IP entry as fallback
4. Check if your router blocks mDNS traffic (port 5353 UDP)

### Playback not starting

1. Check the stream is playing on the desktop app
2. Verify the stream URL is accessible
3. Some IPTV streams may have DRM that prevents re-streaming

### Connection drops

- The app will attempt to reconnect automatically
- Check your WiFi signal strength
- Try moving closer to the router

## License

This companion app is part of the Another IPTV Player project.
