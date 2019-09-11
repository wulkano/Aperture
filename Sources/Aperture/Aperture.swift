import Foundation
import AVFoundation

public enum ApertureError: Error {
  case invalidScreen
  case invalidAudioDevice
  case couldNotAddScreen
  case couldNotAddMic
  case couldNotAddOutput
}

public final class Aperture: NSObject {
  private let destination: URL
  private let session: AVCaptureSession
  private let output: AVCaptureMovieFileOutput
  private var activity: NSObjectProtocol?

  public var onStart: (() -> Void)?
  public var onFinish: (() -> Void)?
  public var onError: ((Error) -> Void)?
  public var onPause: (() -> Void)?
  public var onResume: (() -> Void)?
  public var isRecording: Bool { output.isRecording }
  public var isPaused: Bool { output.isRecordingPaused }
  public let devices = Devices.self

  // TODO: When targeting macOS 10.13, make the `videoCodec` option the type `AVVideoCodecType`.
  public init(
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

  public func start() {
    session.startRunning()
    output.startRecording(to: destination, recordingDelegate: self)
  }

  public func stop() {
    output.stopRecording()
    session.stopRunning()
  }

  public func pause() {
    output.pauseRecording()
  }

  public func resume() {
    output.resumeRecording()
  }
}

extension Aperture: AVCaptureFileOutputRecordingDelegate {
  private var shouldPreventSleep: Bool {
    get { activity != nil }
    set {
      if newValue {
        activity = ProcessInfo.processInfo.beginActivity(options: .idleSystemSleepDisabled, reason: "Recording screen")
      } else if let activity = activity {
        ProcessInfo.processInfo.endActivity(activity)
        self.activity = nil
      }
    }
  }

  public func fileOutput(_ captureOutput: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
    shouldPreventSleep = true
    onStart?()
  }

  public func fileOutput(_ captureOutput: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    shouldPreventSleep = false

    let FINISHED_RECORDING_ERROR_CODE = -11_806

    if let error = error, error._code != FINISHED_RECORDING_ERROR_CODE {
      onError?(error)
    } else {
      onFinish?()
    }
  }

  public func fileOutput(_ output: AVCaptureFileOutput, didPauseRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
    shouldPreventSleep = false
    onPause?()
  }

  public func fileOutput(_ output: AVCaptureFileOutput, didResumeRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
    shouldPreventSleep = true
    onResume?()
  }

  public func fileOutputShouldProvideSampleAccurateRecordingStart(_ output: AVCaptureFileOutput) -> Bool { true }
}
