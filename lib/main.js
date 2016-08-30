const {rename} = require('fs');

const macOS = require('nodobjc');
const pify = require('pify');
const tmp = require('tmp');

class Aperture {
	constructor() {
		macOS.framework('Foundation');
		macOS.framework('AVFoundation');
		macOS.framework('CoreMedia'); // we probably do not need this

		this.pool = macOS.NSAutoreleasePool('alloc')('init'); // TODO move to `('autorelease')` ? && process.exit ~> pool('drain')
		this.session = macOS.AVCaptureSession('alloc')('init');
		this.displayId = macOS.CGMainDisplayID(); // TODO change this when we support multiple displays

		this.input = macOS.AVCaptureScreenInput('alloc')('initWithDisplayID', this.displayId)('autorelease');
		if (this.input) {
			if (this.session('canAddInput', this.input)) {
				this.session('addInput', this.input);
			} else {
				throw new Error(`can't add input`); // TODO
			}
		} else {
			throw new Error(`can't create input`); // TODO
		}

		this.output = macOS.AVCaptureMovieFileOutput('alloc')('init');

		if (this.session('canAddOutput', this.output)) {
			this.session('addOutput', this.output);
		} else {
			throw new Error(`can't add output`); // TODO
		}

		const conn = this.output('connectionWithMediaType', macOS.AVMediaTypeVideo);
		try {
			if (conn('isVideoMinFrameDurationSupported')) {
				conn('setVideoMinFrameDuration', macOS.CMTimeMake('1', '30'));
			}
		} catch (err) {
			if (/FFI_BAD_TYPEDEF/.test(err.message)) {
				console.log(`can't set min fps :(`);
			} else {
				throw err;
			}
		}
		try {
			if (conn('isVideoMaxFrameDurationSupported')) {
				conn('setVideoMaxFrameDuration', macOS.CMTimeMake('1', '60'));
			}
		} catch (err) {
			if (/FFI_BAD_TYPEDEF/.test(err.message)) {
				console.log(`can't set max fps :(`);
			} else {
				throw err;
			}
		}
	}

	startRecording() {
		return new Promise((resolve, reject) => {
			if (this.recording) {
				return reject(Error('Already recording'));
			}
			pify(tmp.tmpName)({postfix: '.mov'})
				.then(path => {
					this.path = path;
					this.NSpath = macOS.NSString('stringWithUTF8String', this.path);
					this.NSpathURL = macOS.NSURL('fileURLWithPath', this.NSpath);

					this.session('startRunning');
					this.output('startRecordingToOutputFileURL', this.NSpathURL,
						'recordingDelegate', this.output);
					this.recording = true;
				})
				.then(resolve)
				.catch(reject);
		});
	}

	stopRecording(opts) {
		return new Promise((resolve, reject) => {
			if (!this.recording) {
				return reject(Error('Not recording'));
			}

			opts = Object.assign({
				destinationPath: undefined,
				override: false
			}, opts);

			this.recording = false;
			this.output('stopRecording');
			// this.pool('drain'); // TODO why this throws an exception?

			if (opts.destinationPath === undefined) {
				return resolve(this.path);
			}

			pify(rename)(this.path, opts.destinationPath)
				.then(() => {
					this.path = opts.destinationPath;
					resolve(opts.destinationPath);
				})
				.catch(reject);
		});
	}
}

module.exports = () => {
	return new Aperture();
};
