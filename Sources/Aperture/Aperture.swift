import Foundation
import AVFoundation
import ScreenCaptureKit

public enum Aperture {
	public enum VideoCodec {
		case h264
		case hevc
		case proRes422
		case proRes4444
	}

	public struct RecordingOptions {
		public init(
			destination: URL,
			targetID: String? = nil,
			framesPerSecond: Int = 60,
			cropRect: CGRect? = nil,
			showCursor: Bool = true,
			highlightClicks: Bool = false,
			videoCodec: VideoCodec = .h264,
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
		let videoCodec: VideoCodec
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
		case recorderNotStarted
		case targetNotFound(String)
		case couldNotAddInput(String)
		case couldNotStartStream(Swift.Error?)
		case microphoneNotFound(String)
		case noTargetProvided
		case unsupportedFileExtension(String, Bool)
		case invalidFileExtension(String, String)
		case noDisplaysConnected
		case noPermissions
		case unsupportedVideoCodec
		case unknown(Swift.Error)
	}
}

extension Aperture {
	public final class Recorder: NSObject {
		private var recordingSession: RecordingSession?

		public var onStart: (() -> Void)?
		public var onFinish: (() -> Void)?
		public var onPause: (() -> Void)?
		public var onResume: (() -> Void)?

		public var onError: ((Error) -> Void)? {
			didSet {
				recordingSession?.onError = onError
			}
		}

		public func startRecording(
			target: Target,
			options: RecordingOptions
		) async throws {
			guard recordingSession == nil else {
				throw Error.recorderAlreadyStarted
			}

			let recordingSession = RecordingSession()
			recordingSession.onError = onError
			try await recordingSession.startRecording(target: target, options: options)
			self.recordingSession = recordingSession
			onStart?()
		}

		public func stopRecording() async throws {
			guard let recordingSession else {
				throw Error.recorderNotStarted
			}

			try await recordingSession.stopRecording()
			self.recordingSession = nil
			onFinish?()
		}

		public func pause() throws {
			guard let recordingSession else {
				throw Error.recorderNotStarted
			}

			recordingSession.pause()
			onPause?()
		}

		public func resume() async throws {
			guard let recordingSession else {
				throw Error.recorderNotStarted
			}

			await recordingSession.resume()
			onResume?()
		}
	}
}

extension Aperture {
	internal final class RecordingSession: NSObject {
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
		private(set) var isPaused = false

		/// Internal helpers for when we are resuming, used to fix the buffer timing
		private var isResuming = false
		private var timeOffset = CMTime.zero
		private var lastFrame: CMTime?

		/// Continuation to resolve when we have started writting to the output file
		private var continuation: CheckedContinuation<Void, any Swift.Error>?
		/// Continuation to resolve when the recording has resumed
		private var resumeContinuation: CheckedContinuation<Void, Never>?
		/// Holds any errors that are throwing during the recording, we throw them when we stop
		private var error: Error?

		/// The options for the current recording
		private var options: RecordingOptions?
		/// The target type for the current recording
		private var target: Target?

		/// The error handler for the recording session
		var onError: ((Error) -> Void)?

		func startRecording(
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
				let finalError: Aperture.Error
				if let error = error as? Aperture.Error {
					finalError = error
				} else {
					finalError = Error.couldNotStartStream(error)
				}

				try? await cleanUp()
				onError?(finalError)

				throw finalError
			}
		}

		func stopRecording() async throws {
			if let error {
				/// We do not clean up here, as we have already cleaned up when the error was recorded
				throw error
			}

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

			if microphoneCaptureSession?.isRunning == true {
				microphoneCaptureSession?.stopRunning()
			}

			if externalDeviceCaptureSession?.isRunning == true {
				externalDeviceCaptureSession?.stopRunning()
			}

			if let assetWriter, assetWriter.status == .writing {
				if let videoInput, assetWriter.inputs.contains([videoInput]) {
					videoInput.markAsFinished()
				}

				if let systemAudioInput, assetWriter.inputs.contains([systemAudioInput]) {
					systemAudioInput.markAsFinished()
				}

				if let microphoneInput, assetWriter.inputs.contains([microphoneInput]) {
					microphoneInput.markAsFinished()
				}

				await assetWriter.finishWriting()
			}

			if let activity {
				ProcessInfo.processInfo.endActivity(activity)
				self.activity = nil
			}
		}

		func pause() {
			isPaused = true
		}

		func resume() async {
			await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
				self.resumeContinuation = continuation

				isPaused = false
				isResuming = true
			}
		}
	}
}

