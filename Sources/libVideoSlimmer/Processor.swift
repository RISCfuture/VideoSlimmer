import Foundation

public struct Operation {
    public let streamIndex: UInt
    public let streamType: StreamType
    public let kind: Kind
    
    private var codecFlag: String { "-c:\(streamType.rawValue)" }
    private var streamSelector: String { "0:\(streamIndex)" }
    
    public var mapArgument: Array<String> { ["-map", streamSelector] }
    public var codecArgument: Array<String> {
        switch kind {
            case let .convert(codec, arguments): return [codecFlag, codec] + arguments
            case .copy: return [codecFlag, "copy"]
        }
    }
    
    public enum StreamType: String {
        case video = "v"
        case audio = "a"
        case subtitle = "s"
    }
    
    public enum Kind: Equatable {
        case copy
        case convert(codec: String, arguments: Array<String>)
    }
}

public protocol Processor {
    var operations: Array<Operation> { get }
    
    init(inputURL: URL, operations: Array<Operation>)
    func process(outputURL: URL) async throws
}

extension Processor {
    public func isNoop(container: Container) -> Bool {
        if operations.count != container.streams.count { return false }
        return operations.allSatisfy { $0.kind == .copy }
    }
}

final public class FFMPEGProcessor: Processor {
    public var ffmpegURL = (try? which("ffmpeg")) ?? URL(filePath: "ffmpeg", directoryHint: .notDirectory)
    public var suppressStderr = false
    
    private let inputURL: URL
    public let operations: Array<Operation>
    
    public init(inputURL: URL, operations: Array<Operation>) {
        self.inputURL = inputURL
        self.operations = operations
    }
    
    public func process(outputURL: URL) throws {
        let convertArguments = (operations.map(\.codecArgument) + operations.map(\.mapArgument)).removingDuplicates().flatMap(\.self),
            arguments = ["-i", inputURL.path(percentEncoded: false)] + convertArguments + [outputURL.path(percentEncoded: false)],
            process = Process()
        process.executableURL = ffmpegURL
        process.arguments = arguments
        process.standardInput = Pipe()
        if suppressStderr { process.standardError = Pipe() }
        
        try process.run()
        process.waitUntilExit()
    }
}

final public class DryRunProcessor: Processor {
    private let inputURL: URL
    public let operations: Array<Operation>
    
    public init(inputURL: URL, operations: Array<Operation>) {
        self.inputURL = inputURL
        self.operations = operations
    }
    
    public func process(outputURL: URL) async throws {
        print("\(inputURL.path(percentEncoded: false)) -> \(outputURL.path(percentEncoded: false)):")
        for operation in operations {
            print("  \(description(operation: operation))")
        }
    }
    
    private func description(operation: Operation) -> String {
        switch operation.kind {
            case .copy:
                "0:\(operation.streamIndex) (\(operation.streamType)): copy"
            case let .convert(codec, _):
                "0:\(operation.streamIndex) (\(operation.streamType)): transcode to \(codec)"
        }
    }
}




