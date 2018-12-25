import AppKit
import AVFoundation
import CoreMediaIO

// Enable access to iOS devices
private func enableDalDevices() {
  var property = CMIOObjectPropertyAddress(
    mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
    mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
    mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
  )
  var allow: UInt32 = 1
  let sizeOfAllow = MemoryLayout<UInt32>.size
  CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &property, 0, nil, UInt32(sizeOfAllow), &allow)
}

struct Devices {
  static func screen() -> [[String: Any]] {
    return NSScreen.screens.map {
      [
        "name": $0.name,
        "id": $0.id
      ]
    }
  }

  static func audio() -> [[String: String]] {
    return AVCaptureDevice.devices(for: .audio).map {
      [
        "name": $0.localizedName,
        "id": $0.uniqueID
      ]
    }
  }

  static func ios() -> [[String: String]] {
    enableDalDevices()
    return AVCaptureDevice.devices(for: .muxed)
      .filter { $0.localizedName == "iPhone" || $0.localizedName == "iPad" }
      .map {
        [
          "name": $0.localizedName,
          "id": $0.uniqueID
        ]
      }
  }
}
