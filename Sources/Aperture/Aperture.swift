import Foundation
import AVFoundation
import ScreenCaptureKit

public final class Aperture {
	public struct RecordingOptions {
		public init(
			destination: URL,
			targetId: String? = nil,
			framesPerSecond: Int = 60,
			cropRect: CGRect? = nil,
			showCursor: Bool = true,
			highlightClicks: Bool = false,
			scaleFactor: Int = 1,
			videoCodec: AVVideoCodecType = .h264,
			losslessAudio: Bool = false,
			recordSystemAudio: Bool = false,
			microphoneDeviceId: String? = nil
		) {
			self.destination = destination
			self.targetId = targetId
			self.framesPerSecond = framesPerSecond
			self.cropRect = cropRect
			self.showCursor = showCursor
			self.highlightClicks = highlightClicks
			self.scaleFactor = scaleFactor
			self.videoCodec = videoCodec
			self.losslessAudio = losslessAudio
			self.recordSystemAudio = recordSystemAudio
			self.microphoneDeviceId = microphoneDeviceId
		}

		let destination: URL
		let targetId: String?
		let framesPerSecond: Int
		let cropRect: CGRect?
		let showCursor: Bool
		let highlightClicks: Bool
		let scaleFactor: Int
		let videoCodec: AVVideoCodecType
		let losslessAudio: Bool
		let recordSystemAudio: Bool
		let microphoneDeviceId: String?
	}
	
	public enum Target {
		case screen
		case window
		case externalDevice
		case audioOnly
	}
	
	public enum ApertureError: Swift.Error {
		case recorderAlreadyStarted
		case targetNotFound(String)
		case couldNotStartStream(Swift.Error?)
		case microphoneNotFound(String)
		case noTargetProvided
		case invalidFileExtension(String, Bool)
		case noDisplaysConnected
		case unknownError(Swift.Error)
		case noPermissions
	}
	public final class Recorder: NSObject {
		
		/// The stream object for capturing anything on displays
		private var stream: SCStream?
		private var isStreamRecording: Bool = false
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
		private var isRunning: Bool = false
		/// Whether the recorder is paused
		private var isPaused: Bool = false
		
		/// Internal helpers for when we are resuming, used to fix the buffer timing
		private var isResuming: Bool = false
		private var timeOffset: CMTime = .zero
		private var lastFrame: CMTime? = nil
		
		/// Continuation to resolve when we have started writting to the output file
		private var continuation: CheckedContinuation<Void, Error>? = nil
		/// Holds any errors that are throwing during the recording, we throw them when we stop
		private var error: ApertureError? = nil
		
		/// The options for the current recording
		private var options: RecordingOptions? = nil
		/// The target type for the current recording
		private var target: Target? = nil
		
		/// Allow consumer to set hooks for various events
		public var onStart: (() -> Void)?
		public var onFinish: (() -> Void)?
		public var onError: ((ApertureError) -> Void)?
		public var onPause: (() -> Void)?
		public var onResume: (() -> Void)?
		
		public func startRecording(
			target: Target,
			options: RecordingOptions
		) async throws {
			if self.target != nil {
				throw ApertureError.recorderAlreadyStarted
			}
			
			self.target = target
			self.options = options
			
			if target != .audioOnly {
				guard options.targetId != nil else {
					throw ApertureError.noTargetProvided
				}
			}
			
			let streamConfig: SCStreamConfiguration = SCStreamConfiguration()
			let filter: SCContentFilter?
			
			let content: SCShareableContent
			do {
				content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
			} catch let error as SCStreamError {
				if error.code == .userDeclined {
					throw ApertureError.noPermissions
				}
				
				throw ApertureError.couldNotStartStream(error)
			} catch {
				throw ApertureError.couldNotStartStream(error)
			}
			
			streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(target == .audioOnly ? 1 : options.framesPerSecond))
			streamConfig.showsCursor = options.showCursor
			if #available(macOS 15.0, *) {
				streamConfig.showMouseClicks = options.highlightClicks
			}
			
			if options.recordSystemAudio {
				streamConfig.capturesAudio = true
			}
			
