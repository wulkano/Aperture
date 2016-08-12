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

exports.checkProcessType = checkProcessType;
