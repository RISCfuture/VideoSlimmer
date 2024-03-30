import Foundation
import ArgumentParser

/// The entry point for the command line tool.
@main
struct VideoSlimmer: ParsableCommand {
    @Option(name: [.short, .customLong("language")],
            help: "The audio and subtitle track languages to preserve")
    var languages = ["eng"]
    
    @Option(name: .shortAndLong,
            help: "A subtitle codec to preserve (e.g., subrip) (default: all codecs)")
    var subtitle = Array<String>()
    
    @Option(name: .long,
            help: "Path to ffmpeg executable",
            transform: { URL(fileURLWithPath: $0) })
    var ffmpeg = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
    
    @Option(name: .shortAndLong,
            help: "Preserve audio and subtitle tracks with no language metadata")
    var noLanguage = false
    
    @Argument(help: "The video file to slim",
              completion: .file())
    var input: String
    
    @Argument(help: "The output path for the slimmed video file",
              completion: .file())
    var output: String
    
    /// The entry point for the command line tool.
    mutating func run() throws {
        let streams = try streams(for: input,
                                  languages: languages.removingDuplicates(),
                                  subtitleCodecs: subtitle.isEmpty ? nil : Set(subtitle),
                                  noLanguage: noLanguage)
        let process = try convert(ffmpeg: ffmpeg, 
                                  streams: streams,
                                  input: input,
                                  output: output)
        process.waitUntilExit()
    }
}
