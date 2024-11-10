import Foundation
import AVFoundation
import Aperture

func delay(seconds: TimeInterval, closure: @escaping () -> Void) {
	DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: closure)
}

let url = URL(fileURLWithPath: "../screen-recording.mp4")
do {
	let recorder = Aperture.Recorder()

	let screens = try await Aperture.Devices.screen()

	guard let screen = screens.first else {
		print("Could not find any iOS devices")
		exit(1)
	}

	print("Available screens:", screens.map(\.name).joined(separator: ", "))

	try await recorder.startRecording(
		target: .screen,
		options: Aperture.RecordingOptions(
			destination: url,
			targetId: screen.id,
			losslessAudio: true,
			recordSystemAudio: true,
			microphoneDeviceId: "BuiltInMicrophoneDevice"
		)
	)
	print("Recording screen for 5 seconds")

	try await Task.sleep(for: .seconds(5))
	print("Stopping recording")

	try await recorder.stopRecording()
	print("Finished recording:", url.path)
	exit(0)
} catch let error as Aperture.ApertureError {
	print("Aperture Error: \(error.localizedDescription)")
} catch {
	print("Unknown Error: \(error.localizedDescription)")
	exit(1)
}

