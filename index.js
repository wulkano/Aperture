'use strict';
const util = require('util');
const path = require('path');
const execa = require('execa');
const tmp = require('tmp');
const macosVersion = require('macos-version');

const debuglog = util.debuglog('aperture');

const IS_LINUX = process.platform === 'linux';
const IS_MACOS = process.platform === 'darwin';

class Aperture {
  constructor() {
    if (IS_MACOS) {
      macosVersion.assertGreaterThanOrEqualTo('10.10');
    }
  }

  getAudioSources() {
    if (IS_MACOS) {
      return execa.stdout(path.join(__dirname, 'swift/main'), ['list-audio-devices']).then(JSON.parse);
    } else if (IS_LINUX) {
      return execa.stdout('arecord', ['-l']).then(
        stdout => stdout.split('\n').reduce((result, line) => {
          const match = line.match(/card (\d+): ([^,]+),/);

          if (match) {
            result.push(`${match[1]}:${match[2]}`);
          }

          return result;
        }, [])
      );
    }
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
      let cropAreaOpts;

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

        cropAreaOpts = `${cropArea.x}:${cropArea.y}:${cropArea.width}:${cropArea.height}`;
      }

      if (IS_MACOS) {
        const recorderOpts = [
          this.tmpPath,
          fps,
          cropAreaOpts || cropArea,
          showCursor,
          highlightClicks,
          displayId,
          audioSourceId
        ];

        this.recorder = execa(path.join(__dirname, 'swift', 'main'), recorderOpts);
      } else if (IS_LINUX) {
        const args = ['-f', 'x11grab'];

        if (typeof cropArea === 'object') {
          args.push(
            '-video_size', `${cropArea.width}x${cropArea.height}`,
            '-i', `:0+${cropArea.x},${cropArea.y}`
          );
        } else {
          args.push('-i', ':0');
        }

        args.push('-framerate', fps, '-draw_mouse', +(showCursor === true), this.tmpPath);

        this.recorder = execa('ffmpeg', args);
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
      }, 7500);

      this.recorder.catch(err => {
        clearTimeout(timeout);
        delete this.recorder;
        reject(err.stderr ? new Error(err.stderr) : err);
      });

      this.recorder.stdout.setEncoding('utf8');
      if (IS_MACOS) {
        this.recorder.stdout.on('data', data => {
          debuglog(data);

          if (data.trim() === 'R') {
            // `R` is printed by Swift when the recording **actually** starts
            clearTimeout(timeout);
            resolve(this.tmpPath);
          }
        });
      } else if (IS_LINUX) {
        this.recorder.stderr.on('data', data => {
          debuglog(data);

          if (/^frame=\s*\d+\sfps=\s\d+/.test(data.toString('utf8').trim())) {
            // fmpeg prints lines like this while it's reocrding
            // frame=  203 fps= 30 q=-1.0 Lsize=      54kB time=00:00:06.70 bitrate=  65.8kbits/s dup=21 drop=19 speed=0.996x
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

      this.recorder.then(() => {
        delete this.recorder;
        resolve(this.tmpPath);
      }).catch(err => {
        reject(err.stderr ? new Error(err.stderr) : err);
      });

      if (IS_MACOS) {
        this.recorder.kill();
      } else if (IS_LINUX) {
        this.recorder.stdin.setEncoding('utf8');
        this.recorder.stdin.write('q');
      }
    });
  }
}

module.exports = () => new Aperture();
