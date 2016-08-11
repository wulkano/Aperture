const {desktopCapturer} = require('electron');

function checkProcessType(expected, msgPrefix) {
	if (expected === 'main' && process.type !== 'browser') {
		throw new Error(`${msgPrefix} should be runned in Electron's main process`);
	}
	if (expected === 'renderer' && process.type !== expected) {
		throw new Error(`${msgPrefix} should be runned in Electron's renderer process`);
	}

	if (['main', 'renderer'].indexOf(expected) === -1) {
		throw new Error(`${expected} is not a known Electron process type`);
	}
}

function initMain() {
	checkProcessType('main', 'aperture.main');
	// TODO
}

function initRenderer() {
	checkProcessType('renderer', 'aperture.renderer');

	desktopCapturer.getSources({types: ['screen']}, (err, sources) => {
		if (err) {
			throw err;
		}

		console.log(navigator.webkitGetUserMedia({
			audio: false,
			video: {
				mandatory: {
					chromeMediaSource: 'desktop',
					chromeMediaSourceId: sources[0].id,
					minWidth: 1280,
					maxWidth: 1280,
					minHeight: 720,
					maxHeight: 720
				}
			}
		}, handleStream, handleError));
	});

	function handleStream(stream) {
		window.stream = stream; // so we can test thing without restarting the app
		document.querySelector('video').src = URL.createObjectURL(stream);
	}

	function handleError(e) {
		console.log(e);
	}
}

const main = {init: initMain};
const renderer = {init: initRenderer};

exports.main = main;
exports.renderer = renderer;