extension Aperture.RecordingSession {
	private func getAssetWriter(target: Aperture.Target, options: Aperture.RecordingOptions) throws -> AVAssetWriter {
		let fileType: AVFileType
		let fileExtension = options.destination.pathExtension

		if target == .audioOnly {
			switch fileExtension {
			case "m4a":
				fileType = .m4a
			default:
				throw Aperture.Error.unsupportedFileExtension(fileExtension, true)
			}
		} else {
			switch fileExtension {
			case "mp4":
				/// ProRes is only supported in .mov containers
				switch options.videoCodec {
				case .proRes422, .proRes4444:
					throw Aperture.Error.invalidFileExtension(fileExtension, options.videoCodec.asString)
				default:
					break
				}

				fileType = .mp4
			case "mov":
				fileType = .mov
			case "m4v":
				/// ProRes is only supported in .mov containers
				switch options.videoCodec {
				case .proRes422, .proRes4444:
					throw Aperture.Error.invalidFileExtension(fileExtension, options.videoCodec.asString)
				default:
					break
				}

				fileType = .m4v
			default:
				throw Aperture.Error.unsupportedFileExtension(fileExtension, false)
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
			} else {
				throw Aperture.Error.couldNotStartStream(Aperture.Error.couldNotAddInput("systemAudio"))
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
			} else {
				throw Aperture.Error.couldNotStartStream(Aperture.Error.couldNotAddInput("microphone"))
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
		guard target != .audioOnly else {
			return
		}

		guard
			let assetWriter,
			let continuation,
			let options,
			let dimensions = sampleBuffer.formatDescription?.dimensions
		else {
			continuation?.resume(throwing: Aperture.Error.couldNotStartStream(nil))
			self.continuation = nil
			return
		}


		let assistant: AVOutputSettingsAssistant?

		switch options.videoCodec {
		case .h264:
			assistant = AVOutputSettingsAssistant(
				preset: .preset3840x2160
			)

			assistant?.sourceVideoFormat = try? CMVideoFormatDescription(
				videoCodecType: .h264,
				width: Int(dimensions.width),
				height: Int(dimensions.height)
			)
		case .hevc:
			assistant = AVOutputSettingsAssistant(
				preset: .hevc7680x4320
			)

			assistant?.sourceVideoFormat = try? CMVideoFormatDescription(
				videoCodecType: .hevc,
				width: Int(dimensions.width),
				height: Int(dimensions.height)
			)
		default:
			assistant = nil
		}

		var outputSettings: [String: Any] = assistant?.videoSettings ?? [AVVideoCodecKey: options.videoCodec.asAVVideoCodec]

		outputSettings[AVVideoWidthKey] = dimensions.width
		outputSettings[AVVideoHeightKey] = dimensions.height

		switch options.videoCodec {
		case .h264:
			outputSettings[AVVideoColorPropertiesKey] = [
				AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
				AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
				AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
			]
		case .hevc:
			outputSettings[AVVideoColorPropertiesKey] = [
				AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
				AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
				AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
			]
		default:
			break
		}

		let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)

		self.videoInput = videoInput

		videoInput.expectsMediaDataInRealTime = true

		if assetWriter.canAdd(videoInput) {
			assetWriter.add(videoInput)
		} else {
			continuation.resume(throwing: Aperture.Error.couldNotStartStream(Aperture.Error.couldNotAddInput("video")))
			self.continuation = nil
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

	private func handleBuffer(buffer: CMSampleBuffer, isVideo: Bool) -> CMSampleBuffer {
		/// Use the video buffer to syncronize after pausing if we have it, otherwise the audio
		guard isVideo || target == .audioOnly else {
			return buffer
		}

		var resultBuffer = buffer

		if isResuming {
			isResuming = false
			resumeContinuation?.resume()

			guard let lastFrame else {
				return buffer
			}

			let offset = buffer.presentationTimeStamp - timeOffset - lastFrame
			timeOffset = timeOffset.value == 0 ? offset : timeOffset + offset
		}

		resultBuffer = resultBuffer.adjustTime(by: timeOffset) ?? resultBuffer
		self.lastFrame = resultBuffer.presentationTimeStamp + (resultBuffer.duration.value > 0 ? resultBuffer.duration : .zero)

		return resultBuffer
	}
}

extension Aperture.RecordingSession: SCStreamDelegate {
	public func stream(_ stream: SCStream, didStopWithError error: any Error) {
		recordError(error: .unknown(error))
	}
}

extension Aperture.RecordingSession: SCStreamOutput {
	public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
		guard !isPaused, sampleBuffer.isValid else {
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

			if
				assetWriter != nil,
				!isRunning
			{
				startVideoStream(sampleBuffer: sampleBuffer)
			}

			if isRunning, let videoInput, videoInput.isReadyForMoreMediaData {
				videoInput.append(sampleBuffer)
			}
		case .audio:
			if
				assetWriter != nil,
				!isRunning,
				target == .audioOnly
			{
				startAudioStream(sampleBuffer: sampleBuffer)
			}

			if isRunning, let systemAudioInput, systemAudioInput.isReadyForMoreMediaData {
				systemAudioInput.append(sampleBuffer)
			}
		case .microphone:
			if
				assetWriter != nil,
				!isRunning,
				target == .audioOnly
			{
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

extension Aperture.RecordingSession: AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
	public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		guard !isPaused else {
			return
		}

		let sampleBuffer = handleBuffer(buffer: sampleBuffer, isVideo: output is AVCaptureVideoDataOutput)

		if output is AVCaptureAudioDataOutput {
			if
				assetWriter != nil,
				!isRunning,
				target == .audioOnly
			{
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
