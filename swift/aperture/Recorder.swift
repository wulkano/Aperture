import AVFoundation

enum ApertureError: Error {
  case invalidScreen
  case invalidAudioDevice
  case couldNotAddScreen
  case couldNotAddMic
  case couldNotAddOutput
}

final class Recorder: NSObject {
  private let destination: URL
  private let session: AVCaptureSession
  private let output: AVCaptureMovieFileOutput

  var onStart: (() -> Void)?
  var onFinish: (() -> Void)?
  var onError: ((Error) -> Void)?
  var onPause: (() -> Void)?
  var onResume: (() -> Void)?

  var isRecording: Bool {
    return output.isRecording
  }

  var isPaused: Bool {
    return output.isRecordingPaused
  }

  /// TODO: When targeting macOS 10.13, make the `videoCodec` option the type `AVVideoCodecType`
  init(
    destination: URL,
    framesPerSecond: Int,
    cropRect: CGRect?,
    showCursor: Bool,
    highlightClicks: Bool,
    screenId: CGDirectDisplayID = .main,
    audioDevice: AVCaptureDevice? = .default(for: .audio),
    videoCodec: String? = nil
  ) throws {
    self.destination = destination
    session = AVCaptureSession()

    let input = try AVCaptureScreenInput(displayID: screenId).unwrapOrThrow(ApertureError.invalidScreen)

    input.minFrameDuration = CMTime(videoFramesPerSecond: framesPerSecond)

    if let cropRect = cropRect {
      input.cropRect = cropRect
    }

    input.capturesCursor = showCursor
    input.capturesMouseClicks = highlightClicks

    output = AVCaptureMovieFileOutput()

    // Needed because otherwise there is no audio on videos longer than 10 seconds
    // http://stackoverflow.com/a/26769529/64949
    output.movieFragmentInterval = .invalid

    if let audioDevice = audioDevice {
      if !audioDevice.hasMediaType(.audio) {
        throw ApertureError.invalidAudioDevice
      }

      let audioInput = try AVCaptureDeviceInput(device: audioDevice)

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

    /// TODO: Default to HEVC when on 10.13 or newer and encoding is hardware supported.
    /// Without hardware encoding I got 3 FPS full screen recording.
    /// TODO: Find a way to detect hardware encoding support.
    /// Hardware encoding is supported on 6th gen Intel processor or newer.
    if let videoCodec = videoCodec {
      output.setOutputSettings([AVVideoCodecKey: videoCodec], for: output.connection(with: .video)!)
    }

    super.init()
  }

  func start() {
    session.startRunning()
    output.startRecording(to: destination, recordingDelegate: self)
  }

  func stop() {
    output.stopRecording()
    session.stopRunning()
  }

  func pause() {
    output.pauseRecording()
  }

  func resume() {
    output.resumeRecording()
  }
}

extension Recorder: AVCaptureFileOutputRecordingDelegate {
  func fileOutput(_ captureOutput: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
    onStart?()
  }

  func fileOutput(_ captureOutput: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    let FINISHED_RECORDING_ERROR_CODE = -11806

    if let error = error, error._code != FINISHED_RECORDING_ERROR_CODE {
      onError?(error)
    } else {
      onFinish?()
    }
  }

  func fileOutput(_ output: AVCaptureFileOutput, didPauseRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
    onPause?()
  }

  func fileOutput(_ output: AVCaptureFileOutput, didResumeRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
    onResume?()
  }

  func fileOutputShouldProvideSampleAccurateRecordingStart(_ output: AVCaptureFileOutput) -> Bool {
    return true
  }
}
