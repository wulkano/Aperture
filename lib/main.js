const {app} = require('electron'); // eslint-disable-line import/no-extraneous-dependencies
const {checkProcessType} = require('./util');

function init() {
	checkProcessType('main', 'aperture.main');
	app.commandLine.appendSwitch('enable-blink-features', 'GetUserMedia');
	app.commandLine.appendSwitch('enable-usermedia-screen-capturing');
	app.commandLine.appendSwitch('max-gum-fps', '60'); // TODO support higher fps
}

exports.init = init;
