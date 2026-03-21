import Foundation
import SwiftUI
import CloneProtocol

final class MenuBarState {
    var focusedAppName = "Finder"
    var nowPlaying: NowPlayingInfo?
}

let menuItems = ["File", "Edit", "View", "Window", "Help"]

/// Client that connects to the cloned daemon to observe now-playing state.
final class MenuBarDaemonClient: @unchecked Sendable {
    private var socketFd: Int32 = -1
    private var readBuffer = Data()
    private var readSource: DispatchSourceRead?
    private let ioQueue = DispatchQueue(label: "clone.menubar.daemon", qos: .userInitiated)
    private let lock = NSLock()
    private(set) var isConnected = false

    var onNowPlayingChanged: ((NowPlayingInfo?) -> Void)?

    func connect() {
        socketFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFd >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        daemonSocketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                pathPtr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    _ = strlcpy(dest, ptr, 104)
                }
            }
        }

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.connect(socketFd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            Darwin.close(socketFd)
            socketFd = -1
            return
        }

        isConnected = true

        let flags = fcntl(socketFd, F_GETFL)
        _ = fcntl(socketFd, F_SETFL, flags | O_NONBLOCK)

        // Subscribe as observer
        send(.observe)

        let source = DispatchSource.makeReadSource(fileDescriptor: socketFd, queue: ioQueue)
        source.setEventHandler { [weak self] in
            self?.handleReadable()
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.socketFd >= 0 {
                Darwin.close(self.socketFd)
                self.socketFd = -1
            }
            self.isConnected = false
        }
        source.resume()
        readSource = source
    }

    func send(_ request: DaemonRequest) {
        guard isConnected, let data = try? WireProtocol.encode(request) else { return }
        data.withUnsafeBytes { ptr in
            _ = Darwin.write(socketFd, ptr.baseAddress!, data.count)
        }
    }

    private func handleReadable() {
        var buf = [UInt8](repeating: 0, count: 65536)
        let bytesRead = Darwin.read(socketFd, &buf, buf.count)
        guard bytesRead > 0 else {
            readSource?.cancel()
            readSource = nil
            isConnected = false
            return
        }

        lock.lock()
        readBuffer.append(contentsOf: buf[0..<bytesRead])
        while let (msg, consumed) = WireProtocol.decode(DaemonResponse.self, from: readBuffer) {
            readBuffer = readBuffer.subdata(in: consumed..<readBuffer.count)
            lock.unlock()
            if case .nowPlayingChanged(let info) = msg {
                onNowPlayingChanged?(info)
            }
            lock.lock()
        }
        lock.unlock()
    }
}

@MainActor func menuBarView(state: MenuBarState, daemonClient: MenuBarDaemonClient?) -> some View {
    let menuTextColor: Color = .primary

    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    let clock = formatter.string(from: Date())

    return HStack(alignment: .center, spacing: 16) {
        // Apple logo placeholder
        Text("\u{F8FF}")
            .font(.system(size: 14))
            .foregroundColor(.primary)

        // Focused app name (bold)
        Text(state.focusedAppName)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.primary)

        // Menu items
        ForEach(menuItems, id: \.self) { item in
            Text(item)
                .font(.system(size: 13))
                .foregroundColor(menuTextColor)
        }

        // Spacer pushes right-side items
        Spacer()

        // Now playing widget
        #if canImport(CloneProtocol)
        if let np = state.nowPlaying {
            nowPlayingWidget(np, daemonClient: daemonClient)
        }
        #endif

        // Clock (right-aligned)
        Text(clock)
            .font(.system(size: 13))
            .foregroundColor(.primary)
    }
    .padding(.horizontal, 12)
    .frame(height: 24)
    .background(Color.adaptive(dark: Color(red: 0.1, green: 0.1, blue: 0.1, opacity: 0.5),
                               light: Color(red: 0.96, green: 0.96, blue: 0.96, opacity: 0.8)))
}

@MainActor func nowPlayingWidget(_ info: NowPlayingInfo, daemonClient: MenuBarDaemonClient?) -> some View {
    let artist = info.artist ?? ""
    let title = info.title ?? ""
    let label = artist.isEmpty ? title : "\(artist) — \(title)"
    let isPlaying = (info.playbackRate ?? 0) > 0

    return HStack(alignment: .center, spacing: 8) {
        // Previous track
        Text("\u{23EE}")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .onTapGesture {
                daemonClient?.send(.remoteCommand(.previousTrack))
            }

        // Play/pause
        Text(isPlaying ? "\u{23F8}" : "\u{23F5}")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .onTapGesture {
                daemonClient?.send(.remoteCommand(.togglePlayPause))
            }

        // Next track
        Text("\u{23ED}")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .onTapGesture {
                daemonClient?.send(.remoteCommand(.nextTrack))
            }

        // Track info
        Text(label)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
    }
}

@main
struct MenuBarApp: App {
    let state = MenuBarState()
    let daemonClient = MenuBarDaemonClient()

    init() {
        daemonClient.onNowPlayingChanged = { [state] info in
            state.nowPlaying = info
        }
        daemonClient.connect()
    }

    var body: some Scene {
        WindowGroup("MenuBar") {
            menuBarView(state: state, daemonClient: daemonClient)
        }
    }

    var configuration: WindowConfiguration {
        WindowConfiguration(title: "MenuBar", width: 1280, height: 24, role: .menubar)
    }

    func onFocusedApp(name: String) {
        state.focusedAppName = name
    }
}
