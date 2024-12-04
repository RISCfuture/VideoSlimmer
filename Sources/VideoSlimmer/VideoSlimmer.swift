import Foundation
import ArgumentParser
import libVideoSlimmer

/// The entry point for the command line tool.
@main
struct VideoSlimmer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A tool that removes unneeded audio and subtitle tracks from a movie container file using FFMPEG.",
        usage: """
            No transcoding occurs unless necessary; the tracks to be kept are
            preferrably copied to a new container file without modification.
            
            VideoSlimmer supports removing audio and subtitle tracks that don't match
            desired languages, audio codecs, or subtitle codecs.
            """
    )
    
    @Option(name: .long,
            help: "Path to ffmpeg executable",
            transform:  { URL(filePath: $0, directoryHint: .notDirectory) })
    var ffmpeg = try? which("ffmpeg") ?? URL(filePath: "ffmpeg", directoryHint: .notDirectory)
    
    @Option(name: .long,
            help: "Path to ffprobe executable",
            transform:  { URL(filePath: $0, directoryHint: .notDirectory) })
    var ffprobe = try? which("ffprobe") ?? URL(filePath: "ffprobe", directoryHint: .notDirectory)
    
    @Option(name: [.short, .customLong("language")],
            help: "The audio and subtitle track languages to preserve")
    var languages = ["eng"]
    
    @Flag(name: .shortAndLong,
            help: "Preserve audio and subtitle tracks with no language metadata")
    var noLanguage = false
    
    @Option(name: .customLong("video-codec"),
            help: "Preference order for video codecs")
    var videoCodecs = ["hevc", "h264"]
    
    @Option(name: .customLong("audio-codec"),
            help: "Preference order for audio codecs")
    var audioCodecs = ["truehd", "dts", "eac3", "ac3", "flac", "aac"]
    
    @Option(name: .customLong("subtitle-codec"),
            help: "Preference order for subtitle codecs")
    var subtitleCodecs = ["hdmv_pgs_subtitle", "subrip"]
    
    @Option(name: .long,
            help: "The codec to transcode video to when not one of --video-codec values")
    var videoTranscode = "hevc"
    
    @Option(name: .long,
            help: "The codec to transcode audio to when not one of --audio-codec values")
    var audioTranscode = "truehd"
    
    @Option(name: .customLong("video-option"),
            help: "Additional options to pass to FFMPEG when transcoding video")
    var videoOptions = ["-profile:v", "veryslow"]
    
    @Option(name: .customLong("audio-option"),
            help: "Additional options to pass to FFMPEG when transcoding audio")
    var audioOptions = Array<String>()
    
    @Flag(help: "Include audio streams of non-default disposition (e.g., hearing-impaired)")
    var includeOtherAudio = false
    
    @Flag(name: .shortAndLong,
          help: "Instead of performing the conversion, print the operations that will be performed")
    var dryRun = false
    
    @Flag(name: .long,
          help: "Do not process files that would not be changed (all tracks selected)")
    var skipNoops = false
    
    @Flag(name: .long,
          help: "Send ffmpeg and ffprobe output (normally to stderr) to /dev/null")
    var suppressStderr = false
    
    @Argument(help: "The video file to slim",
              completion: .file(),
              transform:  { URL(filePath: $0, directoryHint: .notDirectory) })
    var input: URL
    
    @Argument(help: "The output path for the slimmed video file",
              completion: .file(),
              transform:  { URL(filePath: $0, directoryHint: .notDirectory) })
    var output: URL
    
    /// The entry point for the command line tool.
    mutating func run() async throws {
        let reader = Reader(suppressStderr: suppressStderr)
        if let ffprobe { reader.ffprobeURL = ffprobe }
        let container = try reader.open(file: input)
        
        let converter = Converter(container: container,
                                  languages: languages,
                                  preserveNoLanguages: noLanguage,
                                  includeOtherAudio: includeOtherAudio)
        converter.videoPreferredCodecs = videoCodecs
        converter.videoConversionCodec = videoTranscode
        converter.videoConversionOptions = videoOptions
        converter.audioPreferredCodecs = audioCodecs
        converter.audioConversionCodec = audioTranscode
        converter.audioConversionOptions = audioOptions
        converter.subtitlePreferredCodecs = subtitleCodecs
        let operations = try converter.operations()
        
        let processor: Processor = dryRun ? DryRunProcessor(inputURL: input, operations: operations) : {
            let processor = FFMPEGProcessor(inputURL: input, operations: operations)
            if let ffmpeg { processor.ffmpegURL = ffmpeg }
            processor.suppressStderr = suppressStderr
            return processor
        }()
        
        if skipNoops && processor.isNoop(container: container) { return }
        try await processor.process(outputURL: output)
    }
}
