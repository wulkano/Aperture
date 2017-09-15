import Foundation
import AVFoundation

var recorder: Recorder!
let arguments = CommandLine.arguments.dropFirst()

func quit(_: Int32) {
  recorder.stop()
}

struct CropArea: Decodable {
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat
}

struct Options: Decodable {
  let destination: String // TODO: Figure out a way to make this decodable into an `URL`
  let fps: Int
  let cropArea: CropArea? // TODO: Figure out a way to make this decodable into a `CGRect`
  let showCursor: Bool
  let highlightClicks: Bool
  let displayId: String
  let audioDeviceId: String?
}

func record() throws {
  let json = arguments.first!.data(using: .utf8)!
  let options = try JSONDecoder().decode(Options.self, from: json)

  var cropRect: CGRect?
  if let cropArea = options.cropArea {
    cropRect = CGRect(
      x: cropArea.x,
      y: cropArea.y,
      width: cropArea.width,
      height: cropArea.height
    )
  }

  recorder = try Recorder(
    destination: URL(fileURLWithPath: options.destination),
    fps: options.fps,
    cropRect: cropRect,
    showCursor: options.showCursor,
    highlightClicks: options.highlightClicks,
    displayId: options.displayId == "main" ? CGMainDisplayID() : CGDirectDisplayID(options.displayId)!,
    audioDevice: options.audioDeviceId != nil ? AVCaptureDevice(uniqueID: options.audioDeviceId!) : .default(for: .audio)
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
  print(
    """
    usage: aperture <list-audio-devices | <destinationPath> <fps> <crop-rect-coordinates> <show-cursor> <highlight-clicks> <display-id> <audio-device-id>>
    examples: aperture ./file.mp4 30 0:0:100:100 true false 1846519 'AppleHDAEngineInput:1B,0,1,0:1'
              aperture ./file.mp4 30 none true false main none
              aperture list-audio-devices
    """
  )
}

if arguments.first == "list-audio-devices" {
  // Use stderr because of unrelated stuff being outputted on stdout
  printErr(try toJson(DeviceList.audio()))
  exit(0)
}

if arguments.first != nil {
  try record()
  exit(0)
}

usage()
exit(1)
