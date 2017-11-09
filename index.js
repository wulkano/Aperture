'use strict';
const os = require('os');
const util = require('util');
const path = require('path');
const execa = require('execa');
const tempy = require('tempy');
const macosVersion = require('macos-version');
const fileUrl = require('file-url');
const electronUtil = require('electron-util/node');

const debuglog = util.debuglog('aperture');

// Workaround for https://github.com/electron/electron/issues/9459
const BIN = path.join(electronUtil.fixPathForAsarUnpack(__dirname), 'aperture');

const supportsHevcHardwareEncoding = (() => {
  if (!macosVersion.isGreaterThanOrEqualTo('10.13')) {
    return false;
  }

  // Get the Intel Core generation, the `4` in `Intel(R) Core(TM) i7-4850HQ CPU @ 2.30GHz`
  // More info: https://www.intel.com/content/www/us/en/processors/processor-numbers.html
  const result = /Intel.*Core.*i(?:7|5)-(\d)/.exec(os.cpus()[0].model);

  // Intel Core generation 6 or higher supports HEVC hardware encoding
  return result && Number(result[1]) >= 6;
})();

class Aperture {
  constructor() {
    macosVersion.assertGreaterThanOrEqualTo('10.12');
  }

  startRecording({
    fps = 30,
    cropArea = undefined,
    showCursor = true,
    highlightClicks = false,
    displayId = 'main',
    audioDeviceId = undefined,
    videoCodec = undefined
  } = {}) {
    return new Promise((resolve, reject) => {
      if (this.recorder !== undefined) {
        reject(new Error('Call `.stopRecording()` first'));
        return;
      }

      this.tmpPath = tempy.file({extension: 'mp4'});

      if (highlightClicks === true) {
        showCursor = true;
      }

      if (typeof cropArea === 'object') {
        if (typeof cropArea.x !== 'number' ||
            typeof cropArea.y !== 'number' ||
            typeof cropArea.width !== 'number' ||
            typeof cropArea.height !== 'number') {
          reject(new Error('Invalid `cropArea` option object'));
          return;
        }
      }

      const recorderOpts = {
        destination: fileUrl(this.tmpPath),
        fps,
        showCursor,
        highlightClicks,
        displayId,
        audioDeviceId
      };

      if (cropArea) {
        recorderOpts.cropRect = [
          [cropArea.x, cropArea.y],
          [cropArea.width, cropArea.height]
        ];
      }

      if (videoCodec) {
        const codecMap = new Map([
          ['h264', 'avc1'],
          ['hevc', 'hvc1'],
          ['proRes422', 'apcn'],
          ['proRes4444', 'ap4h']
        ]);

        if (!supportsHevcHardwareEncoding) {
          codecMap.delete('hevc');
        }

        if (!codecMap.has(videoCodec)) {
          throw new Error(`Unsupported video codec specified: ${videoCodec}`);
        }

        recorderOpts.videoCodec = codecMap.get(videoCodec);
      }

      this.recorder = execa(BIN, [JSON.stringify(recorderOpts)]);

      const timeout = setTimeout(() => {
        // `.stopRecording()` was called already
        if (this.recorder === undefined) {
          return;
        }

        const err = new Error('Could not start recording within 5 seconds');
        err.code = 'RECORDER_TIMEOUT';
        this.recorder.kill();
        delete this.recorder;
        reject(err);
      }, 10000);

      this.recorder.catch(err => {
        clearTimeout(timeout);
        delete this.recorder;
        reject(err);
      });

      this.recorder.stdout.setEncoding('utf8');
      this.recorder.stdout.on('data', data => {
        debuglog(data);

        if (data.trim() === 'R') {
          // `R` is printed by Swift when the recording **actually** starts
          clearTimeout(timeout);
          resolve(this.tmpPath);
        }
      });
    });
  }

  async stopRecording() {
    if (this.recorder === undefined) {
      throw new Error('Call `.startRecording()` first');
    }

    this.recorder.kill();
    await this.recorder;
    delete this.recorder;

    return this.tmpPath;
  }
}

module.exports = () => new Aperture();

module.exports.audioDevices = async () => {
  const stderr = await execa.stderr(BIN, ['list-audio-devices']);

  try {
    return JSON.parse(stderr);
  } catch (err) {
    return stderr;
  }
};

Object.defineProperty(module.exports, 'videoCodecs', {
  get() {
    const codecs = new Map([
      ['h264', 'H264'],
      ['hevc', 'HEVC'],
      ['proRes422', 'Apple ProRes 422'],
      ['proRes4444', 'Apple ProRes 4444']
    ]);

    if (!supportsHevcHardwareEncoding) {
      codecs.delete('hevc');
    }

    return codecs;
  }
});
