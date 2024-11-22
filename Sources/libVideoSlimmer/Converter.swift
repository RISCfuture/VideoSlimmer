import Foundation

public class Reader {
    private let suppressStderr: Bool
    public var ffprobeURL = (try? which("ffprobe")) ?? URL(filePath: "ffprobe", directoryHint: .notDirectory)
    
    public init(suppressStderr: Bool = false) {
        self.suppressStderr = suppressStderr
    }
    
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

public class Converter {
    public var videoPreferredCodecs = ["hevc", "h264"]
    public var videoConversionCodec = "hevc"
    public var videoConversionOptions = ["-profile:v", "veryslow"]
    public var audioPreferredCodecs = ["truehd", "dts", "eac3", "ac3", "flac", "aac"]
    public var audioConversionCodec = "truehd"
    public var audioConversionOptions = Array<String>()
    public var subtitlePreferredCodecs = ["hdmv_pgs_subtitle", "subrip"]
    
    public let container: Container
    public let languages: Array<String>
    public var preserveNoLanguages: Bool
    public var includeOtherAudio: Bool
    
    public init(container: Container, languages: Array<String>, preserveNoLanguages: Bool = false, includeOtherAudio: Bool = false) {
        self.container = container
        self.languages = languages
        self.preserveNoLanguages = preserveNoLanguages
        self.includeOtherAudio = includeOtherAudio
    }
    
    public func operations() throws -> Array<Operation> {
        var operations = Array<Operation>()
        
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
    
    private var bestVideoStream: VideoStream? {
        let comparator = VideoComparator(preferredCodecs: videoPreferredCodecs)
        return container.videoStreams.sorted(using: comparator).first
    }
    
    private func bestDefaultAudioStream(language: String?) -> AudioStream? {
        let comparator = AudioComparator(preferredCodecs: audioPreferredCodecs)
        return container.audioStreams.filter { stream in
            if stream.language != language { return false }
            if !stream.dispositions.isEmpty {
                if !stream.dispositions.contains(.default) && !stream.dispositions.contains(.dub) { return false }
            }
            return true
        }.sorted(using: comparator).first
    }
    
    private func otherAudioStreams(language: String?) -> Array<AudioStream> {
        let comparator = AudioComparator(preferredCodecs: audioPreferredCodecs)
        return container.audioStreams.filter { stream in
            if stream.language != language { return false }
            if stream.dispositions.isEmpty { return false }
            if stream.dispositions.contains(.default) { return false }
            if stream.dispositions.contains(.dub) { return false }
            return true
        }.sorted(using: comparator)
    }
    
    private var matchingSubtitleStreams: Array<SubtitleStream> {
        let comparator = SubtitleComparator(preferredCodecs: subtitlePreferredCodecs)
        return container.subtitleStreams.filter { stream in
            guard let language = stream.language else { return preserveNoLanguages }
            if !languages.contains(language) { return false }
            return true
        }.sorted(using: comparator)
    }
    
    private func operation(forStream stream: VideoStream) -> Operation {
        if videoPreferredCodecs.contains(stream.codecName) {
            return .init(streamIndex: stream.index,
                         streamType: .video,
                         kind: .copy)
        } else {
            return .init(streamIndex: stream.index,
                         streamType: .video,
                         kind: .convert(codec: videoPreferredCodecs[0], arguments: videoConversionOptions))
        }
    }
    
    private func operation(forStream stream: AudioStream) -> Operation {
        if audioPreferredCodecs.contains(stream.codecName) {
            return .init(streamIndex: stream.index,
                         streamType: .audio,
                         kind: .copy)
        } else {
            return .init(streamIndex: stream.index,
                         streamType: .audio,
                         kind: .convert(codec: audioPreferredCodecs[0], arguments: audioConversionOptions))
        }
    }
    
    private func operation(forStream stream: SubtitleStream) -> Operation {
        .init(streamIndex: stream.index, streamType: .subtitle, kind: .copy)
    }
}
