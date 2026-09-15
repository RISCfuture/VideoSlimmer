# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-09-15

### Added

- `VideoSlimmer`, a macOS command-line tool that removes unneeded audio and
  subtitle tracks from a movie container file using FFMPEG, copying the tracks
  to be kept into a new container without transcoding wherever possible. The
  `ffmpeg` and `ffprobe` binaries are found on `PATH` or given with `--ffmpeg`
  and `--ffprobe`.
- Track selection by language with `--language` and `--no-language`; the order
  of the languages determines the order the tracks appear in the output, and
  thus which language a player picks by default.
- One audio track is kept per language, chosen by channel count, codec
  preference, bit depth, sample rate, bitrate, and index number.
  `--include-other-audio` additionally keeps non-default tracks such as
  commentary and hearing-impaired.
- All subtitle tracks matching a selected language are kept, ordered by codec
  preference.
- Codec preference orders for video, audio, and subtitles, with
  `--video-transcode`, `--audio-transcode`, `--video-option`, and
  `--audio-option` applying only when an input codec is not in the preference
  list.
- `--dry-run` to print the operations instead of performing them,
  `--skip-noops` to leave files alone when every track would be kept, and
  `--suppress-stderr` to silence FFMPEG output.

[Unreleased]: https://github.com/RISCfuture/VideoSlimmer/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/RISCfuture/VideoSlimmer/releases/tag/v1.0.0
