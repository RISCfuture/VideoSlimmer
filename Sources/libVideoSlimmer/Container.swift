import Foundation

public protocol Stream: Decodable, Sendable {
    var index: UInt { get }
    var dispositions: Set<Disposition> { get }
    var tags: Dictionary<String, String> { get }
}

public protocol CodedStream: Stream {
    var codecName: String { get }
}

extension Stream {
    public var language: String? { tags["language"] }
    public var bitsPerSecond: UInt? { tags["BPS"] != nil ? UInt(tags["BPS"]!) : nil }
    public var title: String? { tags["title"] }
    
    static func decodeDispositions(_ dispositions: Dictionary<String, UInt8>) -> Set<Disposition> {
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

public struct VideoStream: CodedStream {
    public let index: UInt
    public let codecName: String
    public let profile: String
    public let width: UInt
    public let height: UInt
    public let pixelFormat: String
    public let fieldOrder: FieldOrder?
    public let dispositions: Set<Disposition>
    public let tags: Dictionary<String, String>
    
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
    
    public enum FieldOrder: String, Decodable, Sendable {
        case progressive, tt, bb, tb, bt
    }
}

public struct AudioStream: CodedStream {
    public let index: UInt
    public let codecName: String
    public let profile: String?
    public let sampleFormat: String?
    public let sampleRate: UInt
    public let channelCount: UInt
    public let bitsPerSample: UInt
    public let dispositions: Set<Disposition>
    public let tags: Dictionary<String, String>
    
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

public struct SubtitleStream: CodedStream {
    public let index: UInt
    public let codecName: String
    
    public let dispositions: Set<Disposition>
    public let tags: Dictionary<String, String>
    
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

public struct AttachmentStream: Stream {
    public let index: UInt
    
    public let dispositions: Set<Disposition>
    public let tags: Dictionary<String, String>
    
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

public enum Disposition: String, Decodable, Sendable {
    case `default`
    case dub
    case original
    case comment
    case lyrics
    case karaoke
    case forced
    case hearingImpaired = "hearing_impaired"
    case visualImpaired = "visual_impaired"
    case cleanEffects = "clean_effects"
    case attachedPic = "attached_pic"
    case timedThumbnails = "timed_thumbnails"
    case nonDiegetic = "non_diegetic"
    case captions
    case descriptions
    case metadata
    case dependent
    case stillImage = "still_image"
    case multilayer
}

public struct Container: Decodable, Sendable {
    public let filename: String
    public let duration: Double
    public let size: UInt
    public let tags: Dictionary<String, String>
    
    public let streams: Array<Stream>
    
    public var videoStreams: Array<VideoStream> { streams.compactMap { $0 as? VideoStream } }
    public var audioStreams: Array<AudioStream> { streams.compactMap { $0 as? AudioStream } }
    public var subtitleStreams: Array<SubtitleStream> { streams.compactMap { $0 as? SubtitleStream } }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        var codedStreams = try container.nestedUnkeyedContainer(forKey: .streams)
        var decodedStreams  = Array<Stream>()
        
        while !codedStreams.isAtEnd {
            do {
                let videoStream = try codedStreams.decode(VideoStream.self)
                decodedStreams.append(videoStream)
            } catch (error: Errors.unknownStreamType) {
                do {
                    let audioStream = try codedStreams.decode(AudioStream.self)
                    decodedStreams.append(audioStream)
                } catch (error: Errors.unknownStreamType) {
                    do {
                        let subtitleStream = try codedStreams.decode(SubtitleStream.self)
                        decodedStreams.append(subtitleStream)
                    } catch (error: Errors.unknownStreamType) {
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
