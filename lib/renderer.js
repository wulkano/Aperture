const {checkProcessType} = require('./util');

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
function startRecording() {
	return new Promise(() => {
		checkProcessType('renderer', 'startRecording'); // TODO reject()
	});
}

function stopRecording() {
	checkProcessType('renderer', 'stopRecording');
}

function debugStream() {
	checkProcessType('renderer', 'stopRecording');
}

exports.init = init;
exports.startRecording = startRecording;
exports.stopRecording = stopRecording;
exports.debugStream = debugStream;
