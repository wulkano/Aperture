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
		guard self.formatDescription != nil else {
			return nil
		}

		var timingInfo = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: Int(self.numSamples))
		CMSampleBufferGetSampleTimingInfoArray(self, entryCount: timingInfo.count, arrayToFill: &timingInfo, entriesNeededOut: nil)

		for index in 0..<timingInfo.count {
			timingInfo[index].decodeTimeStamp = CMTimeSubtract(timingInfo[index].decodeTimeStamp, offset)
			timingInfo[index].presentationTimeStamp = CMTimeSubtract(timingInfo[index].presentationTimeStamp, offset)
		}

		var outSampleBuffer: CMSampleBuffer?
		CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: self, sampleTimingEntryCount: timingInfo.count, sampleTimingArray: &timingInfo, sampleBufferOut: &outSampleBuffer)

		return outSampleBuffer
	}
}

extension Aperture.Error {
	public var localizedDescription: String {
		switch self {
		case .couldNotStartStream:
			return "Could not start recording"
		case .invalidFileExtension(let fileExtension, let isAudioOnly):
			if isAudioOnly {
				return "Invalid file extension. Only .m4a is supported for audio recordings. Got \(fileExtension)."
			}

			return "Invalid file extension. Only .mp4, .mov and .m4v are supported for video recordings. Got \(fileExtension)."
		case .microphoneNotFound(let microphoneId):
			return "Microphone with id \(microphoneId) not found"
		case .noDisplaysConnected:
			return "At least one display must be connected."
		case .noTargetProvided:
			return "No target provider."
		case .recorderAlreadyStarted:
			return "Recorder has already started. Each recorder instance can only be started once."
		case .targetNotFound(let targetId):
			return "Target with id \(targetId) not found."
		case .noPermissions:
			return "Missing screen capture permissions."
		case .unknown:
			return "An unknown error has occurred."
		}
	}
}
