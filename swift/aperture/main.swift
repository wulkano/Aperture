// Exit codes:
// 1: some argument is missing ¯\_(ツ)_/¯
// 2: bad crop rect coordinates
// ?: ¯\_(ツ)_/¯
//
// Note: `highlight-clicks` will only work if `show-cursor` is true
// TODO: document this ^

import Foundation
import AVFoundation

func quit(_: Int32) {
	recorder.stop();
}

func record(){
  let destinationPath = Process.arguments[1];
  let fps = Process.arguments[2];
  let cropArea = Process.arguments[3];
  let showCursor = Process.arguments[4] == "true" ? true : false;
  let highlightClicks = Process.arguments[5] == "true" ? true : false;

  var coordinates = [];
  if (cropArea != "none") {
    coordinates = Process.arguments[3].componentsSeparatedByString(":");
    if (coordinates.count - 1 != 3) { // number of ':' in the string
      print("The coordinates for the crop rect must be in the format 'originX:originY:width:height'");
      exit(2);
    }
  }

  let recorder = Recorder(destinationPath: destinationPath, fps: fps, coordinates: coordinates as! [String], showCursor: showCursor, highlightClicks: highlightClicks);

  signal(SIGHUP, quit);
  signal(SIGINT, quit);
  signal(SIGTERM, quit);
  signal(SIGQUIT, quit);

  recorder.start();

  NSRunLoop.mainRunLoop().run();
}

func listAudioDevices() {
  print(AudioDeviceList().getInputDevices() as! String);
}

func usage() {
  print("usage: main <list-audio-devices | <destinationPath> <fps> <crop-rect-coordinates> <show-cursor> <highlight-clicks> >");
  print("examples: main ./file.mp4 30 0:0:100:100 true false");
  print("          main ./file.mp4 30 none true false");
  print("          main list-audio-devices");
}

let numberOfArgs = Process.arguments.count

if (numberOfArgs == 6) {
  record();
  exit(0);
}

if (numberOfArgs == 2 && Process.arguments[1] == "list-audio-devices"){
  listAudioDevices();
  exit(0);
}

usage();
exit(1);
