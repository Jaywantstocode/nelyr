import AppKit
import Foundation
import OSLog

@MainActor
final class CapsLockCaffeinateController {
    static let shared = CapsLockCaffeinateController()

    private var process: Process?
    private let logger = Logger(subsystem: "ooo.cavin.dailydesk", category: "caffeinate")

    private init() {}

    var isActive: Bool {
        process?.isRunning == true
    }

    func synchronize(modifierFlags: NSEvent.ModifierFlags = NSEvent.modifierFlags) {
        let shouldBeActive = modifierFlags.contains(.capsLock)

        if shouldBeActive {
            if process?.isRunning != true {
                process = nil
                start()
            }
        } else {
            stop()
        }
    }

    func stop() {
        guard let process else { return }
        if process.isRunning {
            process.terminate()
            logger.notice("Caps Lock disabled; caffeinate stopped")
        }
        self.process = nil
    }

    private func start() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = [
            "-d",
            "-i",
            "-w",
            String(ProcessInfo.processInfo.processIdentifier)
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            self.process = process
            logger.notice("Caps Lock enabled; caffeinate -di started")
        } catch {
            logger.error("Could not start caffeinate: \(error.localizedDescription, privacy: .public)")
        }
    }
}