			if #available(macOS 15, *), let microphoneDeviceId = options.microphoneDeviceId  {
				streamConfig.captureMicrophone = true
				streamConfig.microphoneCaptureDeviceID = microphoneDeviceId
			}
			
			switch target {
			case .screen:
				guard let display = content.displays.first(where: { display in
					String(display.displayID) == options.targetId
				}) else {
					throw ApertureError.targetNotFound(options.targetId!)
				}
				
				let screenFilter = SCContentFilter(display: display, excludingWindows: [])
				
				if let cropRect = options.cropRect {
					streamConfig.sourceRect = cropRect
				}
				
				if #available(macOS 14.0, *) {
					streamConfig.width = Int(screenFilter.contentRect.width) * options.scaleFactor
					streamConfig.height = Int(screenFilter.contentRect.height) * options.scaleFactor
				} else {
					streamConfig.width = Int(display.frame.width) * options.scaleFactor
					streamConfig.height = Int(display.frame.height) * options.scaleFactor
				}
				
				filter = screenFilter
				break
			case .window:
				/// We need to cal this before `SCContentFilter` below otherwise an error is thrown: https://forums.developer.apple.com/forums/thread/743615
				initializeCGS()

				guard let window = content.windows.first(where: { window in
					String(window.windowID) == options.targetId
				}) else {
					throw ApertureError.targetNotFound(options.targetId!)
				}
				
				let windowFilter = SCContentFilter(desktopIndependentWindow: window)
				
				if #available(macOS 14.0, *) {
					streamConfig.width = Int(windowFilter.contentRect.width) * options.scaleFactor
					streamConfig.height = Int(windowFilter.contentRect.height) * options.scaleFactor
				} else {
					streamConfig.width = Int(window.frame.width) * options.scaleFactor
					streamConfig.height = Int(window.frame.height) * options.scaleFactor
				}
				
				filter = windowFilter
				break
			case .externalDevice:
				filter = nil
				break
			case .audioOnly:
				guard let display = content.displays.first else {
					throw ApertureError.noDisplaysConnected
				}
				
				let screenFilter = SCContentFilter(display: display, excludingWindows: [])
				filter = screenFilter
				break
			}
			
			if let filter = filter {
				stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
			}
			
			if let stream = stream {
				do {
					try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())
					
					if options.recordSystemAudio {
						try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
					}
					
					if #available(macOS 15, *), options.microphoneDeviceId != nil  {
						try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: .global())
					}
				} catch {
					throw ApertureError.couldNotStartStream(error)
				}
			}
			
			do {
				try await initOutput(target: target, options: options, streamConfig: streamConfig)
			} catch {
				try? await cleanUp()
				throw error is ApertureError ? error : ApertureError.couldNotStartStream(error)
			}
		}
		
		public func stopRecording() async throws {
			if let error = error {
				throw error
			} else {
				onFinish?()
				try? await cleanUp()
			}
		}
		
		private func recordError(error: ApertureError) {
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
			
			if let microphoneCaptureSession = microphoneCaptureSession, microphoneCaptureSession.isRunning {
				microphoneCaptureSession.stopRunning()
			}
			
			if let externalDeviceCaptureSession = externalDeviceCaptureSession, externalDeviceCaptureSession.isRunning {
				externalDeviceCaptureSession.stopRunning()
			}
			
			if (assetWriter?.status == .writing) {
				await assetWriter?.finishWriting()
			}
			
			if let activity = activity {
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

extension Aperture.Recorder: SCStreamDelegate, SCStreamOutput, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
	private func getAssetWriter(target: Aperture.Target, options: Aperture.RecordingOptions) throws -> AVAssetWriter {
		let fileType: AVFileType
		let fileExtension = options.destination.pathExtension

		if target == .audioOnly {
			switch fileExtension {
			case "m4a":
				fileType = .m4a
				break
			default:
				throw Aperture.ApertureError.invalidFileExtension(fileExtension, true)
			}
		} else {
			switch fileExtension {
			case "mp4":
				fileType = .mp4
				break
			case "mov":
				fileType = .mov
				break
			case "m4v":
				fileType = .m4v
				break
			default:
				throw Aperture.ApertureError.invalidFileExtension(fileExtension, false)
			}
		}
		
		return try AVAssetWriter.init(outputURL: options.destination, fileType: fileType)
	}
	
	private func initOutput(target: Aperture.Target, options: Aperture.RecordingOptions, streamConfig: SCStreamConfiguration) async throws {
		let assetWriter = try getAssetWriter(target: target, options: options)
		
		var audioSettings: [String: Any] = [AVSampleRateKey : 48000, AVNumberOfChannelsKey : 2]
		
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
		
		if let microphoneDeviceId = options.microphoneDeviceId {
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
					device.uniqueID == microphoneDeviceId
				}) else {
					throw Aperture.ApertureError.microphoneNotFound(microphoneDeviceId)
				}
				
				guard let microphoneChannels = microphoneDevice.formats.first?.formatDescription.audioChannelLayout?.numberOfChannels else {
					throw Aperture.ApertureError.microphoneNotFound(microphoneDeviceId)
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

			guard let device = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: nil, position: .unspecified).devices.first(where: { device in
				device.uniqueID == options.targetId
			}) else {
				throw Aperture.ApertureError.targetNotFound(options.targetId!)
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
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			self.continuation = continuation
		}
		activity = ProcessInfo.processInfo.beginActivity(options: .idleSystemSleepDisabled, reason: "Recording screen")
	}
	
	private func startAudioStream(sampleBuffer: CMSampleBuffer) {
		guard let assetWriter = assetWriter, let continuation = continuation else {
			return
		}

		isRunning = assetWriter.startWriting()
		
		if isRunning {
			assetWriter.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
			continuation.resume(returning: ())
		} else {
			continuation.resume(throwing: Aperture.ApertureError.couldNotStartStream(assetWriter.error))
		}
		
		self.continuation = nil
	}
	
	private func startVideoStream(sampleBuffer: CMSampleBuffer) {
		if target == .audioOnly {
			return
		}
		
		guard
			let assetWriter = assetWriter,
			let continuation = continuation,
			let options = options,
			let dimensions = sampleBuffer.formatDescription?.dimensions
		else {
			return
		}

		let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
			AVVideoCodecKey: options.videoCodec,
			AVVideoWidthKey: dimensions.width,
			AVVideoHeightKey: dimensions.height,
		])
		
		self.videoInput = videoInput
		
		videoInput.expectsMediaDataInRealTime = true
		
		if (assetWriter.canAdd(videoInput)) {
			assetWriter.add(videoInput)
		}
		
		isRunning = assetWriter.startWriting()
		if isRunning {
			assetWriter.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
			continuation.resume(returning: ())
		} else {
			continuation.resume(throwing: Aperture.ApertureError.couldNotStartStream(assetWriter.error))
		}
		
		self.continuation = nil
	}
	
	public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
		if isPaused {
			return
		}
		guard sampleBuffer.isValid else { return }
		
		let sampleBuffer = handleBuffer(buffer: sampleBuffer, isVideo: type == .screen)
		
		switch type {
		case .screen:
			guard
				let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
				let attachments = attachmentsArray.first,
				let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
				let status = SCFrameStatus(rawValue: statusRawValue),
				status == .complete
			else { return }
			
			if assetWriter != nil && !isRunning {
				startVideoStream(sampleBuffer: sampleBuffer)
			}
			
			if isRunning, let videoInput = videoInput, videoInput.isReadyForMoreMediaData {
				videoInput.append(sampleBuffer)
			}
			
			break
		case .audio:
			if assetWriter != nil && !isRunning && target == .audioOnly {
				startAudioStream(sampleBuffer: sampleBuffer)
			}
			
			if isRunning, let systemAudioInput = systemAudioInput, systemAudioInput.isReadyForMoreMediaData {
				systemAudioInput.append(sampleBuffer)
			}
			break
		case .microphone:
			if assetWriter != nil && !isRunning && target == .audioOnly {
				startAudioStream(sampleBuffer: sampleBuffer)
			}
			
			if isRunning, let microphoneInput = microphoneInput, microphoneInput.isReadyForMoreMediaData {
				microphoneInput.append(sampleBuffer)
			}
			break
		default:
			break
		}
		
	}
	
	public func stream(_ stream: SCStream, didStopWithError error: any Error) {
		recordError(error: .unknownError(error))
	}
	
	public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		if isPaused {
			return
		}
		
		let sampleBuffer = handleBuffer(buffer: sampleBuffer, isVideo: output is AVCaptureVideoDataOutput)
		
		if output is AVCaptureAudioDataOutput {
			if assetWriter != nil && !isRunning && target == .audioOnly {
				startAudioStream(sampleBuffer: sampleBuffer)
			}
			
			if output == self.microphoneDataOutput, let microphoneInput = microphoneInput, microphoneInput.isReadyForMoreMediaData, isRunning {
				microphoneInput.append(sampleBuffer)
			}
			
			if output == self.externalDeviceDataOutput, let systemAudioInput = systemAudioInput, systemAudioInput.isReadyForMoreMediaData, isRunning {
				systemAudioInput.append(sampleBuffer)
			}
		}
		
		if (output is AVCaptureVideoDataOutput) {
			if assetWriter != nil, !isRunning {
				startVideoStream(sampleBuffer: sampleBuffer)
			}
			
			if let videoInput = videoInput, videoInput.isReadyForMoreMediaData {
				videoInput.append(sampleBuffer)
			}
		}
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
			guard let lastFrame = lastFrame else {
				return buffer
			}
			if lastFrame.flags.contains(.valid) {
				if timeOffset.value > 0 {
					pts = CMTimeSubtract(pts, timeOffset)
				}
				
				let offset = CMTimeSubtract(pts, lastFrame)
				if (timeOffset.value == 0) {
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
		if (dur.value > 0) {
			lastFrame = CMTimeAdd(lastFrame, dur)
		}
		
		self.lastFrame = lastFrame
		
		return resultBuffer
	}
}
