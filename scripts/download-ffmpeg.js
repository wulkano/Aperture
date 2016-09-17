#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const chalk = require('chalk');
const execa = require('execa');
const got = require('got');
const ora = require('ora');

let spinner = ora({text: 'Downloading 7zip', stream: process.stdout}).start();

const FFMPEG_URL = 'http://evermeet.cx/ffmpeg/ffmpeg-81632-g09317e3.7z';

const joinPath = (...str) => path.join(__dirname, ...str);
const which = cmd => execa.sync(joinPath('which.sh'), [cmd]).stdout;
const cmdExists = cmd => which(cmd) !== '';
const logErrorAndExit = msg => {
  spinner.fail();
  console.error(chalk.red(msg));
  process.exit(1);
};

if (process.platform === 'darwin') { // macOS
  if (!cmdExists('brew')) {
    let msg = `${chalk.bold('aperture')} needs ${chalk.bold('brew')} in order to `;
    msg += `automagically download ${chalk.bold('ffmpeg')}.`;
    // TODO add a link to a README.md section that explains what's going on here
    logErrorAndExit(msg);
  }

  execa(joinPath('brew-install-7zip.sh'))
    .then(() => {
      spinner.succeed();
      spinner = ora({text: 'Downloading ffmpeg', stream: process.stdout}).start();
      fs.mkdir(joinPath('..', 'vendor'), err => {
        if (err) {
          if (err.code !== 'EEXIST') {
            logErrorAndExit(err);
          }

          const writeStream = fs.createWriteStream(joinPath('..', 'vendor', 'ffmpeg.7z'));
          writeStream.on('error', err => logErrorAndExit(err));
          writeStream.on('close', () => {
            spinner.succeed();
            spinner = ora({text: 'Bundling ffmpeg', stream: process.stdout}).start();
            execa(joinPath('unzip-ffmpeg.sh'), [joinPath('..', 'vendor')])
              .then(() => spinner.succeed())
              .catch(err => logErrorAndExit(err));
          });

          const ffmpegDownloader = got.stream(FFMPEG_URL);
          ffmpegDownloader.pipe(writeStream);
        }
      });
    })
    .catch(logErrorAndExit);
} else {
  logErrorAndExit(`${chalk.bold('aperture.js')} only support macOS for now`);
}
