// host.swift — Ambidash Native Messaging Host for Chrome Extension
// Reads blocked domains from App Group UserDefaults and communicates
// with the Chrome extension via the native messaging protocol (stdin/stdout).
//
// Build:
//   swiftc -O -o ambidash-blocker host.swift
//
// Install:
//   1. Copy the binary to the path specified in ambidash-blocker.json
//   2. Copy ambidash-blocker.json to:
//      ~/Library/Application Support/Google/Chrome/NativeMessagingHosts/
//   3. Update the allowed_origins with your extension ID

import Foundation

// MARK: - Configuration

let appGroupSuite = "group.com.ambidash.restrictions"
let blockedDomainsKey = "applimits.ag.blockedWebDomains"
let isBlockingActiveKey = "applimits.ag.isWebBlockingActive"
let focusEndsAtKey = "applimits.ag.focusEndsAt"
let overrideUntilKey = "applimits.ag.overrideUntil"

// Poll interval for watching UserDefaults changes (seconds)
let pollInterval: TimeInterval = 2.0

// MARK: - Native Messaging Protocol

/// Read a message from stdin using Chrome's native messaging protocol.
/// Messages are length-prefixed with a 4-byte little-endian uint32.
func readMessage() -> [String: Any]? {
    let stdin = FileHandle.standardInput

    // Read 4-byte length prefix
    guard let lengthData = stdin.readData(ofLength: 4), lengthData.count == 4 else {
        return nil
    }

    let lengthBytes = [UInt8](lengthData)
    let length = Int(lengthBytes[0]) |
                 Int(lengthBytes[1]) << 8 |
                 Int(lengthBytes[2]) << 16 |
                 Int(lengthBytes[3]) << 24

    // Sanity check: max message size 1 MB
    guard length > 0, length < 1_048_576 else {
        return nil
    }

    // Read message body
    guard let bodyData = stdin.readData(ofLength: length), bodyData.count == length else {
        return nil
    }

    // Parse JSON
    guard let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
        return nil
    }

    return json
}

/// Write a message to stdout using Chrome's native messaging protocol.
func writeMessage(_ message: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: message) else {
        return
    }

    let stdout = FileHandle.standardOutput

    // Write 4-byte little-endian length prefix
    var length = UInt32(data.count)
    let lengthData = Data(bytes: &length, count: 4)

    stdout.write(lengthData)
    stdout.write(data)
}

// MARK: - UserDefaults Access

func getDefaults() -> UserDefaults? {
    return UserDefaults(suiteName: appGroupSuite)
}

func getStatus() -> [String: Any] {
    let defaults = getDefaults()
    let domains = defaults?.stringArray(forKey: blockedDomainsKey) ?? []
    let isActive = defaults?.bool(forKey: isBlockingActiveKey) ?? false
    let focusEndsAt = defaults?.double(forKey: focusEndsAtKey) ?? 0
    let overrideUntil = defaults?.double(forKey: overrideUntilKey) ?? 0
    let now = Date().timeIntervalSince1970
    let isOverrideActive = overrideUntil > 0 && now < overrideUntil

    let effectiveActive = isActive && !isOverrideActive

    var result: [String: Any] = [
        "blockedDomains": domains,
        "isActive": effectiveActive,
        "isOverrideActive": isOverrideActive,
        "focusEndsAt": focusEndsAt > 0 ? Int(focusEndsAt * 1000) : 0,
        "timestamp": Int(now * 1000)
    ]

    return result
}

// MARK: - Message Handler

func handleMessage(_ message: [String: Any]) -> [String: Any] {
    guard let type = message["type"] as? String else {
        return ["error": "Missing message type"]
    }

    switch type {
    case "getStatus":
        return getStatus()

    case "getBlockedDomains":
        let defaults = getDefaults()
        let domains = defaults?.stringArray(forKey: blockedDomainsKey) ?? []
        return ["blockedDomains": domains]

    case "ping":
        return ["type": "pong", "timestamp": Int(Date().timeIntervalSince1970 * 1000)]

    default:
        return ["error": "Unknown message type: \(type)"]
    }
}

// MARK: - Change Detection

/// Track the last known state to detect changes
var lastDomainsHash: Int = 0
var lastIsActive: Bool = false

func computeDomainsHash() -> Int {
    let defaults = getDefaults()
    let domains = defaults?.stringArray(forKey: blockedDomainsKey) ?? []
    return domains.sorted().joined(separator: ",").hashValue
}

func checkForChanges() {
    let defaults = getDefaults()
    let currentHash = computeDomainsHash()
    let currentActive = defaults?.bool(forKey: isBlockingActiveKey) ?? false

    if currentHash != lastDomainsHash || currentActive != lastIsActive {
        lastDomainsHash = currentHash
        lastIsActive = currentActive

        // Send update to extension (if connected via persistent port)
        // Note: sendNativeMessage is request-response, so we can't push.
        // The extension polls us via alarms, so changes will be picked up
        // on the next poll cycle. We update our internal state here.
    }
}

// MARK: - Main Loop

func main() {
    let stderr = FileHandle.standardError

    // Log to stderr (stdout is reserved for native messaging)
    let logMessage = "[Ambidash Native Host] Starting...\n"
    stderr.write(logMessage.data(using: .utf8) ?? Data())

    // Initialize change tracking
    lastDomainsHash = computeDomainsHash()
    lastIsActive = getDefaults()?.bool(forKey: isBlockingActiveKey) ?? false

    // Start a background timer to watch for UserDefaults changes
    let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
    timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
    timer.setEventHandler {
        checkForChanges()
    }
    timer.resume()

    // Main message loop: read request from stdin, process, write response to stdout
    while true {
        autoreleasepool {
            guard let message = readMessage() else {
                // stdin closed or invalid message — exit
                stderr.write("[Ambidash Native Host] stdin closed, exiting\n".data(using: .utf8) ?? Data())
                exit(0)
            }

            let response = handleMessage(message)
            writeMessage(response)
        }
    }
}

// Entry point
main()
