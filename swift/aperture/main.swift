import Foundation
import AVFoundation

var recorder: Recorder!

func quit(_: Int32) {
  recorder.stop()
}

func record() {
  let destinationPath = CommandLine.arguments[1]
  let fps = CommandLine.arguments[2]
  let cropArea = CommandLine.arguments[3]
  let showCursor = CommandLine.arguments[4] == "true"
  let highlightClicks = CommandLine.arguments[5] == "true"
  let displayId = CommandLine.arguments[6] == "main" ? CGMainDisplayID() : UInt32(CommandLine.arguments[6])
  let audioDeviceId = CommandLine.arguments[7]

  var coordinates = [String]()
  if cropArea != "none" {
    coordinates = CommandLine.arguments[3].components(separatedBy: ":")
  }

  do {
    recorder = try Recorder(
      destinationPath: destinationPath,
      fps: fps,
      coordinates: coordinates,
      showCursor: showCursor,
      highlightClicks: highlightClicks,
      displayId: displayId!,
      audioDeviceId: audioDeviceId
    )
  } catch {
    printErr(error)
    exit(1)
  }

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
  print("usage: main <list-audio-devices | <destinationPath> <fps> <crop-rect-coordinates> <show-cursor> <highlight-clicks> <display-id> <audio-device-id>>")
  print("examples: main ./file.mp4 30 0:0:100:100 true false 1846519 'AppleHDAEngineInput:1B,0,1,0:1'")
  print("          main ./file.mp4 30 none true false main none")
  print("          main list-audio-devices")
}

let numberOfArgs = CommandLine.arguments.count

if numberOfArgs == 8 {
  record()
  exit(0)
}

if numberOfArgs == 2 && CommandLine.arguments[1] == "list-audio-devices" {
  print(try! toJson(DeviceList.audio()))
  exit(0)
}

usage()
exit(1)
