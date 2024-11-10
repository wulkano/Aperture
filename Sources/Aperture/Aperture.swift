import Foundation
import AVFoundation
import ScreenCaptureKit

public enum Aperture {
	public struct RecordingOptions {
		public init(
			destination: URL,
			targetID: String? = nil,
			framesPerSecond: Int = 60,
			cropRect: CGRect? = nil,
			showCursor: Bool = true,
			highlightClicks: Bool = false,
			videoCodec: AVVideoCodecType = .h264,
			losslessAudio: Bool = false,
			recordSystemAudio: Bool = false,
			microphoneDeviceID: String? = nil
		) {
			self.destination = destination
			self.targetID = targetID
			self.framesPerSecond = framesPerSecond
			self.cropRect = cropRect
			self.showCursor = showCursor
			self.highlightClicks = highlightClicks
			self.videoCodec = videoCodec
			self.losslessAudio = losslessAudio
			self.recordSystemAudio = recordSystemAudio
			self.microphoneDeviceID = microphoneDeviceID
		}

		let destination: URL
		let targetID: String?
		let framesPerSecond: Int
		let cropRect: CGRect?
		let showCursor: Bool
		let highlightClicks: Bool
		let videoCodec: AVVideoCodecType
		let losslessAudio: Bool
		let recordSystemAudio: Bool
		let microphoneDeviceID: String?
	}

	public enum Target {
		case screen
		case window
		case externalDevice
		case audioOnly
	}

	public enum Error: Swift.Error {
		case recorderAlreadyStarted
		case targetNotFound(String)
		case couldNotStartStream(Swift.Error?)
		case microphoneNotFound(String)
		case noTargetProvided
		case invalidFileExtension(String, Bool)
		case noDisplaysConnected
		case noPermissions
		case unknown(Swift.Error)
	}
}

extension Aperture {
	public final class Recorder: NSObject {
		/// The stream object for capturing anything on displays
		private var stream: SCStream?
		private var isStreamRecording = false
		/// The writer that will combine all the video/audio inputs into the destination file
		private var assetWriter: AVAssetWriter?

		/// The video stream
		private var videoInput: AVAssetWriterInput?
		/// The optional system audio stream
		private var systemAudioInput: AVAssetWriterInput?
		/// The optional microphone audio stream
		private var microphoneInput: AVAssetWriterInput?

		/// The data output stream for the microphone session
		private var microphoneDataOutput: AVCaptureAudioDataOutput?
		/// The data output stream for the external device session
		private var externalDeviceDataOutput: AVCaptureAudioDataOutput?

		/// The microphone capturing session for versions before macOS 15
		private var microphoneCaptureSession: AVCaptureSession?
		/// The external device capturing session
		private var externalDeviceCaptureSession: AVCaptureSession?

		/// Activity to prevent going to sleep
		private var activity: NSObjectProtocol?

		/// Whether the recorder has started writting to the output file
		private var isRunning = false
		/// Whether the recorder is paused
		private var isPaused = false

		/// Internal helpers for when we are resuming, used to fix the buffer timing
		private var isResuming = false
		private var timeOffset = CMTime.zero
		private var lastFrame: CMTime?

		/// Continuation to resolve when we have started writting to the output file
		private var continuation: CheckedContinuation<Void, any Swift.Error>?
		/// Holds any errors that are throwing during the recording, we throw them when we stop
		private var error: Error?

		/// The options for the current recording
		private var options: RecordingOptions?
		/// The target type for the current recording
		private var target: Target?

		/// Allow consumer to set hooks for various events
		public var onStart: (() -> Void)?
		public var onFinish: (() -> Void)?
		public var onError: ((Error) -> Void)?
		public var onPause: (() -> Void)?
		public var onResume: (() -> Void)?

