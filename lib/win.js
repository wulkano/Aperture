'use strict';

const os = require('os');
const util = require('util');
const path = require('path');
const execa = require('execa');
const tempy = require('tempy');
const electronUtil = require('electron-util/node');

const debuglog = util.debuglog('aperture');

const BIN = path.join(electronUtil.fixPathForAsarUnpack(__dirname), '../aperture.exe');

class Aperture {
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
        destination: this.tmpPath,
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
        if (['h264', 'hevc'].indexOf(videoCodec) === -1) {
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
          // `R` is printed by Aperture.CLI when the recording **actually** starts
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

    this.recorder.stdin.setEncoding('ascii');
    this.recorder.stdin.write('a');  // write anything to stdin - stop the recorder gracefully
    this.recorder.stdin.destroy();

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
    return new Map([
      ['h264', 'H264'],
      ['hevc', 'HEVC']
    ]);
  }
});
