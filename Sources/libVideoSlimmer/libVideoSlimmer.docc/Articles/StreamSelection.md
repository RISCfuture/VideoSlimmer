# Stream Selection

Learn how libVideoSlimmer selects which streams to include in the output.

## Overview

When processing a video container, libVideoSlimmer uses sophisticated algorithms to select the best streams based on language preferences, codec priorities, and quality metrics. The goal is to reduce file size by removing unwanted streams while preserving the highest quality content in preferred languages.

![Stream selection flow diagram](stream-selection.png)

## Video Stream Selection

Video stream selection is straightforward: libVideoSlimmer selects the single best video stream based on the following priority order:

1. **Resolution**: Higher resolution (width × height) is preferred
2. **Codec priority**: Codecs earlier in ``Converter/videoPreferredCodecs`` are preferred
3. **Bit rate**: Higher bits per second is preferred
4. **Stream index**: Lower index is preferred (as a tiebreaker)

> Note: FFMPEG can only process one video stream at a time. If a container has multiple video streams, only the best one is selected.

### Transcoding Decision

If the selected video stream uses a codec not in ``Converter/videoPreferredCodecs``, it will be transcoded to ``Converter/videoConversionCodec`` using ``Converter/videoConversionOptions``.

## Audio Stream Selection

Audio selection is more complex because multiple audio streams may be included (one per language, plus optional commentary tracks).

### Default Audio Selection

For each language in ``Converter/languages``, the best "default" audio stream is selected using these priorities:

1. **Channel count**: More channels (e.g., 7.1 > 5.1 > stereo) is preferred
2. **Codec priority**: Codecs earlier in ``Converter/audioPreferredCodecs`` are preferred
3. **Bit depth**: Higher bits per sample is preferred
4. **Sample rate**: Higher sample rate is preferred
5. **Bit rate**: Higher bits per second is preferred
6. **Stream index**: Lower index is preferred

Only streams with ``Disposition/default`` or ``Disposition/dub`` disposition (or no disposition flags) are considered for default selection.

### Other Audio Streams

When ``Converter/includeOtherAudio`` is enabled, additional audio streams are included after the default selection. These include streams with special dispositions like:

- ``Disposition/comment`` (commentary tracks)
- ``Disposition/hearingImpaired`` (audio descriptions)
- ``Disposition/visualImpaired`` (audio for visually impaired)

These streams are sorted using the same priorities as default audio selection.

### No-Language Streams

If ``Converter/preserveNoLanguages`` is enabled, audio streams without language metadata are also considered, following the same selection algorithm.

## Subtitle Stream Selection

Subtitle selection includes all matching streams rather than selecting just one per language. Streams are included if they match a language in ``Converter/languages`` (or have no language when ``Converter/preserveNoLanguages`` is enabled).

Matching subtitle streams are sorted by:

1. **Codec priority**: Codecs earlier in ``Converter/subtitlePreferredCodecs`` are preferred
2. **Stream index**: Lower index is preferred

> Important: Subtitle streams are always copied, never transcoded.

## Attachment Streams

Attachment streams (fonts, images, etc.) are currently not included in the output. Only video, audio, and subtitle streams are processed.

## Example

Consider a container with the following streams:

| Index | Type | Language | Codec | Channels |
|-------|------|----------|-------|----------|
| 0 | Video | — | hevc | — |
| 1 | Audio | eng | truehd | 7.1 |
| 2 | Audio | eng | ac3 | 5.1 |
| 3 | Audio | eng | aac | stereo |
| 4 | Audio | fra | dts | 5.1 |
| 5 | Subtitle | eng | hdmv_pgs | — |
| 6 | Subtitle | fra | subrip | — |

With `languages = ["eng"]` and default codec preferences:

**Selected streams:**
- Stream 0 (video): hevc, copied
- Stream 1 (audio): truehd 7.1 English, copied (best English audio)
- Stream 5 (subtitle): PGS English, copied

**Excluded streams:**
- Stream 2: Lower channel count than stream 1
- Stream 3: Lower channel count than stream 1
- Stream 4: French (not in language list)
- Stream 6: French (not in language list)

## See Also

- <doc:Architecture>
- ``Converter``
- ``Disposition``
