<p align="center">
  <img src="Media/aperture-logo.svg" width="64" height="64">
  <h3 align="center">Aperture</h3>
  <p align="center">Record the screen on macOS</p>
</p>

## Requirements

- macOS 13+
- Xcode 15+
- Swift 5.7+

## Install

Add the following to `Package.swift`:

```swift
.package(url: "https://github.com/wulkano/Aperture", from: "3.0.0")
```

[Or add the package in Xcode.](https://developer.apple.com/documentation/xcode/adding_package_dependencies_to_your_app)

## Docs

### Base Usage

```swift
import Foundation
import Aperture

let recorder = Aperture.Recorder()

let screens = try await Aperture.Devices.screen()

guard let screen = screens.first else {
  // No screens
  exit(1)
}

try await recorder.startRecording(
  target: .screen,
  options: Aperture.RecordingOptions(
    destination: URL(fileURLWithPath: "./screen-recording.mp4"),
    targetID: screen.id,
  )
)

try await Task.sleep(for: .seconds(5))

try await recorder.stopRecording()
```

### Base Options

#### `destination`

Type: `URL`

The filepath where the resulting recording should be written to.

#### `targetID`

Type: `String`

The ID of the target to record

### Base Audio Options

#### `losslessAudio`

Type: `Bool`\
Default: `false`

Will use the lossless `ALAC` codec if enabled, `AAC` otherwise.

#### `recordSystemAudio`

Type: `Bool`\
Default: `false`

Record the system audio.

#### `microphoneDeviceID`

Type: `String?`

A microphone device ID to record.

### Base Video Options

#### `framesPerSecond`

Type: `Int`\
Default: `60`

Number of frames per seconds.

#### `showCursor`

Type: `Bool`\
Default: `true`

Show the cursor in the screen recording.

#### `highlightClicks`

Type: `Bool`\
Default: `false`

Highlight cursor clicks in the screen recording.

Note: [This](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/4360382-showmouseclicks) will only apply on macOS 15+

#### `videoCodec`

Type: `Aperture.VideoCodec`\
Default: `.h264`\
Values: `.h264`, `.hevc`, `.proRes422`, `.proRes4444`

The video codec to be used.

### Recording a screen

Use [`Aeprture.Devices.screen`](#screens) to discover the available screens

And then start recording with `target: .screen`

```swift
try await recorder.startRecording(
  target: .screen,
  options: Aperture.RecordingOptions(
    destination: fileURL,
    targetID: screen.id,
    framesPerSecond: 60,
    cropRect: CGRect(x: 10, y: 10, width: 100, height: 100),
    showCursor: true,
    highlightClicks: true,
    videoCodec: .h264,
    losslessAudio: true,
    recordSystemAudio: true,
    microphoneDeviceID: microphone.id,
  )
)
```

Accepts all the base [video](#base-video-options) and [audio](#base-audio-options) options along with:

#### `cropRect`

Type: `CGRect?`

Record only an area of the screen.

### Recording a window

Use [`Aeprture.Devices.window`](#windows) to discover the available windows

And then start recording with `target: .window`

```swift
try await recorder.startRecording(
  target: .window,
  options: Aperture.RecordingOptions(
    destination: fileURL,
    targetID: window.id,
    framesPerSecond: 60,
    showCursor: true,
    highlightClicks: true,
    videoCodec: .h264,
    losslessAudio: true,
    recordSystemAudio: true,
    microphoneDeviceID: microphone.id,
  )
)
```

Accepts all the base [video](#base-video-options) and [audio](#base-audio-options) options

### Recording only audio

Use [`Aeprture.Devices.audio`](#audio-devices) to discover the available audio devices

And then start recording with `target: .audioOnly`

```swift
try await recorder.startRecording(
  target: .audioOnly,
  options: Aperture.RecordingOptions(
    destination: fileURL,
    losslessAudio: true,
    recordSystemAudio: true,
    microphoneDeviceID: microphone.id,
  )
)
```

Accepts all the base [audio](#base-audio-options) options.

### Recording an external device

Use [`Aeprture.Devices.iOS`](#external-devices) to discover the available external devices

And then start recording with `target: .externalDevice`

```swift
try await recorder.startRecording(
  target: .externalDevice,
  options: Aperture.RecordingOptions(
    destination: fileURL,
    targetID: device.id,
    framesPerSecond: 60,
    videoCodec: .h264,
    losslessAudio: true,
    recordSystemAudio: true,
    microphoneDeviceID: microphone.id,
  )
)
```

Accepts the base [video](#base-video-options) options except for cursor related ones, and all the [audio](#base-audio-options) options.

### Discovering Devices

#### Screens

```swift
let screens = try await Aperture.Devices.screen()
```
<!-- Aperture.Devices.window(excludeDesktopWindows: false, onScreenWindowsOnly: false) -->
#### Windows

```swift
let windows = try await Aperture.Devices.window(excludeDesktopWindows: true, onScreenWindowsOnly: true)
```

##### `excludeDesktopWindows`

Type: `Bool`\
Default: `true`

##### `onScreenWindowsOnly`

Type: `Bool`\
Default: `true`

#### Audio Devices

```swift
let devices = Aperture.Devices.audio()
```

#### External Devices

```swift
let devices = Aperture.Devices.iOS()
```

## Dev

Run `./example.sh` or `./example-ios.sh`.

## Related

- [aperture-node](https://github.com/wulkano/aperture-node) - Node.js wrapper
