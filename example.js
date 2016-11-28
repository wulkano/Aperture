const aperture = require('./index');

const instance = aperture();
instance.getAudioSources()
  .then(sources => {
    console.log('Audio sources:', sources);
    return instance.startRecording();
  })
  .then(tmp => {
    console.log('Recording to', tmp);
    return new Promise((resolve, reject) => {
      setTimeout(() => instance.stopRecording().then(resolve).catch(reject), 3000);
    });
  })
  .then(tmp => console.log('Saved to', tmp))
  .catch(err => console.error(err));
