const {desktopCapturer} = require('electron');

function initMain() {
	console.log('init main');
}

function initRenderer() {
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
