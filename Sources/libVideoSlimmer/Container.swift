import Foundation

/// A video, audio, or subtitle stream.
public protocol Stream: Decodable, Sendable {

    /// The stream index.
    var index: UInt { get }

    /// The stream dispositions.
    var dispositions: Set<Disposition> { get }

    /// The stream tags.
    var tags: [String: String] { get }
}

/// A stream with an associated codec.
public protocol CodedStream: Stream {

    /// The codec name.
    var codecName: String { get }
}

extension Stream {

    /// The stream's language in ISO 639-2 format (applies to audio and subtitle stream).
    public var language: String? { tags["language"] }

    /// The stream bit density (bits per second), if provided.
    public var bitsPerSecond: UInt? { tags["BPS"] != nil ? UInt(tags["BPS"]!) : nil }

    /// The stream title, if provided.
    public var title: String? { tags["title"] }

    static func decodeDispositions(_ dispositions: [String: UInt8]) -> Set<Disposition> {
        var set = Set<Disposition>()
        for (key, value) in dispositions {
            guard value == 1 else { continue }
            guard let disposition = Disposition(rawValue: key) else {
                preconditionFailure("Unknown disposition: \(key)")
            }
            set.insert(disposition)
        }
        return set
    }
}

/// A stream with video data.
public struct VideoStream: CodedStream {
    public let index: UInt
    public let codecName: String
    public let dispositions: Set<Disposition>
    public let tags: [String: String]

    /// The video encoding profile (e.g., `high`).
    public let profile: String

    /// The video width, in pixels.
    public let width: UInt

    /// The video height, in pixels.
    public let height: UInt

    /// The video pixel format tag (e.g., YUV420).
    public let pixelFormat: String

    /// The temporal resolution (interlaced or progressive), if specified.
    public let fieldOrder: FieldOrder?

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .codec_type)
        guard type == "video" else { throw Errors.unknownStreamType(type) }

        index = try container.decode(UInt.self, forKey: .index)
        codecName = try container.decode(String.self, forKey: .codec_name)
        profile = try container.decode(String.self, forKey: .profile)
        width = try container.decode(UInt.self, forKey: .width)
        height = try container.decode(UInt.self, forKey: .height)
        pixelFormat = try container.decode(String.self, forKey: .pix_fmt)
        fieldOrder = try container.decodeIfPresent(FieldOrder.self, forKey: .field_order)
        tags = try container.decodeIfPresent(Dictionary<String, String>.self, forKey: .tags) ?? [:]

        let dispositions = try container.decode(Dictionary<String, UInt8>.self, forKey: .disposition)
        self.dispositions = Self.decodeDispositions(dispositions)
    }

    private enum CodingKeys: String, CodingKey {
        case index, codec_name, profile, width, height, pix_fmt, field_order, tags, disposition, codec_type
    }

    /// Video field orders.
    public enum FieldOrder: String, Decodable, Sendable {

        /// Progressive video: full temporal resolution.
        case progressive

        /// Interlaced video, top field coded and displayed first
        case tt

        /// Interlaced video, bottom field coded and displayed first
        case bb

        /// Interlaced video, top coded first, bottom displayed first
        case tb

        /// Interlaced video, bottom coded first, top displayed first
        case bt
    }
}

/// An stream with audio data.
public struct AudioStream: CodedStream {
    public let index: UInt
    public let codecName: String
    public let dispositions: Set<Disposition>
    public let tags: [String: String]

    /// The audio encoding profile (e.g., `high`).
    public let profile: String?

    /// The audio sample format (e.g., AAC HE v2).
    public let sampleFormat: String?

    /// The audio sample rate, in hertz (e.g., 44100 for 44 kHz).
    public let sampleRate: UInt

    /// The number of bits per sample (e.g., 24-bit audio).
    public let bitsPerSample: UInt

    /// The number of audio channels (e.g., 2 for stereo).
    public let channelCount: UInt

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .codec_type)
        guard type == "audio" else { throw Errors.unknownStreamType(type) }

        index = try container.decode(UInt.self, forKey: .index)
        codecName = try container.decode(String.self, forKey: .codec_name)
        profile = try container.decodeIfPresent(String.self, forKey: .profile)
        sampleFormat = try container.decodeIfPresent(String.self, forKey: .sample_fmt)
        sampleRate = try UInt(container.decode(String.self, forKey: .sample_rate))!
        channelCount = try container.decode(UInt.self, forKey: .channels)
        var bitsPerSample = try container.decode(UInt.self, forKey: .bits_per_sample)
        if bitsPerSample == 0,
           let bitsPerRawSampleStr = try container.decodeIfPresent(String.self, forKey: .bits_per_raw_sample),
           let bitsPerRawSample = UInt(bitsPerRawSampleStr) {
            bitsPerSample = bitsPerRawSample
        }
        self.bitsPerSample = bitsPerSample
        tags = try container.decodeIfPresent(Dictionary<String, String>.self, forKey: .tags) ?? [:]

        let dispositions = try container.decode(Dictionary<String, UInt8>.self, forKey: .disposition)
        self.dispositions = Self.decodeDispositions(dispositions)
    }

    private enum CodingKeys: String, CodingKey {
        case index, codec_name, profile, sample_fmt, sample_rate, channels, bits_per_sample, tags, disposition, codec_type, bits_per_raw_sample
    }
}

