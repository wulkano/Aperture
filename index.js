'use strict';
const path = require('path');
const execa = require('execa');
const tmp = require('tmp');

// TODO: Log in production with `process.env.DEBUG`
function log(...msgs) {
  if (process.env.DEBUG) {
    console.log(...msgs);
  }
}

class Aperture {
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

      if (typeof cropArea === 'object') { // TODO: Validate this
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

      this.recorder.on('error', reject); // TODO: Handle this

      this.recorder.on('exit', code => {
        clearTimeout(timeout);
        let err;

        if (code === 0) {
          return; // Success
        } else if (code === 1) {
          err = new Error('Malformed arguments'); // TODO
        } else if (code === 2) {
          err = new Error('Invalid coordinates'); // TODO
        } else {
          err = new Error('Unknown error'); // TODO
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
          // TODO: This file is deleted when the program exits
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
