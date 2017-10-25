import AVFoundation

enum ApertureError: Error {
  case couldNotAddScreen
  case couldNotAddMic
  case couldNotAddOutput
}

final class Recorder: NSObject, AVCaptureFileOutputRecordingDelegate {
  private let destination: URL
  private let session: AVCaptureSession
  private let input: AVCaptureScreenInput
  private var audioInput: AVCaptureDeviceInput!
  private let output: AVCaptureMovieFileOutput
  var onStart: (() -> Void)?
  var onFinish: (() -> Void)?
  var onError: ((Any) -> Void)?

  init(destinationPath: String, fps: Int32, coordinates: [String], showCursor: Bool, highlightClicks: Bool, displayId: UInt32, audioDeviceId: String) throws {
    destination = URL(fileURLWithPath: destinationPath)

    session = AVCaptureSession()

    input = AVCaptureScreenInput(displayID: displayId)
    input.minFrameDuration = CMTimeMake(1, fps)
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

      audioInput = try AVCaptureDeviceInput(device: audioDevice)

      if session.canAddInput(audioInput) {
        session.addInput(audioInput)
      } else {
        throw ApertureError.couldNotAddMic
      }
    }

    if session.canAddInput(input) {
      session.addInput(input)
    } else {
      throw ApertureError.couldNotAddScreen
    }

    if session.canAddOutput(output) {
      session.addOutput(output)
    } else {
      throw ApertureError.couldNotAddOutput
    }

    super.init()
  }

  func start() {
    session.startRunning()
    output.startRecording(toOutputFileURL: destination, recordingDelegate: self)
  }

  func stop() {
    output.stopRecording()
    session.stopRunning()
  }

  func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
    onStart?()
  }

  func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
    let FINISHED_RECORDING_ERROR_CODE = -11806

    if let err = error, err._code != FINISHED_RECORDING_ERROR_CODE {
      onError?(error)
    } else {
      onFinish?()
    }
  }
}
