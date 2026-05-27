import Foundation
import os.log

enum ErrorLogger {
    private static let logger = Logger(subsystem: "com.ambidash.app", category: "errors")

    static func log(_ error: Error, context: String, file: String = #file, line: Int = #line) {
        let filename = URL(fileURLWithPath: file).lastPathComponent
        logger.error("[\(filename):\(line)] \(context): \(error.localizedDescription)")
    }

    static func warning(_ message: String, file: String = #file, line: Int = #line) {
        let filename = URL(fileURLWithPath: file).lastPathComponent
        logger.warning("[\(filename):\(line)] \(message)")
    }

    static func info(_ message: String) {
        logger.info("\(message)")
    }
}
