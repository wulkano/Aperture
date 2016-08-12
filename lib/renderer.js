const {desktopCapturer} = require('electron'); // eslint-disable-line import/no-extraneous-dependencies
const {checkProcessType} = require('./util');

let recorder; // TODO make this module an Object or something (WARNING: I hate classes)
let recordedBlobs; // TODO 👆 same                             👆👆👆👆👆👆👆👆👆👆👆👆👆👆

function init() {
	checkProcessType('renderer', 'aperture.renderer');
}

/**
 * startRecording - starts the recording session
 *
 * @param {Object} [opts] options
 * @param {Number} [opts.x=0]
 * @param {Number} [opts.y=0]
 * @param {Number} [opts.width=primary display width]
 * @param {Number} [opts.height==primary display height]
 */
function startRecording(opts) {
	return new Promise((resolve, reject) => {
		checkProcessType('renderer', 'startRecording');

		opts = Object.assign(opts || {}, {
			x: 0,
			y: 0,
			width: 9999,
			height: 9999 // TODO multiply the screen bounds by the scale factor
		});

		desktopCapturer.getSources({types: ['screen']}, (err, sources) => {
			if (err) {
				throw err; // TODO: what kind of error can be thrown here?
			}

			const constraints = {
				audio: false,
				video: {
					mandatory: {
						chromeMediaSource: 'desktop',
						chromeMediaSourceId: sources[0].id,
						minFrameRate: 30,
						maxWidth: opts.width,
						maxHeight: opts.height
					}
				}
			};

			navigator.mediaDevices.getUserMedia(constraints).then(stream => {
				recorder = new window.MediaRecorder(stream, {mimeType: 'video/webm', bitsPerSecond: 100000});
				recordedBlobs = []; // TODO: change this when we suport `pauseRecording()`

				recorder.ondataavailable = event => {
					recordedBlobs.push(event.data);
				};

				recorder.start();
				resolve(URL.createObjectURL(stream)); // TODO: return an Object
			}).catch(err => console.error(err));
		});
	});
}

exports.init = init;
exports.startRecording = startRecording;
