import 'shadow_platform_interface.dart';

//User facing API
class Shadow {
  Stream<dynamic> get microphoneEvents =>
      ShadowPlatform.instance.microphoneEvents;

  Stream<dynamic> get screenCaptureEvents =>
      ShadowPlatform.instance.screenCaptureEvents;

  Stream<dynamic> get microphonePermissionEvents =>
      ShadowPlatform.instance.microphonePermissionEvents;

  Stream<dynamic> get screenRecordingPermissionEvents =>
      ShadowPlatform.instance.screenRecordingPermissionEvents;

  Future<void> deleteFileIfExists(String fileName) {
    return ShadowPlatform.instance.deleteFileIfExists(fileName);
  }

  Future<void> requestScreenPermission() {
    return ShadowPlatform.instance.requestScreenPermission();
  }

  Future<void> requestMicPermission() {
    return ShadowPlatform.instance.requestMicPermission();
  }

  //Test
  Future<String?> getPlatformVersion() {
    return ShadowPlatform.instance.getPlatformVersion();
  }

  //System Audio
  Future<void> startSystemAudioRecordingWithConfig(
      [Map<String, dynamic>? config]) {
    return ShadowPlatform.instance.startSystemAudioRecordingWithConfig(config);
  }

  Future<void> startSystemAudioRecordingWithDefault() {
    return ShadowPlatform.instance.startSystemAudioRecordingWithDefault();
  }

  //ScreenCapture
  Future<void> startScreenCapture() {
    return ShadowPlatform.instance.startScreenCapture();
  }

  Future<void> stopScreenCapture() {
    return ShadowPlatform.instance.stopScreenCapture();
  }

  //Microphone
  Future<void> startMicRecordingWithConfig([Map<String, dynamic>? config]) {
    return ShadowPlatform.instance.startMicRecordingWithConfig(config);
  }

  Future<void> startMicRecordingWithDefault() {
    return ShadowPlatform.instance.startMicRecordingWithDefault();
  }

  Future<void> startMicRecording() {
    return ShadowPlatform.instance.startMicRecording();
  }

  Future<void> stopMicRecording() {
    return ShadowPlatform.instance.stopMicRecording();
  }

  //System and Mic Audio
  Future<void> startSystemAndMicAudioRecordingWithDefault() {
    return ShadowPlatform.instance.startSystemAndMicAudioRecordingWithDefault();
  }

  Future<void> startSystemAndMicAudioRecordingWithConfig({
    Map<String, dynamic>? systemAudioConfig,
    Map<String, dynamic>? micConfig,
  }) {
    return ShadowPlatform.instance.startSystemAndMicAudioRecordingWithConfig(
        systemAudioConfig: systemAudioConfig, micConfig: micConfig);
  }

  Future<void> stopRecordingMicAndSystemAudio() {
    return ShadowPlatform.instance.stopRecordingMicAndSystemAudio();
  }
}
