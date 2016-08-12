const {desktopCapturer} = require('electron'); // eslint-disable-line import/no-extraneous-dependencies
const {checkProcessType} = require('./util');

function init() {
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

exports.init = init;