		public func startRecording(
			target: Target,
			options: RecordingOptions
		) async throws {
			if self.target != nil {
				throw Error.recorderAlreadyStarted
			}

			self.target = target
			self.options = options

			if target != .audioOnly {
				guard options.targetID != nil else {
					throw Error.noTargetProvided
				}
			}

			let streamConfig = SCStreamConfiguration()

			streamConfig.queueDepth = 6

			switch options.videoCodec {
			case .h264:
				streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
				streamConfig.colorSpaceName = CGColorSpace.sRGB
			case .hevc:
				streamConfig.pixelFormat = kCVPixelFormatType_ARGB2101010LEPacked
				streamConfig.colorSpaceName = CGColorSpace.displayP3
			default:
				break
			}

			let filter: SCContentFilter?

			let content: SCShareableContent
			do {
				content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
			} catch let error as SCStreamError {
				if error.code == .userDeclined {
					throw Error.noPermissions
				}

				throw Error.couldNotStartStream(error)
			} catch {
				throw Error.couldNotStartStream(error)
			}

			streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(target == .audioOnly ? 1 : options.framesPerSecond))
			streamConfig.showsCursor = options.showCursor
			if #available(macOS 15.0, *) {
				streamConfig.showMouseClicks = options.highlightClicks
			}

			if options.recordSystemAudio {
				streamConfig.capturesAudio = true
			}

			if #available(macOS 15, *), let microphoneDeviceID = options.microphoneDeviceID  {
				streamConfig.captureMicrophone = true
				streamConfig.microphoneCaptureDeviceID = microphoneDeviceID
			}

			switch target {
			case .screen:
				guard let targetID = options.targetID else {
					throw Error.noTargetProvided
				}

				guard let display = content.displays.first(where: { display in
					String(display.displayID) == targetID
				}) else {
					throw Error.targetNotFound(targetID)
				}

				let screenFilter = SCContentFilter(display: display, excludingWindows: [])

				if let cropRect = options.cropRect {
					streamConfig.sourceRect = cropRect
					streamConfig.width = Int(cropRect.width) * display.scaleFactor
					streamConfig.height = Int(cropRect.height) * display.scaleFactor
				} else {
					if #available(macOS 14.0, *) {
						streamConfig.width = Int(screenFilter.contentRect.width) * display.scaleFactor
						streamConfig.height = Int(screenFilter.contentRect.height) * display.scaleFactor
					} else {
						streamConfig.width = Int(display.frame.width) * display.scaleFactor
						streamConfig.height = Int(display.frame.height) * display.scaleFactor
					}
				}

				filter = screenFilter
			case .window:
				/// We need to call this before `SCContentFilter` below otherwise an error is thrown: https://forums.developer.apple.com/forums/thread/743615
				initializeCGS()

				guard let targetID = options.targetID else {
					throw Error.noTargetProvided
				}

				guard let window = content.windows.first(where: { window in
					String(window.windowID) == targetID
				}) else {
					throw Error.targetNotFound(targetID)
				}

				let windowFilter = SCContentFilter(desktopIndependentWindow: window)

				if #available(macOS 14.0, *) {
					streamConfig.width = Int(windowFilter.contentRect.width)
					streamConfig.height = Int(windowFilter.contentRect.height)
				} else {
					streamConfig.width = Int(window.frame.width)
					streamConfig.height = Int(window.frame.height)
				}

				filter = windowFilter
			case .externalDevice:
				filter = nil
			case .audioOnly:
				guard let display = content.displays.first else {
					throw Error.noDisplaysConnected
				}

				let screenFilter = SCContentFilter(display: display, excludingWindows: [])
				filter = screenFilter
			}

			if let filter {
				stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
			}

			if let stream {
				do {
					try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())

					if options.recordSystemAudio {
						try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
					}

					if #available(macOS 15, *), options.microphoneDeviceID != nil  {
						try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: .global())
					}
				} catch {
					throw Error.couldNotStartStream(error)
				}
			}

			do {
				try await initOutput(target: target, options: options, streamConfig: streamConfig)
			} catch {
				try? await cleanUp()
				throw error is Error ? error : Error.couldNotStartStream(error)
			}
		}

		public func stopRecording() async throws {
			if let error {
				throw error
			}

			onFinish?()
			try? await cleanUp()
		}

		private func recordError(error: Error) {
			self.error = error
			onError?(error)
			Task { try? await self.cleanUp() }
		}

		private func cleanUp() async throws {
			if isStreamRecording {
				try? await stream?.stopCapture()
			}

			videoInput?.markAsFinished()
			systemAudioInput?.markAsFinished()
			microphoneInput?.markAsFinished()

			if microphoneCaptureSession?.isRunning == true {
				microphoneCaptureSession?.stopRunning()
			}

			if externalDeviceCaptureSession?.isRunning == true {
				externalDeviceCaptureSession?.stopRunning()
			}

			if assetWriter?.status == .writing {
				await assetWriter?.finishWriting()
			}

			if let activity {
				ProcessInfo.processInfo.endActivity(activity)
				self.activity = nil
			}
		}

		public func pause() {
			isPaused = true
			onPause?()
		}

		public func resume() {
			isPaused = false
			isResuming = true
			onResume?()
		}
	}
}

