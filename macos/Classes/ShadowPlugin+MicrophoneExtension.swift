import Foundation
import FlutterMacOS

//MARK: - An extension for microphone related MethodChannel Call
extension ShadowPlugin {
    
    public func handleMicRecordingWithConfig(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = args else {
            return
        }
        micAudioRecording.startMicAudioRecording(withConfig: args)
        result("Recording started")
    }
    
    public func handleMicRecordingWithDefault(result: @escaping FlutterResult) {
        micAudioRecording.startMicAudioRecording()  // Use default settings
        //This is where Swift sends a message to Flutter via MethodChannel
        result("Recording started")
    }
    
    public func handleStopMicRecording(result: @escaping FlutterResult) {
        print("stopMicRecording called!!!")
        micAudioRecording.stopMicAudioRecording()
        result("Recording stopped")
    }
}
