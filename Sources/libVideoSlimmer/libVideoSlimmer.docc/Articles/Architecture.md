# Architecture

Understand how libVideoSlimmer processes video files through its pipeline architecture.

## Overview

libVideoSlimmer follows a modular pipeline design that separates concerns into distinct phases: reading, converting, and processing. This architecture allows for flexible configuration and easy testing through the ``DryRunProcessor``.

![Architecture diagram showing the flow from Reader to Container to Converter to Operations to Processor](architecture.png)

## Pipeline Stages

### Stage 1: Reading

The ``Reader`` class uses `ffprobe` to analyze a video container file and extract metadata about all streams. The result is a ``Container`` object containing:

- File metadata (filename, duration, size, tags)
- All streams (video, audio, subtitle, attachment)

```swift
let reader = Reader()
let container = try reader.open(file: inputURL)
```

### Stage 2: Converting

The ``Converter`` class analyzes the ``Container`` and generates a list of ``Operation``s based on:

- Language preferences
- Codec preferences (video, audio, subtitle)
- Disposition filters (default, dub, commentary, etc.)

```swift
let converter = Converter(
    container: container,
    languages: ["eng"],
    preserveNoLanguages: false,
    includeOtherAudio: false
)
converter.videoPreferredCodecs = ["hevc", "h264"]
converter.audioPreferredCodecs = ["truehd", "dts", "eac3", "ac3", "flac", "aac"]

let operations = try converter.operations()
```

### Stage 3: Processing

A ``Processor`` implementation executes the operations:

- ``FFMPEGProcessor``: Executes the actual FFMPEG command
- ``DryRunProcessor``: Prints what would be executed without running FFMPEG

```swift
let processor = FFMPEGProcessor(inputURL: inputURL, operations: operations)
try await processor.process(outputURL: outputURL)
```

## Key Design Decisions

### Protocol-Based Streams

All stream types conform to the ``Stream`` protocol, with codec-bearing streams additionally conforming to ``CodedStream``. This allows generic handling while preserving type-specific properties.

### Operation-Based Processing

Rather than directly manipulating FFMPEG commands, the library generates ``Operation`` objects that describe what should be done. Each operation specifies:

- Which stream to process (``Operation/streamIndex``)
- What type of stream it is (``Operation/streamType``)
- What to do with it (``Operation/kind``: copy or convert)

### Separation of Concerns

The ``Converter`` knows nothing about FFMPEG command syntax—it only generates abstract operations. The ``Processor`` implementations translate those operations into actual commands, making it easy to add alternative processing backends.

## See Also

- <doc:StreamSelection>
- ``Reader``
- ``Converter``
- ``Processor``