extension Aperture.Recorder {
	private func getAssetWriter(target: Aperture.Target, options: Aperture.RecordingOptions) throws -> AVAssetWriter {
		let fileType: AVFileType
		let fileExtension = options.destination.pathExtension

		if target == .audioOnly {
			switch fileExtension {
			case "m4a":
				fileType = .m4a
			default:
				throw Aperture.Error.invalidFileExtension(fileExtension, true)
			}
		} else {
			switch fileExtension {
			case "mp4":
				fileType = .mp4
			case "mov":
				fileType = .mov
			case "m4v":
				fileType = .m4v
			default:
				throw Aperture.Error.invalidFileExtension(fileExtension, false)
			}
		}

		return try AVAssetWriter(outputURL: options.destination, fileType: fileType)
	}

	private func initOutput(target: Aperture.Target, options: Aperture.RecordingOptions, streamConfig: SCStreamConfiguration) async throws {
		let assetWriter = try getAssetWriter(target: target, options: options)

		var audioSettings: [String: Any] = [
			AVSampleRateKey: 48_000,
			AVNumberOfChannelsKey: 2
		]

		if options.losslessAudio {
			audioSettings[AVFormatIDKey] = kAudioFormatAppleLossless
			audioSettings[AVEncoderBitDepthHintKey] = 16
		} else {
			audioSettings[AVFormatIDKey] = kAudioFormatMPEG4AAC
		}

		self.assetWriter = assetWriter

		if options.recordSystemAudio {
			let systemAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)

			self.systemAudioInput = systemAudioInput

			systemAudioInput.expectsMediaDataInRealTime = true

			if assetWriter.canAdd(systemAudioInput) {
				assetWriter.add(systemAudioInput)
			}
		}

		if let microphoneDeviceID = options.microphoneDeviceID {
			let channels: Int

			if #available(macOS 15, *), target != .externalDevice {
				channels = 2
			} else {
				let deviceTypes: [AVCaptureDevice.DeviceType]

				if #available(macOS 14, *) {
					deviceTypes = [.microphone, .external]
				} else {
					deviceTypes = [.builtInMicrophone, .externalUnknown]
				}

