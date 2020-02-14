import Foundation
import AVFoundation
import Aperture

guard
	let deviceInfo = Aperture.Devices.iOS().first,
	let device = AVCaptureDevice(uniqueID: deviceInfo.id)
else {
	print("Could not find any iOS devices")
	exit(1)
}

let url = URL(fileURLWithPath: "../ios-screen-recording.mp4")

guard let aperture = try? Aperture(destination: url, iosDevice: device) else {
	print("Failed to start recording")
	exit(1)
}

print("Recording the screen of “\(deviceInfo.name)” for 5 seconds")

aperture.start()

sleep(5)

aperture.stop()

print("Finished recording:", url.path)
