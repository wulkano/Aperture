import AVFoundation

internal func initializeCGS() {
	CGMainDisplayID()
}

extension CMSampleBuffer {
	public func adjustTime(by offset: CMTime) -> CMSampleBuffer? {
		guard CMSampleBufferGetFormatDescription(self) != nil else { return nil }
		
		var timingInfo = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: Int(CMSampleBufferGetNumSamples(self)))
		CMSampleBufferGetSampleTimingInfoArray(self, entryCount: timingInfo.count, arrayToFill: &timingInfo, entriesNeededOut: nil)
		
		for i in 0..<timingInfo.count {
			timingInfo[i].decodeTimeStamp = CMTimeSubtract(timingInfo[i].decodeTimeStamp, offset)
			timingInfo[i].presentationTimeStamp = CMTimeSubtract(timingInfo[i].presentationTimeStamp, offset)
		}
		
		var outSampleBuffer: CMSampleBuffer?
		CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: self, sampleTimingEntryCount: timingInfo.count, sampleTimingArray: &timingInfo, sampleBufferOut: &outSampleBuffer)
		
		return outSampleBuffer
	}
}

extension Aperture.ApertureError {
	public var localizedDescription: String {
		switch self {
		case .couldNotStartStream(_):
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
		case .unknownError(_):
			return "An unknown error has occurred."
		case .noPermissions:
			return "Missing screen capture permissions."
		}
	}
}
