import Foundation
import AVFoundation
import Aperture

func delay(seconds: TimeInterval, closure: @escaping () -> Void) {
	DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: closure)
}

let url = URL(fileURLWithPath: "../screen-recording.mp4")
let aperture = try! Aperture(destination: url)

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

print("Available screens:", Aperture.Devices.screen().map(\.name).joined(separator: ", "))
print("Recording screen for 5 seconds")

delay(seconds: 5) {
	aperture.stop()
}

setbuf(__stdoutp, nil)
RunLoop.current.run()
