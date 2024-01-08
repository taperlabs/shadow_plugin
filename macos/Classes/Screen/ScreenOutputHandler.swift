import Foundation
import AVFAudio
import AVFoundation
import ScreenCaptureKit
import FlutterMacOS

//MARK: - Stream Output 처리 클래스 + Flutter Event Stream 핸들
class ScreenRecorderOutputHandler: NSObject, SCStreamOutput, SCStreamDelegate, FlutterStreamHandler {
    
    //Weak var for preventing Strong Reference Cycle (ARC)
    weak var recorder: ScreenRecorder?
    weak var timeIndicator: TimeIndicator?
    
    var capturedFrameHandler: ((CapturedFrame) -> Void)?
    // Keep track of the original start time.
    var originalStartTime: CMTime?
    
    // Keep track of the offset to apply to timestamps.
    var timeOffset = CMTime.zero
    
    var eventSink: FlutterEventSink?
    private var statusTimer: Timer?
    
    //initalizer
    init(recorder: ScreenRecorder, timeIndicator: TimeIndicator) {
        self.recorder = recorder
        self.timeIndicator = timeIndicator
    }
    
    //Flutter EventStreamHandler 메소드
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // Set the event sink
        self.eventSink = events
        statusTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(sendTimeUpdate), userInfo: nil, repeats: true)
        // Start sending the recording status
        //        startSendingStatus()
        return nil
    }
    
    @objc func sendTimeUpdate() {
        guard let sink = eventSink else { return }
        let time = timeIndicator?.elapsedTime ?? 0
        print("sendTimeUpdate from ScreenCaptureKit 🖥️", time)
        
        let eventData = RecordingStatusEventModel(type: .screenRecordingStatus, isRecording: self.recorder?.isRecording ?? false, elapsedTime: time)
        sink(eventData.recordingStatusDictionary)
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        // Stop sending the recording status
        print("이벤트 구독 취소 입니다!!! 🔥 ScreenOutPUT!!!")
        statusTimer?.invalidate()
        statusTimer = nil
        //        stopSendingStatus()
        // Clear the event sink
        self.eventSink = nil
        
        
        return nil
    }
    
    func startSendingStatus() {
        // Invalidate any existing timer to ensure only one timer is running
        statusTimer?.invalidate()
        
        // Create and start a new timer
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            //            print("isRecordng",self?.recorder?.isRecording)
            if let isRecording = self?.recorder?.isRecording {
                self?.sendRecordingStatusToFlutter(isRecording)
            }
        }
    }
    
    func stopSendingStatus() {
        statusTimer?.invalidate()
        statusTimer = nil
    }
    
    
    
    @objc func sendRecordingStatusToFlutter(_ isRecording: Bool) {
        guard let eventSink = eventSink else { return }
        
        print("센드 리코딩 투 플러터", isRecording)
        
        let eventData = RecordingStatusEventModel(type: .screenRecordingStatus, isRecording: isRecording, elapsedTime: 0)
        
        eventSink(eventData.recordingStatusDictionary)
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        //Error Handler
        print("didStopWithError -> ❌",error)
    }
    
    //ScreenCapture Stream Output
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Return early if the sample buffer is invalid.
        guard sampleBuffer.isValid else { return }
        
        switch type {
        case .screen:
            break
        case .audio:
            let timestampledSampleBuffer = adjustTimeStamp(sampleBuffer: sampleBuffer)
            
            guard let recorder = self.recorder else { return }
            
            
            //            guard let display = recorder.display else { return }
            //
            //            let newFilter = SCContentFilter(display: display[1], including: [], exceptingWindows: [])
            //
            //            stream.updateContentFilter(newFilter)
            
            
            //Audio Buffer discard if clamshell mode
            
            //systemAudioInput에 AudioBuffer 쓰기
            guard let systemAudioInput = recorder.assetWriterSetup.systemAudioInput, systemAudioInput.isReadyForMoreMediaData else {
                print("System Audio Recording Not Ready")
                return
            }
            
            guard let audioData = timestampledSampleBuffer else {
                print("Audio data does not exist")
                return
            }
            
            systemAudioInput.append(audioData)
            //            audioInput.append(realSamplBuffer)
            
        @unknown default:
            fatalError("Encountered unknown stream output type: \(type)")
        }
    }
    
    /// Create a `CapturedFrame` for the video sample buffer.
    private func createFrame(for sampleBuffer: CMSampleBuffer) -> CapturedFrame? {
        
        // Retrieve the array of metadata attachments from the sample buffer.
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,
                                                                             createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let attachments = attachmentsArray.first else { return nil }
        
        // Validate the status of the frame. If it isn't `.complete`, return nil.
        guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
              let status = SCFrameStatus(rawValue: statusRawValue),
              status == .complete else { return nil }
        
        // Get the pixel buffer that contains the image data.
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return nil }
        
        // Get the backing IOSurface.
        guard let surfaceRef = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else { return nil }
        let surface = unsafeBitCast(surfaceRef, to: IOSurface.self)
        
        // Retrieve the content rectangle, scale, and scale factor.
        guard let contentRectDict = attachments[.contentRect],
              let contentRect = CGRect(dictionaryRepresentation: contentRectDict as! CFDictionary),
              let contentScale = attachments[.contentScale] as? CGFloat,
              let scaleFactor = attachments[.scaleFactor] as? CGFloat else { return nil }
        
        
        
        // Create a new frame with the relevant data.
        let frame = CapturedFrame(surface: surface,
                                  contentRect: contentRect,
                                  contentScale: contentScale,
                                  scaleFactor: scaleFactor)
        return frame
    }
    
    func adjustTimeStamp(sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        var copy: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo()
        
        // Get the timing info.
        CMSampleBufferGetSampleTimingInfo(sampleBuffer, at: 0, timingInfoOut: &timingInfo)
        
        // If this is the first buffer, save its presentation timestamp as the original start time.
        if originalStartTime == nil {
            originalStartTime = timingInfo.presentationTimeStamp
        }
        
        // Adjust the timing info for this sample buffer.
        if let originalStartTime = originalStartTime {
            timingInfo.presentationTimeStamp = CMTimeSubtract(timingInfo.presentationTimeStamp, originalStartTime)
            timingInfo.decodeTimeStamp = CMTimeSubtract(timingInfo.decodeTimeStamp, originalStartTime)
        }
        
        timingInfo.presentationTimeStamp = CMTimeAdd(timingInfo.presentationTimeStamp, timeOffset)
        timingInfo.decodeTimeStamp = CMTimeAdd(timingInfo.decodeTimeStamp, timeOffset)
        
        // Create a copy of the sample buffer with the new timing info.
        CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleTimingEntryCount: 1, sampleTimingArray: &timingInfo, sampleBufferOut: &copy)
        
        return copy
    }
}

