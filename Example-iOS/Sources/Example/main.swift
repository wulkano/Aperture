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

let url = URL(fileURLWithPath: "../screen-recording-ios.mp4")
let aperture = try! Aperture(destination: url, iosDevice: device)

aperture.onFinish = {
	switch $0 {
	case .success(let warning):
		print("Finished recording:", url.path)

		if let warning = warning {
			print("Warning:", warning.localizedDescription)
		}

		exit(0)
	case .failure(let error):
		print(error)
		exit(1)
	}
}

aperture.start()

print("Recording the screen of “\(deviceInfo.name)” for 5 seconds")

delay(seconds: 5) {
	aperture.stop()
}

setbuf(__stdoutp, nil)
RunLoop.current.run()
