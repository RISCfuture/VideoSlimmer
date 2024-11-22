# VideoSlimmer

VideoSlimmer is a tool that removes unneeded audio and subtitle tracks from a 
movie container file using FFMPEG. No transcoding occurs unless necessary; the
tracks to be kept are preferrably copied to a new container file without
modification.

VideoSlimmer supports removing audio and subtitle tracks that don't match
desired languages, audio codecs, or subtitle codecs.

## Requirements

VideoSlimmer uses FFMPEG. You must have the `ffmpeg` and `ffprobe` binaries in
your `PATH`.

VideoSlimmer currently only works with the macOS operating system. On macOS,
you can install FFMPEG with Homebrew, using `brew install ffmpeg`. FFMPEG
currently compiles only for the x86-64 architecture, and so ARMv7 is not
supported natively.

## Usage

```
USAGE: video-slimmer [<options>] <input> <output>

ARGUMENTS:
  <input>                 The video file to slim
  <output>                The output path for the slimmed video file

OPTIONS:
  --ffmpeg <ffmpeg>       Path to ffmpeg executable
  --ffprobe <ffprobe>     Path to ffprobe executable
  -l, --language <language>
                          The audio and subtitle track languages to preserve (default: eng)
  -n, --no-language       Preserve audio and subtitle tracks with no language metadata
  --video-codec <video-codec>
                          Preference order for video codecs (default: hevc, h264)
  --audio-codec <audio-codec>
                          Preference order for audio codecs (default: truehd, dts, eac3, ac3, flac, aac)
  --subtitle-codec <subtitle-codec>
                          Preference order for subtitle codecs (default: hdmv_pgs_subtitle, subrip)
  --video-transcode <video-transcode>
                          The codec to transcode video to when not one of --video-codec values (default: hevc)
  --audio-transcode <audio-transcode>
                          The codec to transcode audio to when not one of --audio-codec values (default: truehd)
  --video-option <video-option>
                          Additional options to pass to FFMPEG when transcoding video (default: -profile:v, veryslow)
  --audio-option <audio-option>
                          Additional options to pass to FFMPEG when transcoding audio
  --include-other-audio   Include audio streams of non-default disposition (e.g., hearing-impaired)
  -d, --dry-run           Instead of performing the conversion, print the operations that will be performed
  --skip-noops            Do not process files that would not be changed (all tracks selected)
  --suppress-stderr       Send ffmpeg and ffprobe output (normally to stderr) to /dev/null
  -h, --help              Show help information.
```

The order of codecs provided by `--video-codec`, `--audio-codec`, and
`--subtitle-codec` determines which codecs are given priority over others. 

The order of languages provided by `--language` determines the order the audio
and subtitle tracks will appear in the output movie, and thus, which language
is chosen by default.

The `--video-transcode` and `--audio-transcode` options are used to choose an
output codec when the input codec is not in the `--video-codec` or
`--audio-codec` list. If the input codec _is_ in the list, no transcoding
occurs. When transcoding does occur, the `--video-option` and `--audio-option`
options are passed to FFMPEG.

### Video track selection

FFMPEG is capable of working with only one video stream. If a container has
multiple video streams, FFMPEG will automatically select the first one. This is
a limitation of FFMPEG, not VideoSlimmer.

### Audio track selection

Audio tracks whose languages are not included in the `--language` option are
not selected. (Audio tracks without a language will be selected if
`--no-language` is set.) Of the remaining audio tracks, for each language, one
track is selected according to the following priorities:

* the higher channel count,
* the codec higher in the priority order,
* the higher bit depth,
* the higher sample rate,
* the higher bits per second, and
* the lower index number.

If `--include-other-audio` is not set, only audio tracks whose disposition is
"default" or "dub", or who have no disposition flags are chosen according to
this algorithm.

If `--include-other-audio` is set, after one audio track per language is chosen
according to the above algorithm, additional audio tracks are chosen as long as
they have a non-default/dub disposition (e.g., hearing-impaired or commentary)
and they match a selected language. They are re-sorted according to the above
priorities. 

### Subtitle track selection

Subtitle tracks whose languages are not included in the `--language` option are
not selected. (Subtitle tracks without a language will be selected if
`--no-language` is set.) Of the remaining subtitle tracks, for each language,
all matching subtitle tracks are chosen. They are re-sorted according to the
following priorities:

* the codec higher in the priority order, and
* the lower index number.
