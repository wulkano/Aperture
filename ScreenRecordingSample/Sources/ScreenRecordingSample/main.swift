import Foundation
import Aperture
import AVFoundation

let url = URL(fileURLWithPath: "./ios_screen.mp4")

let aperture = try! Aperture(destination: url, iosDevice: AVCaptureDevice(uniqueID: Devices.ios()[0]["id"]!)!)

aperture.start()

sleep(5)

aperture.stop()
