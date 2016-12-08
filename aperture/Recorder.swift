import AVFoundation;

public class Recorder: NSObject, AVCaptureFileOutputRecordingDelegate {
  var destination: NSURL?;
  var session: AVCaptureSession?;
  var input: AVCaptureScreenInput?
  var output: AVCaptureMovieFileOutput?;

  public init(destinationPath: String, fps: String, coordinates: [String], showCursor: Bool, highlightClicks: Bool, displayId: UInt32) {
    super.init();
    self.session = AVCaptureSession();

    self.input = AVCaptureScreenInput(displayID: displayId);
    self.input!.minFrameDuration = CMTimeMake(1, Int32(fps)!);

    if ((self.session?.canAddInput(input)) != nil) {
      self.session?.addInput(input);
    } else {
      print("can't add input"); // TODO
    }

    self.output = AVCaptureMovieFileOutput();

    if ((self.session?.canAddOutput(self.output)) != nil) {
      self.session?.addOutput(self.output);
    } else {
      print("can't add output"); // TODO
    }

    self.destination = NSURL.fileURLWithPath(destinationPath);

    if (coordinates.count != 0) {
      let points = coordinates.map { CGFloat((Int($0))!) };
      let rect = CGRectMake(points[0], points[1], points[2], points[3]); // x, y, width, height
      self.input?.cropRect = rect;
    }

    self.input?.capturesCursor = showCursor;
    self.input?.capturesMouseClicks = highlightClicks;
  }

  public func start() {
      self.session?.startRunning();
      self.output?.startRecordingToOutputFileURL(self.destination, recordingDelegate: self);
    }

  public func stop() {
      self.output?.stopRecording();
      self.session?.stopRunning();
  }

  public func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
    print("R"); // at this point the recording really started
  }

  public func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
    if error != nil {
      // don't print useless "Stop Recording" error
      if (error.code != -11806) {
        print(error);
      }

      // TODO: Make `stop()` accept a callback that is called when this method is called and do the exiting in `main.swift`
      exit(1);
    } else {
      exit(0);
    }
  }
}
