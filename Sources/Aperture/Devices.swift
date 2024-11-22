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
		NSScreen.screens.first { $0.displayID == displayID }
	}

	var scaleFactor: Int {
		if let mode = CGDisplayCopyDisplayMode(displayID) {
			return mode.pixelWidth / mode.width
		}

		return 1
	}
}

extension Aperture {
	/**
	Discover devices that can be used with Aperture.
	*/
	public struct Devices {
		/**
		Represents a screen that can be recorded.
		*/
		public struct Screen: Hashable, Codable, Identifiable, Sendable {
			/**
			The screen identifier.
			*/
			public let id: String
			/**
			The screen name.
			*/
			public let name: String

			/**
			The width of the screen in points.
			*/
			public let width: Int
			/**
			The height of the screen in points.
			*/
			public let height: Int
			/**
			The frame of the screen.
			*/
			public let frame: CGRect
		}

		/**
		Represents a window that can be recorded.
		*/
		public struct Window: Hashable, Codable, Identifiable, Sendable {
			/**
			The window identifier. 
			*/
			public let id: String
			/**
			The string that displays in a window’s title bar.
			*/
			public let title: String?
			/**
			The display name of the app that owns the window.
			*/
			public let appName: String?
			/**
			The unique bundle identifier of the app that owns the window.
			*/
			public let appBundleIdentifier: String?

			/**
			A Boolean value that indicates if the window is currently streaming.
			*/
			public let isActive: Bool
			/**
			A Boolean value that indicates whether the window is on screen.
			*/
			public let isOnScreen: Bool
			/**
			The layer of the window relative to other windows.
			*/
			public let layer: Int

			/**
			A rectangle the represents the frame of the window within a display.
			*/
			public let frame: CGRect
		}

		/**
		Represents devices that can be used to record audio.
		*/
		public struct Audio: Hashable, Codable, Identifiable, Sendable {
			/**
			The audio device identifier.
			*/
			public let id: String
			/**
			The audio device name. 
			*/
			public let name: String
		}

		/**
		Represents iOS devices that can be used to record. 
		*/
		public struct IOS: Hashable, Codable, Identifiable, Sendable {
			/**
			The iOS device identifier. 
			*/
			public let id: String
			/**
			The iOS device name. 
			*/
			public let name: String
		}

		/**
		Get a list of availble screens.
		*/
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

		/**
		Get a list of available windows.
		 
		- Parameter excludeDesktopWindows: A Boolean value that indicates whether to exclude desktop windows like Finder, Dock, and Desktop from the set of shareable content.
		- Parameter onScreenWindowsOnly: A Boolean value that indicates whether to include only onscreen windows in the set of shareable content.
		*/
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
					appName: device.owningApplication?.applicationName,
					appBundleIdentifier: device.owningApplication?.bundleIdentifier,
					isActive: isActive,
					isOnScreen: device.isOnScreen,
					layer: device.windowLayer,
					frame: device.frame
				)
			}
		}

		/**
		Get a list of available audio devices.
		*/
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

		/**
		Get a list of available iOS devices.
		*/
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