				guard let microphoneDevice = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .audio, position: .unspecified).devices.first(where: { device in
					device.uniqueID == microphoneDeviceID
				}) else {
					throw Aperture.Error.microphoneNotFound(microphoneDeviceID)
				}

				guard let microphoneChannels = microphoneDevice.formats.first?.formatDescription.audioChannelLayout?.numberOfChannels else {
					throw Aperture.Error.microphoneNotFound(microphoneDeviceID)
				}

				channels = microphoneChannels

				let microphoneCaptureSession = AVCaptureSession()
				self.microphoneCaptureSession = microphoneCaptureSession

				let microphoneCaptureInput = try AVCaptureDeviceInput(device: microphoneDevice)
				if microphoneCaptureSession.canAddInput(microphoneCaptureInput) {
					microphoneCaptureSession.addInput(microphoneCaptureInput)
				}

				let microphoneDataOutput = AVCaptureAudioDataOutput()
				self.microphoneDataOutput = microphoneDataOutput
				let microphoneQueue = DispatchQueue(label: "microphoneQueue")
				microphoneDataOutput.setSampleBufferDelegate(self, queue: microphoneQueue)
				if microphoneCaptureSession.canAddOutput(microphoneDataOutput) {
					microphoneCaptureSession.addOutput(microphoneDataOutput)
				}
			}

			audioSettings[AVNumberOfChannelsKey] = channels

			let microphoneInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)

			self.microphoneInput = microphoneInput

			microphoneInput.expectsMediaDataInRealTime = true

			if assetWriter.canAdd(microphoneInput) {
				assetWriter.add(microphoneInput)
			}
		}

		if target == .externalDevice {
			let deviceTypes: [AVCaptureDevice.DeviceType]

			if #available(macOS 14, *) {
				deviceTypes = [.external]
			} else {
				deviceTypes = [.externalUnknown]
			}

			enableDalDevices()

			guard let targetID = options.targetID else {
				throw Aperture.Error.noTargetProvided
			}

			guard let device = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: nil, position: .unspecified).devices.first(where: { device in
				device.uniqueID == targetID
			}) else {
				throw Aperture.Error.targetNotFound(targetID)
			}

			let externalDeviceCaptureSession = AVCaptureSession()
			self.externalDeviceCaptureSession = externalDeviceCaptureSession

			let deviceCaptureInput = try AVCaptureDeviceInput(device: device)
			if externalDeviceCaptureSession.canAddInput(deviceCaptureInput) {
				externalDeviceCaptureSession.addInput(deviceCaptureInput)
			}

			let deviceDataOuput = AVCaptureVideoDataOutput()
			let deviceQueue = DispatchQueue(label: "deviceQueue")
			deviceDataOuput.setSampleBufferDelegate(self, queue: deviceQueue)
			if externalDeviceCaptureSession.canAddOutput(deviceDataOuput) {
				externalDeviceCaptureSession.addOutput(deviceDataOuput)
			}

			let deviceAudioOutput = AVCaptureAudioDataOutput()
			self.externalDeviceDataOutput = deviceAudioOutput
			let deviceAudioQueue = DispatchQueue(label: "deviceAudioQueue")
			deviceAudioOutput.setSampleBufferDelegate(self, queue: deviceAudioQueue)
			if externalDeviceCaptureSession.canAddOutput(deviceAudioOutput) {
				externalDeviceCaptureSession.addOutput(deviceAudioOutput)
			}
		}

		microphoneCaptureSession?.startRunning()
		externalDeviceCaptureSession?.startRunning()

		try await stream?.startCapture()
		isStreamRecording = true
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Swift.Error>) in
			self.continuation = continuation
		}
		activity = ProcessInfo.processInfo.beginActivity(options: .idleSystemSleepDisabled, reason: "Recording screen")
	}

	private func startAudioStream(sampleBuffer: CMSampleBuffer) {
		guard let assetWriter, let continuation else {
			return
		}

		isRunning = assetWriter.startWriting()

		if isRunning {
			assetWriter.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
			continuation.resume(returning: ())
		} else {
			continuation.resume(throwing: Aperture.Error.couldNotStartStream(assetWriter.error))
		}

		self.continuation = nil
	}

	private func startVideoStream(sampleBuffer: CMSampleBuffer) {
		if target == .audioOnly {
			return
		}

		guard
			let assetWriter,
			let continuation,
			let options,
			let dimensions = sampleBuffer.formatDescription?.dimensions
		else {
			return
		}

		let assistant = AVOutputSettingsAssistant(
			preset: options.videoCodec == .h264 ? .preset3840x2160 : .hevc7680x4320
		)

		assistant?.sourceVideoFormat = try? CMVideoFormatDescription(
			videoCodecType: options.videoCodec == .h264 ? .h264 : .hevc,
			width: Int(dimensions.width),
			height: Int(dimensions.height)
		)

		var outputSettings: [String: Any] = assistant?.videoSettings ?? [AVVideoCodecKey: options.videoCodec]

		outputSettings[AVVideoWidthKey] = dimensions.width
		outputSettings[AVVideoHeightKey] = dimensions.height

		outputSettings[AVVideoColorPropertiesKey] = options.videoCodec == .h264 ? [
			AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
			AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
			AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
		] : [
			AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
			AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
			AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
		]

		let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)

		self.videoInput = videoInput

		videoInput.expectsMediaDataInRealTime = true

		if assetWriter.canAdd(videoInput) {
			assetWriter.add(videoInput)
		}

		isRunning = assetWriter.startWriting()
		if isRunning {
			assetWriter.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
			continuation.resume(returning: ())
		} else {
			continuation.resume(throwing: Aperture.Error.couldNotStartStream(assetWriter.error))
		}

		self.continuation = nil
	}

	private func handleBuffer(buffer: CMSampleBuffer, isVideo: Bool) -> CMSampleBuffer {
		/// Use the video buffer to syncronize after pausing if we have it, otherwise the audio
		if !isVideo && target != .audioOnly {
			return buffer
		}

		var resultBuffer = buffer

		if isResuming {
			isResuming = false

			var pts = CMSampleBufferGetPresentationTimeStamp(buffer)
			guard let lastFrame else {
				return buffer
			}
			if lastFrame.flags.contains(.valid) {
				if timeOffset.value > 0 {
					pts = CMTimeSubtract(pts, timeOffset)
				}

				let offset = CMTimeSubtract(pts, lastFrame)
				if timeOffset.value == 0 {
					timeOffset = offset
				} else {
					timeOffset = CMTimeAdd(timeOffset, offset)
				}
			}
			self.lastFrame?.flags = []
		}

		if timeOffset.value > 0 {
			resultBuffer = resultBuffer.adjustTime(by: timeOffset) ?? resultBuffer
		}

		var lastFrame = CMSampleBufferGetPresentationTimeStamp(resultBuffer)
		let dur = CMSampleBufferGetDuration(resultBuffer)
		if dur.value > 0 {
			lastFrame = CMTimeAdd(lastFrame, dur)
		}

		self.lastFrame = lastFrame

		return resultBuffer
	}
}

