<p>
  <h1 align="center">aperture.js</h1>
  <h3 align="center">A library for screen recording </h3>
  <p align="center"><a href="https://github.com/sindresorhus/xo"><img src="https://img.shields.io/badge/code_style-XO-5ed9c7.svg" alt="XO code style"></a></p>
</p>

## Install

```
npm install aperture.js
```

## Usage

```javascript
const aperture = require('aperture.js')();

const cropArea = {x: 100, y: 100, width: 500, height: 500};

aperture.startRecording({fps: 30, cropArea})
  .then(filePath => setTimeout(stopRecording, 3000));

function stopRecording() {
  aperture.stopRecording()
    .then(console.log); //=> /var/folders/r9/65knbqts47x3yg055cd739qh0000gn/T/tmp-15694AAzbYX1vzi2X.mp4
}

```

## Why

`aperture.js` was built to fulfill the needs of [Kap](https://github.com/wulkano/kap), providing a JavaScript interface to the **best** available method for recording the screen.
That's why it's currently a wrapper for a [Swift script](https://github.com/wulkano/aperture.js/blob/master/swift/aperture/main.swift) that records the screen using the [AVFoundation framework](https://developer.apple.com/av-foundation/).

## But you can use `ffmpeg -f avfoundation...`

Yes, we can, but the performance is terrible:

#### Recording the entire screen with `ffmpeg -f avfoundation -i 1 -y test.mp4`:

![ffmpeg](https://cloud.githubusercontent.com/assets/4721750/19214740/f823d4b6-8d60-11e6-8af3-4726146ef29a.jpg)

#### Recording the entire screen with `aperture.js`:

![aperture](https://cloud.githubusercontent.com/assets/4721750/19214743/11f4aaaa-8d61-11e6-9822-4e83bcdfab24.jpg)

## Linux and Windows

We want to bring `aperture.js` to Linux and Windows, but we don't have time and resources for such tasks (we're Mac users), so **any help is more than welcome**. We just want to enforce two things: **performance** and **quality** – doesn't matter how (`ffmpeg`, custom built native lib, etc) they are achieved.

## Upcoming

`aperture.js` it's in its early days. We want it to have more a lot of features, such as *export to GIF*, compression options, support for multiple displays, support for audio and much more. Check out our [`aperture.js`](https://github.com/wulkano/kap/issues?q=is%3Aissue+is%3Aopen+label%3Aaperture.js) issues on **Kap**  to see what we need 😄
