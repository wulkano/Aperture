import AppKit
import AVFoundation
import CoreMediaIO

// Enable access to iOS devices.
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

extension Aperture {
	public struct Devices {
		public struct Screen: Hashable, Codable {
			public let id: CGDirectDisplayID
			public let name: String
		}

		public struct Audio: Hashable, Codable {
			public let id: String
			public let name: String
		}

		public struct IOS: Hashable, Codable {
			public let id: String
			public let name: String
		}

		public static func screen() -> [Screen] {
			NSScreen.screens.map { Screen(id: $0.id, name: $0.name) }
		}

		public static func audio() -> [Audio] {
			AVCaptureDevice.devices(for: .audio).map {
				Audio(id: $0.uniqueID, name: $0.localizedName)
			}
		}

		public static func iOS() -> [IOS] {
			enableDalDevices()

			return AVCaptureDevice
				.devices(for: .muxed)
				.filter {
					$0.localizedName.contains("iPhone") || $0.localizedName.contains("iPad")
				}
				.map {
					IOS(id: $0.uniqueID, name: $0.localizedName)
				}
		}
	}
}

@available(macOS 10.15, *)
extension Aperture.Devices.Screen: Identifiable {}

@available(macOS 10.15, *)
extension Aperture.Devices.Audio: Identifiable {}

@available(macOS 10.15, *)
extension Aperture.Devices.IOS: Identifiable {}
