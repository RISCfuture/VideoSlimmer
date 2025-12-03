# Usage

Learn how to use VideoSlimmer to remove unwanted audio and subtitle tracks from video files.

## Overview

VideoSlimmer is a command-line tool that analyzes video container files and creates a new file containing only the desired audio and subtitle tracks. It uses FFMPEG under the hood but provides a simpler interface focused on track selection.

## Basic Usage

The simplest usage requires only an input file and output file:

```bash
VideoSlimmer input.mkv output.mkv
```

This keeps:
- The best video stream
- The best English audio stream
- All English subtitle streams

## Command-Line Options

### Input and Output

| Argument | Description |
|----------|-------------|
| `<input>` | The video file to process |
| `<output>` | The output path for the processed video file |

### FFMPEG Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `--ffmpeg <path>` | Auto-detected | Path to the `ffmpeg` executable |
| `--ffprobe <path>` | Auto-detected | Path to the `ffprobe` executable |
| `--suppress-stderr` | Off | Suppress FFMPEG output |

### Language Selection

| Option | Default | Description |
|--------|---------|-------------|
| `-l`, `--language <lang>` | `eng` | Audio and subtitle languages to preserve (ISO 639-2) |
| `-n`, `--no-language` | Off | Also preserve tracks with no language metadata |

You can specify multiple languages by repeating the option:

```bash
VideoSlimmer -l eng -l fra input.mkv output.mkv
```

The order determines priority—the first language's audio will be the default track.

### Codec Preferences

| Option | Default | Description |
|--------|---------|-------------|
| `--video-codec <codec>` | `hevc`, `h264` | Preference order for video codecs |
| `--audio-codec <codec>` | `truehd`, `dts`, `eac3`, `ac3`, `flac`, `aac` | Preference order for audio codecs |
| `--subtitle-codec <codec>` | `hdmv_pgs_subtitle`, `subrip` | Preference order for subtitle codecs |

Codecs listed first are preferred. Repeat the option to specify multiple:

```bash
VideoSlimmer --audio-codec truehd --audio-codec dts input.mkv output.mkv
```

### Transcoding Options

When a stream uses a codec not in the preferred list, it must be transcoded:

| Option | Default | Description |
|--------|---------|-------------|
| `--video-transcode <codec>` | `hevc` | Target codec for video transcoding |
| `--audio-transcode <codec>` | `truehd` | Target codec for audio transcoding |
| `--video-option <opt>` | `-profile:v`, `veryslow` | Additional FFMPEG options for video transcoding |
| `--audio-option <opt>` | (none) | Additional FFMPEG options for audio transcoding |

### Audio Track Selection

| Option | Description |
|--------|-------------|
| `--include-other-audio` | Include non-default audio streams (e.g., commentary, hearing-impaired) |

By default, only the best audio stream per language is included. Enable this to also include commentary, audio descriptions, and other alternate tracks.

### Processing Behavior

| Option | Description |
|--------|-------------|
| `-d`, `--dry-run` | Print what would be done without processing |
| `--skip-noops` | Skip files that wouldn't change (all tracks already selected) |

## Examples

### Keep English and French Audio

```bash
VideoSlimmer -l eng -l fra movie.mkv movie-slim.mkv
```

### Preview Changes (Dry Run)

```bash
VideoSlimmer -d movie.mkv output.mkv
```

Output:
```
movie.mkv -> output.mkv:
  0:0 (video): copy
  0:1 (audio): copy
  0:5 (subtitle): copy
```

### Include Commentary Tracks

```bash
VideoSlimmer --include-other-audio movie.mkv movie-with-commentary.mkv
```

### Custom Codec Preferences

Prefer AAC audio over lossless codecs (for smaller files):

```bash
VideoSlimmer --audio-codec aac --audio-codec ac3 movie.mkv output.mkv
```

### Preserve Tracks Without Language Tags

Some files have tracks without language metadata. To keep these:

```bash
VideoSlimmer -l eng -n movie.mkv output.mkv
```

### Batch Processing

Process multiple files with a shell loop:

```bash
for f in *.mkv; do
    VideoSlimmer "$f" "slim/${f}"
done
```

Skip files that don't need processing:

```bash
for f in *.mkv; do
    VideoSlimmer --skip-noops "$f" "slim/${f}"
done
```

## How Track Selection Works

### Video

VideoSlimmer selects the single best video stream based on:
1. Resolution (higher is better)
2. Codec preference order
3. Bit rate
4. Stream index

### Audio

For each specified language, VideoSlimmer selects the best audio stream based on:
1. Channel count (7.1 > 5.1 > stereo)
2. Codec preference order
3. Bit depth
4. Sample rate
5. Bit rate
6. Stream index

With `--include-other-audio`, additional streams (commentary, etc.) are also included.

### Subtitles

All subtitle streams matching the specified languages are included, sorted by codec preference and stream index.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (invalid arguments, file not found, FFMPEG error, etc.) |
