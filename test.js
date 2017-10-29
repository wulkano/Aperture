import fs from 'fs';
import test from 'ava';
import delay from 'delay';
import readChunk from 'read-chunk';
import fileType from 'file-type';
import aperture from '.';

test('returns audio devices', async t => {
  const devices = await aperture.audioDevices();
  console.log('Audio devices:', devices);

  t.true(Array.isArray(devices));

  if (devices.length > 0) {
    t.true(devices[0].id.length > 0);
    t.true(devices[0].name.length > 0);
  }
});

test('returns available video codecs', t => {
  const codecs = aperture.videoCodecs;
  console.log('Video codecs:', codecs);
  t.true(codecs.has('h264'));
});

test('records screen', async t => {
  const recorder = aperture();
  t.true(fs.existsSync(await recorder.startRecording()));
  await delay(1000);
  const videoPath = await recorder.stopRecording();
  t.true(fs.existsSync(videoPath));
  t.is(fileType(readChunk.sync(videoPath, 0, 4100)).ext, 'mov');
  fs.unlinkSync(videoPath);
});
