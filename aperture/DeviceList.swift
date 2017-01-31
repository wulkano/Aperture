import Cocoa
import CoreAudio
import CoreMediaIO
import Foundation
import AVFoundation
import AudioToolbox

// Enable access to iOS devices
func enableDalDevices() {
  var property = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices), mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal), mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster))
  var allow: UInt32 = 1
  let sizeOfAllow = MemoryLayout<UInt32>.size
  CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &property, 0, nil, UInt32(sizeOfAllow), &allow)
}

class DeviceList {
  func audio() -> NSString? {
    let captureDevices = AVCaptureDevice.devices(withMediaType: AVMediaTypeAudio) as! [AVCaptureDevice]

    let ret = captureDevices
      .map {[
        "name": $0.localizedName,
        "id": $0.uniqueID
      ]}

    do {
      let parsedData = try JSONSerialization.data(withJSONObject: ret, options: [])
      return NSString(data: parsedData, encoding: String.Encoding.utf8.rawValue)
    } catch _ as NSError {
      return nil
    }
  }

  func ios() -> NSString? {
    enableDalDevices()
    let captureDevices = AVCaptureDevice.devices(withMediaType: AVMediaTypeMuxed) as! [AVCaptureDevice]
    let ret = captureDevices
      .filter {$0.localizedName == "iPhone" || $0.localizedName == "iPad"}
      .map {[
        "name": $0.localizedName,
        "id": $0.uniqueID
      ]}

    do {
      let parsedData = try JSONSerialization.data(withJSONObject: ret, options: [])
      return NSString(data: parsedData, encoding: String.Encoding.utf8.rawValue)
    } catch _ as NSError {
      return nil
    }
  }
}