extension Aperture.Recorder: SCStreamDelegate {
	public func stream(_ stream: SCStream, didStopWithError error: any Error) {
		recordError(error: .unknown(error))
	}
}

extension Aperture.Recorder: SCStreamOutput {
	public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
		if isPaused {
			return
		}
		guard sampleBuffer.isValid else {
			return
		}

		let sampleBuffer = handleBuffer(buffer: sampleBuffer, isVideo: type == .screen)

		switch type {
		case .screen:
			guard
				let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
				let attachments = attachmentsArray.first,
				let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
				let status = SCFrameStatus(rawValue: statusRawValue),
				status == .complete
			else {
			    return
			}

			if assetWriter != nil && !isRunning {
				startVideoStream(sampleBuffer: sampleBuffer)
			}

			if isRunning, let videoInput, videoInput.isReadyForMoreMediaData {
				videoInput.append(sampleBuffer)
			}
		case .audio:
			if assetWriter != nil && !isRunning && target == .audioOnly {
				startAudioStream(sampleBuffer: sampleBuffer)
			}

			if isRunning, let systemAudioInput, systemAudioInput.isReadyForMoreMediaData {
				systemAudioInput.append(sampleBuffer)
			}
		case .microphone:
			if assetWriter != nil && !isRunning && target == .audioOnly {
				startAudioStream(sampleBuffer: sampleBuffer)
			}

			if isRunning, let microphoneInput, microphoneInput.isReadyForMoreMediaData {
				microphoneInput.append(sampleBuffer)
			}
		default:
			break
		}
	}
}

extension Aperture.Recorder: AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
	public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		if isPaused {
			return
		}

		let sampleBuffer = handleBuffer(buffer: sampleBuffer, isVideo: output is AVCaptureVideoDataOutput)

		if output is AVCaptureAudioDataOutput {
			if assetWriter != nil && !isRunning && target == .audioOnly {
				startAudioStream(sampleBuffer: sampleBuffer)
			}

			if output == self.microphoneDataOutput, let microphoneInput, microphoneInput.isReadyForMoreMediaData, isRunning {
				microphoneInput.append(sampleBuffer)
			}

			if output == self.externalDeviceDataOutput, let systemAudioInput, systemAudioInput.isReadyForMoreMediaData, isRunning {
				systemAudioInput.append(sampleBuffer)
			}
		}

		if output is AVCaptureVideoDataOutput {
			if assetWriter != nil, !isRunning {
				startVideoStream(sampleBuffer: sampleBuffer)
			}

			if let videoInput, videoInput.isReadyForMoreMediaData {
				videoInput.append(sampleBuffer)
			}
		}
	}
}
