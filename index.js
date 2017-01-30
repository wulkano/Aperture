'use strict';
const os = require('os');
const path = require('path');
const execa = require('execa');
const tmp = require('tmp');

const isYosemiteOrHigher = process.platform === 'darwin' && Number(os.release().split('.')[0]) >= 14;

function log(...msgs) {
  if (process.env.DEBUG) {
    console.log(...msgs);
  }
}

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
      this.tmpPath = tmp.tmpNameSync({postfix: '.mp4'});

      if (typeof cropArea === 'object') {
        // TODO(matheuss): We should validate the values passed here, because AVFoundation
        // will simply record the entire screen if it receives invalid values
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
        reject(err);
      }, 5000);

      this.recorder.stdout.on('data', data => {
        data = data.toString();
        log(data);

        if (data.replace(/\n|\s/gm, '') === 'R') {
          // `R` is printed by Swift when the recording **actually** starts
          clearTimeout(timeout);
          resolve(this.tmpPath);
        }
      });

      // TODO(matheuss): Not sure if this will ever happen, but if it happens, we
      // should handle it and `reject` the Promise with some useful info, or at least
      // `Unknown Error`
      this.recorder.on('error', reject);

      this.recorder.on('exit', code => {
        clearTimeout(timeout);
        let err;

        // TODO(matheuss): Reject the Promise with more useful info
        // `Malformed args`, for example, is far from enough
        if (code === 0) {
          return; // Success
        } else if (code === 1) {
          err = new Error('Malformed arguments');
        } else if (code === 2) {
          err = new Error('Invalid coordinates');
        } else {
          err = new Error('Unknown error');
        }

        reject(err);
      });
    });
  }

  stopRecording() {
    return new Promise((resolve, reject) => {
      if (this.recorder === undefined) {
        reject(new Error('Call `.startRecording()` first'));
      }

      this.recorder.on('exit', code => {
        // At this point the movie file has been fully written to the filesystem
        if (code === 0) {
          delete this.recorder;

          resolve(this.tmpPath);
          // TODO(matheuss): This file is deleted when the program exits
          // maybe we should add a note about this on the docs or implement a workaround
          delete this.tmpPath;
        } else {
          reject(code); // TODO
        }
      });

      this.recorder.kill();
    });
  }
}

module.exports = () => new Aperture();
