import AVFoundation;

class Recorder: NSObject, AVCaptureFileOutputRecordingDelegate {
  var destination: URL?;
  var session: AVCaptureSession?;
  var input: AVCaptureScreenInput?
  var audioInput: AVCaptureDeviceInput?
  var output: AVCaptureMovieFileOutput?;

  init(destinationPath: String, fps: String, coordinates: [String], showCursor: Bool, highlightClicks: Bool, displayId: UInt32, audioDeviceId: String) {
    super.init();
    self.session = AVCaptureSession();

    self.input = AVCaptureScreenInput(displayID: displayId);
    self.input!.minFrameDuration = CMTimeMake(1, Int32(fps)!);

    if (audioDeviceId != "none") {
      let audioDevice: AVCaptureDevice = AVCaptureDevice.init(uniqueID: audioDeviceId);

      do {
        try self.audioInput = AVCaptureDeviceInput(device: audioDevice);

        if ((self.session?.canAddInput(self.audioInput)) != nil) {
          self.session?.addInput(self.audioInput);
        } else {
          print("Can't add audio input");
        }
      } catch {} // TODO
    }

    if ((self.session?.canAddInput(input)) != nil) {
      self.session?.addInput(input);
    } else {
      print("Can't add input"); // TODO
    }

    self.output = AVCaptureMovieFileOutput();

    if ((self.session?.canAddOutput(self.output)) != nil) {
      self.session?.addOutput(self.output);
    } else {
      print("can't add output"); // TODO
    }

    self.destination = URL(fileURLWithPath: destinationPath);

    if (coordinates.count != 0) {
      let points = coordinates.map { CGFloat((Int($0))!) };
      let rect = CGRect(x: points[0], y: points[1], width: points[2], height: points[3]); // x, y, width, height
      self.input?.cropRect = rect;
    }

    self.input?.capturesCursor = showCursor;
    self.input?.capturesMouseClicks = highlightClicks;
  }

  func start() {
      self.session?.startRunning();
      self.output?.startRecording(toOutputFileURL: self.destination, recordingDelegate: self);
    }

  func stop() {
      self.output?.stopRecording();
      self.session?.stopRunning();
  }

  func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
    print("R"); // at this point the recording really started
  }

  func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
    // TODO: Make `stop()` accept a callback that is called when this method is called and do the exiting in `main.swift`
    if error != nil {
      // don't print useless "Stop Recording" error
      if (error._code != -11806) {
        print(error);
        exit(1);
      } else {
        exit(0);
      }
    } else {
      exit(0); // TODO: this will probably never happen, check if we can remove the if-else
    }
  }
}
