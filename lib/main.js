const {checkProcessType} = require('./util');

function init() {
	checkProcessType('main', 'aperture.main');
}

exports.init = init;
