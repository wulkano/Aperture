import AVFoundation

final class Recorder: NSObject, AVCaptureFileOutputRecordingDelegate {
  private var destination: URL!
  private var session: AVCaptureSession!
  private var input: AVCaptureScreenInput!
  private var audioInput: AVCaptureDeviceInput!
  private var output: AVCaptureMovieFileOutput!

  init(destinationPath: String, fps: String, coordinates: [String], showCursor: Bool, highlightClicks: Bool, displayId: UInt32, audioDeviceId: String) {
    super.init()

    destination = URL(fileURLWithPath: destinationPath)

    session = AVCaptureSession()

    input = AVCaptureScreenInput(displayID: displayId)
    input.minFrameDuration = CMTimeMake(1, Int32(fps)!)
    input.capturesCursor = showCursor
    input.capturesMouseClicks = highlightClicks

    if coordinates.count != 0 {
      let points = coordinates.map { CGFloat((Int($0))!) }
      let rect = CGRect(x: points[0], y: points[1], width: points[2], height: points[3]) // x, y, width, height
      input.cropRect = rect
    }

    output = AVCaptureMovieFileOutput()
    // Needed because otherwise there is no audio on videos longer than 10 seconds
    // http://stackoverflow.com/a/26769529/64949
    output.movieFragmentInterval = kCMTimeInvalid

    if audioDeviceId != "none" {
      let audioDevice: AVCaptureDevice = AVCaptureDevice.init(uniqueID: audioDeviceId)

      do {
        try audioInput = AVCaptureDeviceInput(device: audioDevice)

        if session.canAddInput(audioInput) {
          session.addInput(audioInput)
        } else {
          // TODO(matheuss): When we can't add the input, we should imediately exit
          // With that, the JS part would be able to `reject` the `Promise`.
          // Right now, on Kap for example, the recording will probably continue without
          // letting the user now that no audio is being recorded
          print("Can't add audio input")
        }
      } catch {} // TODO(matheuss): Exit when this happens
    }

    if session.canAddInput(input) {
      session.addInput(input)
    } else {
      print("Can't add input")
      // TODO(matheuss): When we can't add the input, we should imediately exit
      // With that, the JS part would be able to `reject` the `Promise`.
      // Right now, on Kap for example, the recording will probably continue without
      // letting the user now that no video is being recorded
    }

    if session.canAddOutput(output) {
      session.addOutput(output)
    } else {
      print("Can't add output")
      // TODO(matheuss): When we can't add the input, we should imediately exit
      // With that, the JS part would be able to `reject` the `Promise`.
      // Right now, on Kap for example, the recording will probably continue without
      // letting the user now that no the file will not be saved
    }
  }

  func start() {
    session.startRunning()
    output.startRecording(toOutputFileURL: destination, recordingDelegate: self)
  }

  func stop() {
    output.stopRecording()
    session.stopRunning()
  }

  internal func capture(_ captureOutput: AVCaptureFileOutput, didStartRecordingToOutputFileAt fileURL: URL, fromConnections connections: [Any]) {
    print("R") // At this point the recording really started
  }

  internal func capture(_ captureOutput: AVCaptureFileOutput, didFinishRecordingToOutputFileAt outputFileURL: URL, fromConnections connections: [Any], error: Error!) {
    // TODO: Make `stop()` accept a callback that is called when this method is called and do the exiting in `main.swift`
    if error != nil {
      // Don't print useless "Stop Recording" error
      if error._code != -11806 {
        print(error)
        exit(1)
      } else {
        exit(0)
      }
    } else {
      exit(0) // TODO(matheuss): This will probably never happen, check if we can remove the if-else
    }
  }
}
