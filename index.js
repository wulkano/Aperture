'use strict';
const os = require('os');
const util = require('util');
const path = require('path');
const execa = require('execa');
const tmp = require('tmp');

const debuglog = util.debuglog('aperture');
const isYosemiteOrHigher = process.platform === 'darwin' && Number(os.release().split('.')[0]) >= 14;

class Aperture {
  constructor() {
    if (!isYosemiteOrHigher) {
      throw new Error('Requires macOS 10.10 or higher');
    }
  }

  getAudioSources() {
    return execa.stdout(path.join(__dirname, 'swift/main'), ['list-audio-devices']).then(JSON.parse);
  }

  startRecording({
    fps = 30,
    cropArea = 'none',
    showCursor = true,
    highlightClicks = false,
    displayId = 'main',
    audioSourceId = 'none'
  } = {}) {
    return new Promise((resolve, reject) => {
      if (this.recorder !== undefined) {
        reject(new Error('Call `.stopRecording()` first'));
        return;
      }

      if (highlightClicks === true) {
        showCursor = true;
      }

      this.tmpPath = tmp.tmpNameSync({postfix: '.mp4'});

      if (typeof cropArea === 'object') {
        if (typeof cropArea.x !== 'number' ||
            typeof cropArea.y !== 'number' ||
            typeof cropArea.width !== 'number' ||
            typeof cropArea.height !== 'number') {
          reject(new Error('Invalid `cropArea` option object'));
          return;
        }

        cropArea = `${cropArea.x}:${cropArea.y}:${cropArea.width}:${cropArea.height}`;
      }

      const recorderOpts = [
        this.tmpPath,
        fps,
        cropArea,
        showCursor,
        highlightClicks,
        displayId,
        audioSourceId
      ];

      this.recorder = execa(path.join(__dirname, 'swift', 'main'), recorderOpts);

      const timeout = setTimeout(() => {
        const err = new Error('Could not start recording within 5 seconds');
        err.code = 'RECORDER_TIMEOUT';
        this.recorder.kill();
        delete this.recorder;
        reject(err);
      }, 5000);

      this.recorder.catch(err => {
        clearTimeout(timeout);
        delete this.recorder;
        reject(err.stderr ? new Error(err.stderr) : err);
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

  stopRecording() {
    return new Promise((resolve, reject) => {
      if (this.recorder === undefined) {
        reject(new Error('Call `.startRecording()` first'));
        return;
      }

      this.recorder.then(() => {
        delete this.recorder;
        resolve(this.tmpPath);
      }).catch(err => {
        reject(err.stderr ? new Error(err.stderr) : err);
      });

      this.recorder.kill();
    });
  }
}

module.exports = () => new Aperture();
