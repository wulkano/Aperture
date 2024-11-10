import Foundation
import AVFoundation
import Aperture

let url = URL(fileURLWithPath: "../screen-recording-ios.mp4")
do {
	let recorder = Aperture.Recorder()

	let devices = Aperture.Devices.iOS()

	guard let device = devices.first else {
		print("Could not find any iOS devices")
		exit(1)
	}

	print("Available iOS devices:", devices.map(\.name).joined(separator: ", "))

	try await recorder.startRecording(
		target: .externalDevice,
		options: Aperture.RecordingOptions(
			destination: url,
			targetId: device.id,
			losslessAudio: true,
			recordSystemAudio: true,
			microphoneDeviceId: "BuiltInMicrophoneDevice" //"AppleUSBAudioEngine:Kingston:HyperX Quadcast:4110:2"
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

