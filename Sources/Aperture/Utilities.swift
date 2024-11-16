import AVFoundation
import ScreenCaptureKit

internal func initializeCGS() {
	CGMainDisplayID()
}

extension Aperture {
	public static var hasPermissions: Bool {
		get async {
			do {
				_ = try await SCShareableContent.current
				return true
			} catch {
				return false
			}
		}
	}
}

extension CMSampleBuffer {
	public func adjustTime(by offset: CMTime) -> CMSampleBuffer? {
		guard self.formatDescription != nil, offset.value > 0 else {
			return nil
		}

		do {
			var timingInfo = try self.sampleTimingInfos()

			for index in 0..<timingInfo.count {
				// swiftlint:disable:next shorthand_operator
				timingInfo[index].decodeTimeStamp = timingInfo[index].decodeTimeStamp - offset
				// swiftlint:disable:next shorthand_operator
				timingInfo[index].presentationTimeStamp = timingInfo[index].presentationTimeStamp - offset
			}

			return try .init(copying: self, withNewTiming: timingInfo)
		} catch {
			return nil
		}
	}
}

extension Aperture.Error {
	public var localizedDescription: String {
		switch self {
		case .couldNotStartStream(let error):
			let errorReason: String

			if let error = error as? Aperture.Error {
				errorReason = ": \(error.localizedDescription)"
			} else if let error {
				errorReason = ": \(error.localizedDescription)"
			} else {
				errorReason = "."
			}

			return "Could not start recording\(errorReason)"
		case .unsupportedFileExtension(let fileExtension, let isAudioOnly):
			if isAudioOnly {
				return "Invalid file extension. Only .m4a is supported for audio recordings. Got \(fileExtension)."
			}

			return "Invalid file extension. Only .mp4, .mov and .m4v are supported for video recordings. Got \(fileExtension)."
		case .invalidFileExtension(let fileExtension, let videoCodec):
			return "Invalid file extension. .\(fileExtension) does not support \(videoCodec)."
		case .microphoneNotFound(let microphoneId):
			return "Microphone with id \(microphoneId) not found"
		case .noDisplaysConnected:
			return "At least one display must be connected."
		case .noTargetProvided:
			return "No target provider."
		case .recorderAlreadyStarted:
			return "Recorder has already started. Each recorder instance can only be started once."
		case .recorderNotStarted:
			return "Recorder needs to be started first."
		case .targetNotFound(let targetId):
			return "Target with id \(targetId) not found."
		case .noPermissions:
			return "Missing screen capture permissions."
		case .unsupportedVideoCodec:
			return "VideoCodec not supported."
		case .couldNotAddInput(let inputType):
			return "Could not add \(inputType) input."
		case .unknown(let error):
			return "An unknown error has occurred: \(error.localizedDescription)"
		}
	}
}

extension Aperture.VideoCodec {
	public static func fromRawValue(_ rawValue: String) throws -> Aperture.VideoCodec {
		switch rawValue {
		case "h264":
			return .h264
		case "hevc":
			return .hevc
		case "proRes422":
			return .proRes422
		case "proRes4444":
			return .proRes4444
		default:
			throw Aperture.Error.unsupportedVideoCodec
		}
	}

	var asString: String {
		switch self {
		case .h264:
			return "h264"
		case .hevc:
			return "hevc"
		case .proRes422:
			return "proRes422"
		case .proRes4444:
			return "proRes4444"
		}
	}

	var asAVVideoCodec: AVVideoCodecType {
		switch self {
		case .h264:
			return .h264
		case .hevc:
			return .hevc
		case .proRes422:
			return .proRes422
		case .proRes4444:
			return .proRes4444
		}
	}
}
