import Foundation
import SwiftFFmpeg

/**
 Determines and returns which streams should be preserved from the input video
 based on the provided filter settings. The returned integers are unique stream
 indexes that can be used with FFMPEG when running the conversion.
 
 - Parameter video: The path to the input video.
 - Parameter languages: The set of locales for audio and subtitle files that
 should be preserved. The order that languages appear in this array is the
 order they will appear in the output movie. If omitted, all languages are
 preserved.
 - Parameter subtitleCodecs: The subtitle codecs that should be preserved.
 - Parameter noLanguage: If `true`, audio and subtitle tracks with no language
 metadata will be preserved. (They will appear last in the track list.)
 - Returns: An array of stream indexes that should be preserved when converting
   the video.
 - Throws: If the file could not be opened, or could not be parsed by FFMPEG.
 */
public func streams(for video: String, languages: Array<String>? = nil, subtitleCodecs: Set<String>? = nil, noLanguage: Bool = false) throws -> Array<Int> {
    let context = try AVFormatContext(url: video)
    try context.findStreamInfo()
    
    let videoStream = videoStream(context: context)
    let audioStreams = audioStreams(context: context, languages: languages, noLanguage: noLanguage)
    let subtitleStreams = subtitleStreams(context: context, codecs: subtitleCodecs, languages: languages, noLanguage: noLanguage)
    
    return ([videoStream] + audioStreams + subtitleStreams).map { $0.index }
}

fileprivate func videoStream(context: AVFormatContext) -> AVStream {
    let videoStreams = context.streams.filter { $0.mediaType == .video }
    if videoStreams.count > 1 {
        logger.info("Container has \(videoStreams.count) video streams; choosing stream #0")
    }
    return videoStreams.min(by: { $0.index < $1.index })!
}

fileprivate func audioStreams(context: AVFormatContext, languages: Array<String>?, noLanguage: Bool) -> Array<AVStream> {
    let audioStreams = context.streams.filter { $0.mediaType == .audio }
    var keptStreams = Array<AVStream>()
    
    if let languages = languages {
        for language in languages {
            let streams = audioStreams.filter { $0.metadata["language"] == language }
            keptStreams.append(contentsOf: streams.sorted(by: compareAudioStreams))
        }
    }
    
    if noLanguage {
        let noLanguageStreams = audioStreams.filter { $0.metadata["language"] == nil }
        keptStreams.append(contentsOf: noLanguageStreams)
    }
    
    return keptStreams
}

fileprivate func subtitleStreams(context: AVFormatContext, codecs: Set<String>?, languages: Array<String>?, noLanguage: Bool) -> Array<AVStream> {
    let subtitleStreams = context.streams.filter { $0.mediaType == .subtitle }
    var keptStreams = Array<AVStream>()
    
    if let languages = languages {
        for language in languages {
            let streams = subtitleStreams.filter { $0.metadata["language"] == language }
            let channelCount = SortDescriptor(\AVStream.codecParameters.channelLayout.channelCount, order: .reverse)
            keptStreams.append(contentsOf: streams.sorted(using: [channelCount]))
        }
    }
    
    if noLanguage {
        let noLanguageStreams = subtitleStreams.filter { $0.metadata["language"] == nil }
        keptStreams.append(contentsOf: noLanguageStreams)
    }
    
    if let codecs = codecs {
        keptStreams.removeAll(where: { !codecs.contains($0.codecParameters.codecId.name)})
    }
    
    return keptStreams
}

/**
 Uses the `ffmpeg` binary to remove streams from a video. No transcoding is
 done; streams that are not removed are simply copied. The `ffmpeg` process runs
 separately; a `Process` handle is returned that can be used to monitor or wait
 for it.
 
 In some cases, `ffmpeg` may prompt for user input (e.g., when overwriting an
 existing file).
 
 If the output file has a different extension from the input file, the format of
 the output container may be different from the input container.
 
 - Parameter ffmpeg: The path to the `ffmpeg` binary.
 - Parameter streams: The streams in the container file to keep.
 - Parameter input: The path to the input container file.
 - Parameter output: The path to the output container file to write to.
 - Returns: A handle to the `ffmpeg` process.
 - Throws: If the process could not be started.
 */
public func convert(ffmpeg: URL, streams: Array<Int>, input: String, output: String) throws -> Process {
    let map = streams.flatMap { ["-map", "0:\($0)"] }
    let arguments = [
        "-i", input,
        "-c", "copy"
    ] + map + [
        output
    ]
    
    logger.info("Running ffmpeg \(arguments.joined(separator: " "))")
    return try Process.run(ffmpeg, arguments: arguments)
}

fileprivate let codecPriority = ["truehd", "dts", "ac3", "eac3", "pcm_s24le", "flac", "aac", "mp2"]

// true if stream1 is better than stream2
fileprivate func compareAudioStreams(_ stream1: AVStream, _ stream2: AVStream) -> Bool {
    let stream1CodecPriority = codecPriority.firstIndex(of: stream1.codecParameters.codecId.name)
    let stream2CodecPriority = codecPriority.firstIndex(of: stream2.codecParameters.codecId.name)
    if let stream1CodecPriority = stream1CodecPriority,
       let stream2CodecPriority = stream2CodecPriority {
        return stream1CodecPriority < stream2CodecPriority
    }
    if stream1CodecPriority != nil { return true }
    if stream2CodecPriority != nil { return false }
    
    let stream1Channels = stream1.codecParameters.channelLayout.channelCount
    let stream2Channels = stream2.codecParameters.channelLayout.channelCount
    return stream1Channels > stream2Channels
}
