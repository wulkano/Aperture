import AVFoundation
import CoreMediaIO
import ScreenCaptureKit

// Enable access to iOS devices.
internal func enableDalDevices() {
	var property = CMIOObjectPropertyAddress(
		mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
		mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
		mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
	)
	var allow: UInt32 = 1
	let sizeOfAllow = MemoryLayout<UInt32>.size
	CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &property, 0, nil, UInt32(sizeOfAllow), &allow)
}

extension NSScreen {
	var displayID: CGDirectDisplayID? {
		deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID
	}
}

extension SCDisplay {
	var nsScreen: NSScreen? {
		NSScreen.screens.first { $0.displayID == self.displayID }
	}

	var scaleFactor: Int {
		if let mode = CGDisplayCopyDisplayMode(self.displayID) {
			return mode.pixelWidth / mode.width
		}
		return 1
	}
}

extension Aperture {
	public struct Devices {
		public struct Screen: Hashable, Codable, Identifiable {
			public let id: String
			public let name: String

			public let width: Int
			public let height: Int
			public let frame: CGRect
		}

		public struct Window: Hashable, Codable, Identifiable {
			public let id: String
			public let title: String?
			public let applicationName: String?
			public let applicationBundleIdentifier: String?

			public let isActive: Bool
			public let isOnScreen: Bool
			public let layer: Int

			public let frame: CGRect
		}

		public struct Audio: Hashable, Codable, Identifiable {
			public let id: String
			public let name: String
		}

		public struct IOS: Hashable, Codable, Identifiable {
			public let id: String
			public let name: String
		}

		public static func screen() async throws -> [Screen] {
			let content = try await SCShareableContent.current
			return content.displays.map { device in
				Screen(
					id: String(device.displayID),
					name: device.nsScreen?.localizedName ?? "Unknown Display",
					width: device.width,
					height: device.height,
					frame: device.frame
				)
			}
		}

		public static func window(excludeDesktopWindows: Bool = true, onScreenWindowsOnly: Bool = true) async throws -> [Window] {
			let content = try await SCShareableContent.excludingDesktopWindows(excludeDesktopWindows, onScreenWindowsOnly: onScreenWindowsOnly)
			return content.windows.map { device in
				let isActive: Bool

				if #available(macOS 13.1, *) {
					isActive = device.isActive
				} else {
					isActive = false
				}

				return Window(
					id: String(device.windowID),
					title: device.title,
					applicationName: device.owningApplication?.applicationName,
					applicationBundleIdentifier: device.owningApplication?.bundleIdentifier,
					isActive: isActive,
					isOnScreen: device.isOnScreen,
					layer: device.windowLayer,
					frame: device.frame
				)
			}
		}

		public static func audio() -> [Audio] {
			let deviceTypes: [AVCaptureDevice.DeviceType]

			if #available(macOS 14, *) {
				deviceTypes = [.microphone, .external]
			} else {
				deviceTypes = [.builtInMicrophone, .externalUnknown]
			}

			let devices = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .audio, position: .unspecified).devices

			return devices.map { device in
				Audio(id: device.uniqueID, name: device.localizedName)
			}
		}

		public static func iOS() -> [IOS] {
			enableDalDevices()

			let deviceTypes: [AVCaptureDevice.DeviceType]

			if #available(macOS 14, *) {
				deviceTypes = [.external]
			} else {
				deviceTypes = [.externalUnknown]
			}

			let devices = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: nil, position: .unspecified).devices

			return devices.map { device in
				IOS(id: device.uniqueID, name: device.localizedName)
			}
		}
	}
}
