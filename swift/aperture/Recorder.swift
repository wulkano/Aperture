import AVFoundation

enum ApertureError: Error {
  case couldNotAddScreen
  case couldNotAddMic
  case couldNotAddOutput
}

final class Recorder: NSObject, AVCaptureFileOutputRecordingDelegate {
  private var destination: URL!
  private var session: AVCaptureSession!
  private var input: AVCaptureScreenInput!
  private var audioInput: AVCaptureDeviceInput!
  private var output: AVCaptureMovieFileOutput!
  var onStart: (() -> Void)?
  var onFinish: (() -> Void)?
  var onError: ((Any) -> Void)?

  init(destinationPath: String, fps: String, coordinates: [String], showCursor: Bool, highlightClicks: Bool, displayId: UInt32, audioDeviceId: String) throws {
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
        audioInput = try AVCaptureDeviceInput(device: audioDevice)

        if session.canAddInput(audioInput) {
          session.addInput(audioInput)
        } else {
          throw ApertureError.couldNotAddMic
        }
      } catch {
        // TODO(sindresorhus): Why do I have to catch this just to throw it again? Must be a better way...
        throw error
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
  }

  func start() {
    session.startRunning()
    output.startRecording(toOutputFileURL: destination, recordingDelegate: self)
  }

  func stop() {
    output.stopRecording()
    session.stopRunning()
  }

  func capture(_ captureOutput: AVCaptureFileOutput, didStartRecordingToOutputFileAt fileURL: URL, fromConnections connections: [Any]) {
    onStart?()
  }

  func capture(_ captureOutput: AVCaptureFileOutput, didFinishRecordingToOutputFileAt outputFileURL: URL, fromConnections connections: [Any], error: Error) {
    // Don't print useless "Stop Recording" error
    if error._code != -11806 {
      onError?(error)
    } else {
      onFinish?()
    }
  }
}
