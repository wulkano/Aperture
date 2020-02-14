import Foundation
import AVFoundation
import Aperture

func delay(seconds: TimeInterval, closure: @escaping () -> Void) {
	DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: closure)
}

guard
	let deviceInfo = Aperture.Devices.iOS().first,
	let device = AVCaptureDevice(uniqueID: deviceInfo.id)
else {
	print("Could not find any iOS devices")
	exit(1)
}

let url = URL(fileURLWithPath: "../ios-screen-recording.mp4")

guard let aperture = try? Aperture(destination: url, iosDevice: device) else {
	print("Failed to initialize")
	exit(1)
}

aperture.onFinish = {
	if let error = $0 {
		print(error)
		exit(1)
	}

	print("Finished recording:", url.path)
	exit(0)
}

aperture.start()

print("Recording the screen of “\(deviceInfo.name)” for 5 seconds")

delay(seconds: 5) {
	aperture.stop()
}

setbuf(__stdoutp, nil)
RunLoop.current.run()
