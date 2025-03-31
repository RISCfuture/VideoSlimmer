import Foundation

/// Reads media files using `ffprobe` and returns ``Container``s.
public class Reader {
    private let suppressStderr: Bool

    /// The URL to the `ffprobe` executable.
    public var ffprobeURL = (try? which("ffprobe")) ?? URL(filePath: "ffprobe", directoryHint: .notDirectory)

    /**
     Creates a new instance.

     - Parameter suppressStderr: If `true`, `stderr` output will not be printed.
     */
    public init(suppressStderr: Bool = false) {
        self.suppressStderr = suppressStderr
    }

    /**
     Reads a media file and creates a Container.

     - Parameter file: The path to the container file.
     - Returns: The parsed Container.
     */
    public func `open`(file: URL) throws -> Container {
        let arguments = ["-print_format", "json", "-show_format", "-show_streams", file.path(percentEncoded: false)]
        let process = Process()
        let stdout = Pipe()
        process.executableURL = ffprobeURL
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardInput = Pipe()
        if suppressStderr { process.standardError = Pipe() }

        try process.run()
        //        process.waitUntilExit()

        //        guard process.terminationStatus == .zero else {
        //            throw Errors.badExitCode(process: ffprobeURL.lastPathComponent, exitCode: process.terminationStatus)
        //        }
        guard let data = try stdout.fileHandleForReading.readToEnd() else {
            throw Errors.noDataFromFFProbe(url: file)
        }

        return try JSONDecoder().decode(Container.self, from: data)
    }
}

/// Given a ``Container``, generates a list of conversion ``Operation``s
/// according to the parameters of this instance.
public class Converter {

    /// Ordered list of preferred video codecs. Used when ordering and filtering
    /// video streams.
    public var videoPreferredCodecs = ["hevc", "h264"]

    /// Codec to use when transcoding a video stream whose codec is not in
    /// ``videoPreferredCodecs``.
    public var videoConversionCodec = "hevc"

    /// Options to use when transcoding a video stream.
    public var videoConversionOptions = ["-profile:v", "veryslow"]

    /// Ordered list of preferred audio codecs. Used when ordering and filtering
    /// audio streams.
    public var audioPreferredCodecs = ["truehd", "dts", "eac3", "ac3", "flac", "aac"]

    /// Codec to use when transcoding an audio stream whose codec is not in
    /// ``audioPreferredCodecs``.
    public var audioConversionCodec = "truehd"

    /// Options to use when transcoding an audio stream.
    public var audioConversionOptions = [String]()

    /// Ordered list of preferred subtitle codecs. Used when ordering and
    /// filtering subtitle streams.
    public var subtitlePreferredCodecs = ["hdmv_pgs_subtitle", "subrip"]

    /// The container file to convert.
    public let container: Container

    /// The audio and subtitle languages to filter in.
    public let languages: [String]

    /// If `true`, preserves audio and subtitle tracks with no language
    /// metadata.
    public var preserveNoLanguages: Bool

    /// If `true`, includes audio streams other than the stream with the best
    /// codec (e.g., commentary tracks or downmixes).
    public var includeOtherAudio: Bool

    private var bestVideoStream: VideoStream? {
        let comparator = VideoComparator(preferredCodecs: videoPreferredCodecs)
        return container.videoStreams.sorted(using: comparator).first
    }

    private var matchingSubtitleStreams: [SubtitleStream] {
        let comparator = SubtitleComparator(preferredCodecs: subtitlePreferredCodecs)
        return container.subtitleStreams.filter { stream in
            guard let language = stream.language else { return preserveNoLanguages }
            if !languages.contains(language) { return false }
            return true
        }
        .sorted(using: comparator)
    }

    /**
     Creates an instance.

     - Parameter container: The container file to convert.
     - Parameter languages: The audio and subtitle languages to filter in.
     - Parameter preserveNoLanguages: If `true`, preserves audio and subtitle
     tracks with no language metadata.
     - Parameter includeOtherAudio: If `true`, includes audio streams other than
     the stream with the best codec (e.g., commentary tracks or downmixes).
     */
    public init(container: Container, languages: [String], preserveNoLanguages: Bool = false, includeOtherAudio: Bool = false) {
        self.container = container
        self.languages = languages
        self.preserveNoLanguages = preserveNoLanguages
        self.includeOtherAudio = includeOtherAudio
    }

    /// A list of operations to perform to convert the media file according to
    /// the given parameters.
    public func operations() throws -> [Operation] {
        var operations = [Operation]()

        guard let videoStream = bestVideoStream else {
            throw Errors.noVideoStream(filename: container.filename)
        }
        operations.append(operation(forStream: videoStream))

        for language in languages {
            if let audioStream = bestDefaultAudioStream(language: language) {
                operations.append(operation(forStream: audioStream))
            }
            if includeOtherAudio {
                for audioStream in otherAudioStreams(language: language) {
                    operations.append(operation(forStream: audioStream))
                }
            }
        }
        if preserveNoLanguages {
            if let audioStream = bestDefaultAudioStream(language: nil) {
                operations.append(operation(forStream: audioStream))
            }
            if includeOtherAudio {
                for audioStream in otherAudioStreams(language: nil) {
                    operations.append(operation(forStream: audioStream))
                }
            }
        }

        for subtitleStream in matchingSubtitleStreams {
            operations.append(operation(forStream: subtitleStream))
        }

        return operations
    }

    private func bestDefaultAudioStream(language: String?) -> AudioStream? {
        let comparator = AudioComparator(preferredCodecs: audioPreferredCodecs)
        return container.audioStreams.filter { stream in
            if stream.language != language { return false }
            if !stream.dispositions.isEmpty {
                if !stream.dispositions.contains(.default) && !stream.dispositions.contains(.dub) { return false }
            }
            return true
        }
        .sorted(using: comparator).first
    }

    private func otherAudioStreams(language: String?) -> [AudioStream] {
        let comparator = AudioComparator(preferredCodecs: audioPreferredCodecs)
        return container.audioStreams.filter { stream in
            if stream.language != language { return false }
            if stream.dispositions.isEmpty { return false }
            if stream.dispositions.contains(.default) { return false }
            if stream.dispositions.contains(.dub) { return false }
            return true
        }
        .sorted(using: comparator)
    }

    private func operation(forStream stream: VideoStream) -> Operation {
        if videoPreferredCodecs.contains(stream.codecName) {
            return .init(streamIndex: stream.index,
                         streamType: .video,
                         kind: .copy)
        }
        return .init(streamIndex: stream.index,
                     streamType: .video,
                     kind: .convert(codec: videoPreferredCodecs[0], arguments: videoConversionOptions))
    }

    private func operation(forStream stream: AudioStream) -> Operation {
        if audioPreferredCodecs.contains(stream.codecName) {
            return .init(streamIndex: stream.index,
                         streamType: .audio,
                         kind: .copy)
        }
        return .init(streamIndex: stream.index,
                     streamType: .audio,
                     kind: .convert(codec: audioPreferredCodecs[0], arguments: audioConversionOptions))
    }

    private func operation(forStream stream: SubtitleStream) -> Operation {
        .init(streamIndex: stream.index, streamType: .subtitle, kind: .copy)
    }
}
