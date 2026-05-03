import Foundation

/// An operation to perform on a media file as part of a conversion process.
public struct Operation {

  /// The index of the stream to perform the operation on.
  public let streamIndex: UInt

  /// The stream content type.
  public let streamType: StreamType

  /// The type of operation to be performed.
  public let kind: Kind

  private var codecFlag: String { "-c:\(streamType.rawValue)" }
  private var streamSelector: String { "0:\(streamIndex)" }

  /// The FFMPEG `-map` flag and its options.
  public var mapArgument: [String] { ["-map", streamSelector] }

  /// The FFMPEG `-c:x` argument and its options.
  public var codecArgument: [String] {
    switch kind {
      case let .convert(codec, arguments): return [codecFlag, codec] + arguments
      case .copy: return [codecFlag, "copy"]
    }
  }

  /// Stream types.
  public enum StreamType: String {

    /// Video stream.
    case video = "v"

    /// Audio stream.
    case audio = "a"

    /// Subtitle stream.
    case subtitle = "s"
  }

  /// Types of operations.
  public enum Kind: Equatable {

    /// Copy (`-c:x copy`)
    case copy

    /// Convert (`-c:x <codec> [...]`)
    case convert(codec: String, arguments: [String])
  }
}

/// Processors are used to convert or transcode a video file according to a list
/// of an ``operations``.
public protocol Processor {

  /// The operations that will be performed.
  var operations: [Operation] { get }

  /**
   Creates a processor instance.

   - Parameter inputURL: The input video file.
   - Parameter operations: The operations to perform on the video.
   */
  init(inputURL: URL, operations: [Operation])

  /**
   Processes a video file.

   - Parameter outputURL: The output video file.
   */
  func process(outputURL: URL) async throws
}

extension Processor {

  /// Returns `true` if a container does not need any processing (all
  /// operations are ``Operation/Kind-swift.enum/copy``.
  public func isNoop(container: Container) -> Bool {
    if operations.count != container.streams.count { return false }
    return operations.allSatisfy { $0.kind == .copy }
  }
}

/// Processes a video file using FFMPEG.
public final class FFMPEGProcessor: Processor {

  /// The URL path to the `ffmpeg` executable.
  public var ffmpegURL =
    (try? which("ffmpeg")) ?? URL(filePath: "ffmpeg", directoryHint: .notDirectory)

  /// The URL path to the `ffprobe` executable (used for post-process
  /// verification).
  public var ffprobeURL =
    (try? which("ffprobe")) ?? URL(filePath: "ffprobe", directoryHint: .notDirectory)

  /// If `true`, `stderr` output will not be printed.
  public var suppressStderr = false

  /// If `true`, the output file is re-probed after `ffmpeg` exits, and an
  /// error is thrown if any expected stream is missing or empty (zero
  /// packets). Defaults to `true`.
  public var verifyOutput = true

  private let inputURL: URL

  public let operations: [Operation]

  public init(inputURL: URL, operations: [Operation]) {
    self.inputURL = inputURL
    self.operations = operations
  }

  public func process(outputURL: URL) throws {
    let convertArguments = (operations.map(\.codecArgument) + operations.map(\.mapArgument))
      .removingDuplicates().flatMap(\.self)
    let arguments =
      ["-y", "-i", inputURL.path(percentEncoded: false)] + convertArguments + [
        outputURL.path(percentEncoded: false)
      ]
    let process = Process()
    process.executableURL = ffmpegURL
    process.arguments = arguments
    process.standardInput = Pipe()
    if suppressStderr { process.standardError = FileHandle.nullDevice }

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      throw Errors.badExitCode(
        process: ffmpegURL.lastPathComponent,
        exitCode: process.terminationStatus
      )
    }

    if verifyOutput { try verify(outputURL: outputURL) }
  }

  private func verify(outputURL: URL) throws {
    let reader = Reader(suppressStderr: suppressStderr)
    reader.ffprobeURL = ffprobeURL
    let output = try reader.open(file: outputURL, countPackets: true)

    var expectedByType = [Operation.StreamType: Int]()
    for operation in operations { expectedByType[operation.streamType, default: 0] += 1 }
    let actualByType: [Operation.StreamType: Int] = [
      .video: output.videoStreams.count,
      .audio: output.audioStreams.count,
      .subtitle: output.subtitleStreams.count
    ]
    for (type, expected) in expectedByType {
      let actual = actualByType[type] ?? 0
      if actual != expected {
        throw Errors.verificationFailed(
          "expected \(expected) \(type.rawValue) stream(s) in output, found \(actual)"
        )
      }
    }

    for stream in output.videoStreams + (output.audioStreams as [any CodedStream])
      + output.subtitleStreams
    {
      if stream.nbReadPackets == 0 || stream.nbReadPackets == nil {
        throw Errors.verificationFailed(
          "output stream 0:\(stream.index) (\(stream.codecName)) contains no packets"
        )
      }
    }
  }
}

/// Dry-runs a video file, printing what would be processed without processing it.
public final class DryRunProcessor: Processor {
  private let inputURL: URL
  public let operations: [Operation]

  public init(inputURL: URL, operations: [Operation]) {
    self.inputURL = inputURL
    self.operations = operations
  }

  public func process(outputURL: URL) throws {
    print("\(inputURL.path(percentEncoded: false)) -> \(outputURL.path(percentEncoded: false)):")
    for operation in operations {
      print("  \(description(operation: operation))")
    }
  }

  private func description(operation: Operation) -> String {
    switch operation.kind {
      case .copy:
        "0:\(operation.streamIndex) (\(operation.streamType)): copy"
      case .convert(let codec, _):
        "0:\(operation.streamIndex) (\(operation.streamType)): transcode to \(codec)"
    }
  }
}
