import OSLog

enum Log {
    static let pty = Logger(subsystem: "com.aterm.app", category: "pty")
    static let core = Logger(subsystem: "com.aterm.app", category: "core")
    static let view = Logger(subsystem: "com.aterm.app", category: "view")
    static let bridge = Logger(subsystem: "com.aterm.app", category: "bridge")
}
