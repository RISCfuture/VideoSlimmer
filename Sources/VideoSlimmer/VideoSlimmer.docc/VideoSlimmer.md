# ``VideoSlimmer``

A command-line tool that removes unneeded audio and subtitle tracks from video container files.

## Overview

VideoSlimmer uses FFMPEG to analyze video container files and remove unwanted audio and subtitle tracks based on language and codec preferences. No transcoding occurs unless necessary—tracks are preferably copied to a new container file without modification.

### Key Features

- **Language-based filtering**: Keep only audio and subtitle tracks in specified languages
- **Codec-aware selection**: Prefer higher-quality codecs when multiple tracks exist
- **Quality-based ranking**: Automatically select the best track when multiple options exist
- **Dry-run mode**: Preview what changes would be made without processing
- **No unnecessary transcoding**: Copy streams when possible, transcode only when needed

### Requirements

VideoSlimmer requires FFMPEG to be installed. On macOS, install via Homebrew:

```bash
brew install ffmpeg
```

The `ffmpeg` and `ffprobe` binaries must be in your `PATH`, or you can specify their locations with `--ffmpeg` and `--ffprobe` options.

### Using the Library

For developers who want to use VideoSlimmer programmatically, the **libVideoSlimmer** module provides the core functionality:

| Type | Description |
|------|-------------|
| **Reader** | Reads video container files using `ffprobe` |
| **Container** | Represents a video container with its streams |
| **Converter** | Generates stream selection operations based on preferences |
| **Processor** | Executes operations using `ffmpeg` |

## Topics

### Getting Started

- <doc:Usage>
