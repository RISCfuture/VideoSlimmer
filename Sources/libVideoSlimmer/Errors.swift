import Foundation

/// Errors that can occur during video processing.
public enum Errors: Error {

  /// A subprocess exited with a non-zero exit code.
  ///
  /// - Parameters:
  ///   - process: The name of the process that failed.
  ///   - exitCode: The exit code returned by the process.
  case badExitCode(process: String, exitCode: Int32)

  /// `ffprobe` returned no data for the specified file.
  ///
  /// This typically indicates the file is not a valid media container
  /// or is corrupted.
  ///
  /// - Parameter url: The URL of the file that could not be read.
  case noDataFromFFProbe(url: URL)

  /// The container file does not contain a video stream.
  ///
  /// VideoSlimmer requires at least one video stream to process a file.
  ///
  /// - Parameter filename: The name of the file without a video stream.
  case noVideoStream(filename: String)

  /// An unknown stream type was encountered in the container.
  ///
  /// This is an internal error that occurs during JSON decoding when
  /// `ffprobe` reports an unrecognized stream type.
  ///
  /// - Parameter type: The unrecognized stream type string.
  case unknownStreamType(_ type: String)
}

extension Errors: LocalizedError {
  public var errorDescription: String? {
    switch self {
      case let .badExitCode(process, exitCode):
        return "\(process) exited with code \(exitCode)"
      case .noDataFromFFProbe(let url):
        return "ffprobe returned no data for “\(url.lastPathComponent)”"
      case .noVideoStream(let filename):
        return "File “\(filename)” does not contain a matching video stream"
      case .unknownStreamType(let type):
        return "Unknown stream type “\(type)”; expected video, audio, or subtitle"
    }
  }
}
