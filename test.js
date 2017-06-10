import fs from 'fs';
import test from 'ava';
import delay from 'delay';
import readChunk from 'read-chunk';
import fileType from 'file-type';
import aperture from '.';

test('returns audio sources', async t => {
  const sources = await aperture.getAudioSources();
  console.log('Audio sources:', sources);

  t.true(Array.isArray(sources));

  if (sources.length > 0) {
    t.true(sources[0].id.length > 0);
    t.true(sources[0].name.length > 0);
  }
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
