# ``libVideoSlimmer``

A library for reading video container metadata and generating stream selection operations.

## Overview

libVideoSlimmer provides the core functionality for analyzing video container files and generating FFMPEG operations to select and process specific streams. It uses `ffprobe` to read container metadata and `ffmpeg` to perform the actual processing.

The library follows a pipeline architecture:

1. **Read**: Use ``Reader`` to analyze a video file and produce a ``Container``
2. **Convert**: Use ``Converter`` to generate ``Operation``s based on language and codec preferences
3. **Process**: Use a ``Processor`` implementation to execute the operations

## Topics

### Essentials

- <doc:Architecture>
- <doc:StreamSelection>

### Reading Container Files

- ``Reader``
- ``Container``

### Stream Types

- ``Stream``
- ``CodedStream``
- ``VideoStream``
- ``AudioStream``
- ``SubtitleStream``
- ``AttachmentStream``
- ``Disposition``

### Generating Operations

- ``Converter``
- ``Operation``

### Processing

- ``Processor``
- ``FFMPEGProcessor``
- ``DryRunProcessor``

### Utilities

- ``which(_:)``

### Errors

- ``Errors``