/// A stream with subtitle data.
public struct SubtitleStream: CodedStream {
    public let index: UInt
    public let codecName: String

    public let dispositions: Set<Disposition>
    public let tags: [String: String]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .codec_type)
        guard type == "subtitle" else { throw Errors.unknownStreamType(type) }

        index = try container.decode(UInt.self, forKey: .index)
        codecName = try container.decode(String.self, forKey: .codec_name)
        tags = try container.decodeIfPresent(Dictionary<String, String>.self, forKey: .tags) ?? [:]

        let dispositions = try container.decode(Dictionary<String, UInt8>.self, forKey: .disposition)
        self.dispositions = Self.decodeDispositions(dispositions)
    }

    private enum CodingKeys: String, CodingKey {
        case index, codec_name, tags, disposition, codec_type
    }
}

/// A stream with attached file data.
public struct AttachmentStream: Stream {
    public let index: UInt

    public let dispositions: Set<Disposition>
    public let tags: [String: String]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .codec_type)
        guard type == "attachment" else { throw Errors.unknownStreamType(type) }

        index = try container.decode(UInt.self, forKey: .index)
        tags = try container.decodeIfPresent(Dictionary<String, String>.self, forKey: .tags) ?? [:]

        let dispositions = try container.decode(Dictionary<String, UInt8>.self, forKey: .disposition)
        self.dispositions = Self.decodeDispositions(dispositions)
    }

    private enum CodingKeys: String, CodingKey {
        case index, tags, disposition, codec_type
    }
}

/// Stream dispositions provide usage hints for a stream.
public enum Disposition: String, Decodable, Sendable {

    /// Default disposition
    case `default`

    /// Dubbed audio
    case dub

    /// Original audio
    case original

    /// Commentary audio or subtitles
    case comment

    /// Musical lyrics subtitles
    case lyrics

    /// Karaoke audio (without lead singer)
    case karaoke

    /// Forced subtitle track (displayed even when subtitles aee turned off)
    case forced

    /// Subtitles for hearing impaired viewers
    case hearingImpaired = "hearing_impaired"

    /// Audio for visually impaired viewers
    case visualImpaired = "visual_impaired"

    /// Audio with clean effects
    case cleanEffects = "clean_effects"

    /// Attachment with thumbnail or cover image
    case attachedPic = "attached_pic"

    /// Attachment with timed thumbnails
    case timedThumbnails = "timed_thumbnails"

    /// Audio track without music or narration
    case nonDiegetic = "non_diegetic"

    /// Attachment with thumbnail captions
    case captions

    /// Attachment with description text
    case descriptions

    /// Attachment with metadata information
    case metadata

    /// Track dependent on another track
    case dependent

    /// Attachment with still image
    case stillImage = "still_image"

    /// Multilayer track
    case multilayer
}

/// A container file contains one or more ``Stream``s.
public struct Container: Decodable, Sendable {

    /// The name of the container file.
    public let filename: String

    /// The media duration, in seconds.
    public let duration: Double

    /// The media size, in bytes.
    public let size: UInt

    /// The container tags.
    public let tags: [String: String]

    /// The streams in the container.
    public let streams: [Stream]

    /// The video streams.
    public var videoStreams: [VideoStream] { streams.compactMap { $0 as? VideoStream } }

    /// The audio streams.
    public var audioStreams: [AudioStream] { streams.compactMap { $0 as? AudioStream } }

    /// The subtitle streams.
    public var subtitleStreams: [SubtitleStream] { streams.compactMap { $0 as? SubtitleStream } }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        var codedStreams = try container.nestedUnkeyedContainer(forKey: .streams)
        var decodedStreams = [Stream]()

        while !codedStreams.isAtEnd {
            do {
                let videoStream = try codedStreams.decode(VideoStream.self)
                decodedStreams.append(videoStream)
            } catch Errors.unknownStreamType {
                do {
                    let audioStream = try codedStreams.decode(AudioStream.self)
                    decodedStreams.append(audioStream)
                } catch Errors.unknownStreamType {
                    do {
                        let subtitleStream = try codedStreams.decode(SubtitleStream.self)
                        decodedStreams.append(subtitleStream)
                    } catch Errors.unknownStreamType {
                        let attachmentStream = try codedStreams.decode(AttachmentStream.self)
                        decodedStreams.append(attachmentStream)
                    }
                }
            }
        }
        streams = decodedStreams

        let formatContainer = try container.nestedContainer(keyedBy: FormatCodingKeys.self, forKey: .format)
        filename = try formatContainer.decode(String.self, forKey: .filename)
        duration = try Double(formatContainer.decode(String.self, forKey: .duration))!
        size = try UInt(formatContainer.decode(String.self, forKey: .size))!
        tags = try formatContainer.decode(Dictionary<String, String>.self, forKey: .tags)
    }

    private enum CodingKeys: String, CodingKey {
        case format
        case streams
    }

    private enum FormatCodingKeys: String, CodingKey {
        case filename, duration, size, tags
    }
}
