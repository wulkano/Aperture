import AppKit
import AVFoundation

private final class StandardErrorOutputStream: TextOutputStream {
  func write(_ string: String) {
    FileHandle.standardError.write(string.data(using: .utf8)!)
  }
}

private var stderr = StandardErrorOutputStream()

func printErr(_ item: Any) {
  print(item, to: &stderr)
}

func toJson<T>(_ data: T) throws -> String {
  let json = try JSONSerialization.data(withJSONObject: data)
  return String(data: json, encoding: .utf8)!
}

extension CMTime {
  static var zero: CMTime = kCMTimeZero
  static var invalid: CMTime = kCMTimeInvalid
}

extension CGDirectDisplayID {
  static let main = CGMainDisplayID()
}

extension NSScreen {
  private func infoForCGDisplay(_ displayID: CGDirectDisplayID, options: Int) -> [AnyHashable: Any]? {
    var iterator: io_iterator_t = 0

    let result = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"), &iterator)
    guard result == kIOReturnSuccess else {
      print("Could not find services for IODisplayConnect: \(result)")
      return nil
    }

    var service = IOIteratorNext(iterator)
    while service != 0 {
      let info = IODisplayCreateInfoDictionary(service, IOOptionBits(options)).takeRetainedValue() as! [AnyHashable: Any]

      guard
        let vendorID = info[kDisplayVendorID] as! UInt32?,
        let productID = info[kDisplayProductID] as! UInt32?
      else {
          continue
      }

      if vendorID == CGDisplayVendorNumber(displayID) && productID == CGDisplayModelNumber(displayID) {
        return info
      }

      service = IOIteratorNext(iterator)
    }

    return nil
  }

  var id: CGDirectDisplayID {
    return deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
  }

  var name: String {
    guard let info = infoForCGDisplay(id, options: kIODisplayOnlyPreferredName) else {
      return "Unknown screen"
    }

    guard
      let localizedNames = info[kDisplayProductName] as? [String: Any],
      let name = localizedNames.values.first as? String
      else {
        return "Unnamed screen"
    }

    return name
  }
}
