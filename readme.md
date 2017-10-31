<p>
  <h1 align="center">Aperture</h1>
  <h4 align="center">Record the screen on macOS</h4>
  <p align="center">
    <a href="https://travis-ci.org/wulkano/aperture">
      <img src="https://travis-ci.org/wulkano/aperture.svg?branch=master" alt="Build Status: macOS">
    </a>
    <a href="https://github.com/sindresorhus/xo">
      <img src="https://img.shields.io/badge/code_style-XO-5ed9c7.svg" alt="XO code style">
    </a>
  </p>
</p>


## Install

```
$ npm install aperture
```

*Requires macOS 10.12 or later.*


## Usage

```js
const delay = require('delay');
const aperture = require('aperture')();

const options = {
  fps: 30,
  cropArea: {
    x: 100,
    y: 100,
    width: 500,
    height: 500
  }
};

(async () => {
  await aperture.startRecording(options);
  await delay(3000);
  console.log(await aperture.stopRecording());
  //=> '/private/var/folders/3x/jf5977fn79jbglr7rk0tq4d00000gn/T/cdf4f7df426c97880f8c10a1600879f7.mp4'
})();
```

See [`example.js`](example.js) if you want to quickly try it out. *(The example requires Node.js 8+)*


## API

### Aperture.audioDevices() -> `Promise<Array>`

Get a list of audio devices.

Example:

```js
[{
  id: 'AppleHDAEngineInput:1B,0,1,0:1',
  name: 'Built-in Microphone'
}]
```

### Aperture.videoCodecs -> `Map`

Get a list of available video codecs. The key is the `videoCodec` option name and the value is the codec name. It only returns `hevc` if you're on macOS 10.13 or newer and your computer supports HEVC hardware encoding.

Example:

```js
Map {
  'h264' => 'H264',
  'hevc' => 'HEVC',
  'proRes422' => 'Apple ProRes 422',
  'proRes4444' => 'Apple ProRes 4444'
}
```

### recorder = `new Aperture()`

### recorder.startRecording([options])

Returns a `Promise` for the path to the screen recording file.

Fullfills when the recording starts or rejects if the recording didn't start after 5 seconds.

### recorder.stopRecording()

Returns a `Promise` for the path to the screen recording file.

#### options

##### fps

Type: `number`<br>
Default: `30`

Number of frames per seconds.

##### cropArea

Type: `Object`<br>
Default: `undefined`

Record only an area of the screen. Accepts an object with `x`, `y`, `width`, `height` properties.

##### showCursor

Type: `boolean`<br>
Default: `true`

Show the cursor in the screen recording.

##### highlightClicks

Type: `boolean`<br>
Default: `false`

Highlight cursor clicks in the screen recording.

Enabling this will also enable the `showCursor` option.

##### displayId

Type: `string`<br>
Default: `main`

Display to record.

##### audioDeviceId

Type: `string`<br>
Default: `undefined`

Audio device to include in the screen recording. Should be one of the `id`'s from `aperture.audioDevices()`.

##### videoCodec

Type: `string`<br>
Default: `h264`<br>
Values: `hevc` `h264` `proRes422` `proRes4444`

The `hevc` codec requires macOS 10.13 or newer. A computer with Intel 6th generation processor or newer is strongly recommended, as otherwise it will use software encoding, which only produces 3 FPS fullscreen recording.

The [`proRes422` and `proRes4444`](https://documentation.apple.com/en/finalcutpro/professionalformatsandworkflows/index.html#chapter=10%26section=2%26tasks=true) codecs are uncompressed data. They will create huge files.


## Why

Aperture was built to fulfill the needs of [Kap](https://github.com/wulkano/kap), providing a JavaScript interface to the **best** available method for recording the screen. That's why it's currently a wrapper for a [Swift script](swift/aperture/main.swift) that records the screen using the [AVFoundation framework](https://developer.apple.com/av-foundation/).

#### But you can use `ffmpeg -f avfoundation...`

Yes, we can, but the performance is terrible:

##### Recording the entire screen with `ffmpeg -f avfoundation -i 1 -y test.mp4`:

![ffmpeg](https://cloud.githubusercontent.com/assets/4721750/19214740/f823d4b6-8d60-11e6-8af3-4726146ef29a.jpg)

##### Recording the entire screen with Aperture:

![aperture](https://cloud.githubusercontent.com/assets/4721750/19214743/11f4aaaa-8d61-11e6-9822-4e83bcdfab24.jpg)


## Linux and Windows

We want to bring Aperture to Linux and Windows, but we don't have time or resources for such tasks (we're Mac users), so **any help is more than welcome**. We just want to enforce two things: **performance** and **quality** – it doesn't matter how (`ffmpeg`, custom built native lib, etc) they are achieved.


## Upcoming

Aperture is in its early days. We're working on adding more features, such as *export to GIF*, compression options, support for multiple displays, support for audio, and much more. Check out our [Aperture](https://github.com/wulkano/kap/issues?q=is%3Aissue+is%3Aopen+label%3Aaperture) issues on **Kap** to learn more.


## Maintainers

- [Matheus Fernandes](https://github.com/matheuss)
- [Sindre Sorhus](https://github.com/sindresorhus)


## License

MIT
