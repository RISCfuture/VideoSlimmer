import Foundation

protocol StreamComparator: SortComparator where Compared: CodedStream {
    var preferredCodecs: Array<String> { get }
}

extension StreamComparator {
    func compareCodecs(_ lhs: CodedStream, _ rhs: CodedStream) -> ComparisonResult? {
        let lhsCodecPriority = preferredCodecs.firstIndex(of: lhs.codecName) ?? Int.max,
            rhsCodecPriority = preferredCodecs.firstIndex(of: rhs.codecName) ?? Int.max
        if lhsCodecPriority != rhsCodecPriority {
            return lhsCodecPriority < rhsCodecPriority ? .orderedAscending : .orderedDescending
        } else {
            return nil
        }
    }
    
    func compareIndexes(_ lhs: CodedStream, _ rhs: CodedStream) -> ComparisonResult {
        return lhs.index < rhs.index ? .orderedAscending : .orderedDescending
    }
    
    func compareBPS(_ lhs: CodedStream, _ rhs: CodedStream) -> ComparisonResult? {
        if let lhsBPS = lhs.bitsPerSecond, let rhsBPS = rhs.bitsPerSecond, lhsBPS != rhsBPS {
            return lhsBPS > rhsBPS ? .orderedAscending : .orderedDescending
        } else {
            return nil
        }
    }
}

struct VideoComparator: StreamComparator {
    typealias Compared = VideoStream
    
    var order = SortOrder.forward
    let preferredCodecs: Array<String>
    
    init(preferredCodecs: Array<String>) {
        self.preferredCodecs = preferredCodecs
    }
    
    func compare(_ lhs: VideoStream, _ rhs: VideoStream) -> ComparisonResult {
        compareResolutions(lhs, rhs) ??
            compareCodecs(lhs, rhs) ??
            compareBPS(lhs, rhs) ??
            compareIndexes(lhs, rhs)
    }
    
    private func compareResolutions(_ lhs: VideoStream, _ rhs: VideoStream) -> ComparisonResult? {
        let lhsResolution = lhs.width * lhs.height,
            rhsResolution = rhs.width * rhs.height
        if lhsResolution != rhsResolution {
            return lhsResolution > rhsResolution ? .orderedAscending : .orderedDescending
        } else {
            return nil
        }
    }
}

struct AudioComparator: StreamComparator {
    typealias Compared = AudioStream
    
    var order = SortOrder.forward
    let preferredCodecs: Array<String>
    
    init(preferredCodecs: Array<String>) {
        self.preferredCodecs = preferredCodecs
    }
    
    func compare(_ lhs: AudioStream, _ rhs: AudioStream) -> ComparisonResult {
        compareChannelCount(lhs, rhs) ??
            compareCodecs(lhs, rhs) ??
            compareBitDepth(lhs, rhs) ??
            compareSampleRate(lhs, rhs) ??
            compareBPS(lhs, rhs) ??
            compareIndexes(lhs, rhs)
    }
    
    private func compareChannelCount(_ lhs: AudioStream, _ rhs: AudioStream) -> ComparisonResult? {
        if lhs.channelCount != rhs.channelCount {
            return lhs.channelCount > rhs.channelCount ? .orderedAscending : .orderedDescending
        } else {
            return nil
        }
    }
    
    private func compareBitDepth(_ lhs: AudioStream, _ rhs: AudioStream) -> ComparisonResult? {
        if lhs.bitsPerSample != rhs.bitsPerSample {
            return lhs.bitsPerSample > rhs.bitsPerSample ? .orderedAscending : .orderedDescending
        } else {
            return nil
        }
    }
    
    private func compareSampleRate(_ lhs: AudioStream, _ rhs: AudioStream) -> ComparisonResult? {
        if lhs.sampleRate != rhs.sampleRate {
            return lhs.sampleRate > rhs.sampleRate ? .orderedAscending : .orderedDescending
        } else {
            return nil
        }
    }
}

struct SubtitleComparator: StreamComparator {
    typealias Compared = SubtitleStream
    
    var order = SortOrder.forward
    let preferredCodecs: Array<String>
    
    init(preferredCodecs: Array<String>) {
        self.preferredCodecs = preferredCodecs
    }
    
    func compare(_ lhs: SubtitleStream, _ rhs: SubtitleStream) -> ComparisonResult {
        if let result = compareCodecs(lhs, rhs) { return result }
        return compareIndexes(lhs, rhs)
    }
}
