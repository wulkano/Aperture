'use strict';
const util = require('util');
const path = require('path');
const execa = require('execa');
const tmp = require('tmp');
const macosVersion = require('macos-version');

const debuglog = util.debuglog('aperture');

class Aperture {
  constructor() {
    if (process.platform === 'darwin') {
      macosVersion.assertGreaterThanOrEqualTo('10.10');
    }
  }

  getAudioSources() {
    if (process.platform === 'darwin') {
      return execa.stdout(path.join(__dirname, 'swift/main'), ['list-audio-devices']).then(JSON.parse);
    } else if (process.platform === 'linux') {
      return execa.stdout('sh', ['-c', "arecord -l | awk 'match(\$0, /card ([0-9]): ([^,]+),/, result) { print result[1] \":\" result[2] }'"]);
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

      if (process.platform === 'darwin') {
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
      } else if (process.platform === 'linux') {
        const args = ['-f', 'x11grab', '-i'];

        if (typeof cropArea === 'object') {
          args.push(
            `:0+${cropArea.x},${cropArea.y}`,
            '-video_size', `${cropArea.width}x${cropArea.height}`
          );
        } else {
          args.push(':0');
        }

        args.push('-framerate', fps, this.tmpPath);

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
      }, 5000);

      this.recorder.catch(err => {
        clearTimeout(timeout);
        delete this.recorder;
        reject(err.stderr ? new Error(err.stderr) : err);
      });

      this.recorder.stdout.setEncoding('utf8');
      if (process.platform === 'darwin') {
        this.recorder.stdout.on('data', data => {
          debuglog(data);

          if (data.trim() === 'R') {
            // `R` is printed by Swift when the recording **actually** starts
            clearTimeout(timeout);
            resolve(this.tmpPath);
          }
        });
      } else if (process.platform === 'linux') {
        this.recorder.stderr.on('data', data => {
          debuglog(data);

          if (/^frame=\s*\d+\sfps=\s\d+/.test(data.trim())) {
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

      if (process.platform === 'darwin') {
        this.recorder.kill();
      } else if (process.platform === 'linux') {
        this.recorder.stdin.setEncoding('utf8');
        this.recorder.stdin.write('q');
      }
    });
  }
}

module.exports = () => new Aperture();
