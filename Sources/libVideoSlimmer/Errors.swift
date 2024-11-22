import Foundation

public enum Errors: Error {
    case badExitCode(process: String, exitCode: Int32)
    case noDataFromFFProbe(url: URL)
    case noVideoStream(filename: String)
    case unknownStreamType(_ type: String)
}

extension Errors: LocalizedError {
    public var errorDescription: String? {
        switch self {
            case let .badExitCode(process, exitCode):
                return "\(process) exited with code \(exitCode)"
            case let .noDataFromFFProbe(url):
                return "ffprobe returned no data for “\(url.lastPathComponent)”"
            case let .noVideoStream(filename):
                return "File “\(filename)” does not contain a matching video stream"
            case let .unknownStreamType(type):
                return "Unknown stream type “\(type)”; expected video, audio, or subtitle"
        }
    }
}
