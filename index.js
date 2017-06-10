'use strict';
const util = require('util');
const path = require('path');
const execa = require('execa');
const tmp = require('tmp');
const macosVersion = require('macos-version');

const debuglog = util.debuglog('aperture');

const IS_LINUX = process.platform === 'linux';
const IS_MACOS = process.platform === 'darwin';
const IS_WINDOWS = process.platform === 'win32';

class Aperture {
  constructor() {
    if (IS_MACOS) {
      macosVersion.assertGreaterThanOrEqualTo('10.10');
    }

    if (IS_LINUX) {
      throw new Error('Linux is not implemented yet');
    }
  }

  getAudioSources() {
    return execa.stderr(path.join(__dirname, 'swift/main'), ['list-audio-devices']).then(stderr => {
      try {
        return JSON.parse(stderr);
      } catch (err) {
        return stderr;
      }
    });
  }

  startRecording({
    fps = 30,
    cropArea,
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
      }

      if (IS_MACOS) {
        const recorderOpts = [
          this.tmpPath,
          fps,
          cropArea ? `${cropArea.x}:${cropArea.y}:${cropArea.width}:${cropArea.height}` : 'none',
          showCursor,
          highlightClicks,
          displayId,
          audioSourceId
        ];

        this.recorder = execa(path.join(__dirname, 'swift', 'main'), recorderOpts);
      } else if (IS_WINDOWS) {
        const ffmpegArgs = [];

        if (typeof cropArea === 'object') {
          ffmpegArgs.push(
            '-video_size', `${cropArea.width}x${cropArea.height}`,
            '-f', 'gdigrab',
            '-i', 'desktop',
            '-offset_x', cropArea.x,
            '-offset_y', cropArea.y
          );
        } else {
          ffmpegArgs.push(
            '-f', 'gdigrab',
            '-i', 'desktop',
            '-offset_x', 0,
            '-offset_y', 0
          );
        }

        ffmpegArgs.push('-framerate', fps, '-draw_mouse', Number(showCursor === true), this.tmpPath);
        this.recorder = execa('ffmpeg', ffmpegArgs);
      }

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
      }, 5000);

      this.recorder.catch(err => {
        clearTimeout(timeout);
        delete this.recorder;
        reject(err);
      });

      if (IS_MACOS) {
        this.recorder.stdout.setEncoding('utf8');
        this.recorder.stdout.on('data', data => {
          debuglog(data);

          if (data.trim() === 'R') {
            // `R` is printed by Swift when the recording **actually** starts
            clearTimeout(timeout);
            resolve(this.tmpPath);
          }
        });
      } else if (IS_WINDOWS) {
        this.recorder.stderr.on('data', data => {
          debuglog(data);

          if (data.toString('utf8').includes('encoder')) {
            clearTimeout(timeout);
            resolve(this.tmpPath);
          }
        });
      }
    });
  }

  stopRecording() {
    return new Promise((resolve, reject) => {
      if (this.recorder === undefined) {
        reject(new Error('Call `.startRecording()` first'));
        return;
      }

      if (IS_MACOS) {
        this.recorder.then(() => {
          delete this.recorder;
          resolve(this.tmpPath);
        }).catch(reject);

        this.recorder.kill();
      } else if (IS_WINDOWS) {
        this.recorder.stdin.write('quit\n');
        this.recorder.then(() => {
          delete this.recorder;
          resolve(this.tmpPath)
        })
        .catch(err => {
          reject(err.stderr ? new Error(err.stderr) : err);
        });
      }
    });
  }
}

module.exports = () => new Aperture();
