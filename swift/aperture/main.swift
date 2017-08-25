import Foundation
import AVFoundation

var recorder: Recorder!

func quit(_: Int32) {
  recorder.stop()
}

func record() throws {
  // TODO: Use JSON and `Codable` here when Swift 4 is out

  let args = CommandLine.arguments
  let destination = args[1]
  let fps = args[2]
  let cropArea = args[3]
  let showCursor = args[4]
  let highlightClicks = args[5]
  let displayId = args[6]
  let audioDeviceId = args[7]

  var cropRect: CGRect?
  if cropArea != "none" {
    let points = cropArea.components(separatedBy: ":").map { Double($0)! }
    cropRect = CGRect(x: points[0], y: points[1], width: points[2], height: points[3])
  }

  recorder = try Recorder(
    destination: URL(fileURLWithPath: destination),
    fps: Int(fps)!,
    cropRect: cropRect,
    showCursor: showCursor == "true",
    highlightClicks: highlightClicks == "true",
    displayId: displayId == "main" ? CGMainDisplayID() : CGDirectDisplayID(displayId)!,
    audioDevice: audioDeviceId == "none" ? nil : .defaultDevice(withMediaType: AVMediaTypeAudio)
  )

  recorder.onStart = {
    print("R")
  }

  recorder.onFinish = {
    exit(0)
  }

  recorder.onError = {
    printErr($0)
    exit(1)
  }

  signal(SIGHUP, quit)
  signal(SIGINT, quit)
  signal(SIGTERM, quit)
  signal(SIGQUIT, quit)

  recorder.start()
  setbuf(__stdoutp, nil)

  RunLoop.main.run()
}

func usage() {
  print("usage: aperture <list-audio-devices | <destinationPath> <fps> <crop-rect-coordinates> <show-cursor> <highlight-clicks> <display-id> <audio-device-id>>")
  print("examples: aperture ./file.mp4 30 0:0:100:100 true false 1846519 'AppleHDAEngineInput:1B,0,1,0:1'")
  print("          aperture ./file.mp4 30 none true false main none")
  print("          aperture list-audio-devices")
}

let numberOfArgs = CommandLine.arguments.count

if numberOfArgs == 8 {
  try record()
  exit(0)
}

if numberOfArgs == 2 && CommandLine.arguments[1] == "list-audio-devices" {
  // Use stderr because of unrelated stuff being outputted on stdout
  // TODO: Use JSON and `Codable` here when Swift 4 is out
  printErr(try toJson(DeviceList.audio()))
  exit(0)
}

usage()
exit(1)
