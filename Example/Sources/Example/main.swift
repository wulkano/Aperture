import Foundation
import AVFoundation
import Aperture

let url = URL(filePath: "../screen-recording.mp4")
do {
	let recorder = Aperture.Recorder()

	let screens = try await Aperture.Devices.screen()

	guard let screen = screens.first else {
		print("Could not find any screens")
		exit(1)
	}

	print("Available screens:", screens.map(\.name).joined(separator: ", "))

	try await recorder.startRecording(
		target: .screen,
		options: Aperture.RecordingOptions(
			destination: url,
			targetID: screen.id,
			losslessAudio: true,
			recordSystemAudio: true,
			microphoneDeviceID: "BuiltInMicrophoneDevice" //Aperture.Devices.audio().first?.id
		)
	)
	print("Recording screen for 5 seconds")

	try await Task.sleep(for: .seconds(5))
	print("Pausing for 5 seconds")
	try recorder.pause()

	try await Task.sleep(for: .seconds(5))
	print("Resuming for 5 seconds")
	try await recorder.resume()

	try await Task.sleep(for: .seconds(5))
	print("Stopping recording")

	try await recorder.stopRecording()
	print("Finished recording:", url.path)
	exit(0)
} catch let error as Aperture.Error {
	print("Aperture Error: \(error.localizedDescription)")
	exit(1)
} catch {
	print("Unknown Error: \(error.localizedDescription)")
	exit(1)
}
