import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'shadow_method_channel.dart';

abstract class ShadowPlatform extends PlatformInterface {
  /// Constructs a ShadowPlatform.
  ShadowPlatform() : super(token: _token);

  static final Object _token = Object();

  static ShadowPlatform _instance = MethodChannelShadow();

  /// The default instance of [ShadowPlatform] to use.
  ///
  /// Defaults to [MethodChannelShadow].
  static ShadowPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ShadowPlatform] when
  /// they register themselves.
  static set instance(ShadowPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  //Event Streams
  Stream<dynamic> get microphoneEvents {
    throw UnimplementedError('microphoneEvents has not been implemented.');
  }

  Stream<dynamic> get screenCaptureEvents {
    throw UnimplementedError('screenCaptureEvents has not been implemented.');
  }

  Stream<dynamic> get microphonePermissionEvents {
    throw UnimplementedError('systemAudioEvents has not been implemented.');
  }

  Stream<dynamic> get screenRecordingPermissionEvents {
    throw UnimplementedError('systemAudioEvents has not been implemented.');
  }

  Future<void> deleteFileIfExists(String fileName) {
    throw UnimplementedError('deleteFileIfExists() has not been implemented.');
  }

  Future<void> requestScreenPermission() {
    throw UnimplementedError(
        'requestScreenPermission() has not been implemented.');
  }

  Future<void> requestMicPermission() {
    throw UnimplementedError(
        'requestMicPermission() has not been implemented.');
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  //SystemAudio
  Future<void> startSystemAudioRecordingWithDefault() {
    throw UnimplementedError(
        'startSystemAudioRecordingWithDefault() has not been implemented.');
  }

  Future<void> startSystemAudioRecordingWithConfig(
      [Map<String, dynamic>? config]) {
    throw UnimplementedError(
        'startSystemAudioRecordingWithConfig() has not been implemented.');
  }

  //ScreenCapture
  Future<void> startScreenCapture() {
    throw UnimplementedError('startScreenCapture() has not been implemented.');
  }

  Future<void> stopScreenCapture() {
    throw UnimplementedError('stopScreenCapture() has not been implemented.');
  }

  //Microphone
  Future<void> startMicRecordingWithConfig([Map<String, dynamic>? config]) {
    throw UnimplementedError('startMicRecording() has not been implemented.');
  }

  Future<void> startMicRecordingWithDefault() {
    throw UnimplementedError('startMicRecording() has not been implemented.');
  }

  Future<void> startMicRecording() {
    throw UnimplementedError('startMicRecording() has not been implemented.');
  }

  Future<void> stopMicRecording() {
    throw UnimplementedError('stopMicRecording() has not been implemented.');
  }

  Future<void> startSystemAndMicAudioRecordingWithDefault() {
    throw UnimplementedError(
        'startSystemAndMicAudioRecordingWithDefault() has not been implemented.');
  }

  Future<void> startSystemAndMicAudioRecordingWithConfig({
    Map<String, dynamic>? systemAudioConfig,
    Map<String, dynamic>? micConfig,
  }) {
    throw UnimplementedError(
        'startSystemAndMicAudioRecordingWithConfig() has not been implemented.');
  }

  Future<void> stopRecordingMicAndSystemAudio() {
    throw UnimplementedError(
        'stopRecordingMicAndSystemAudio() has not been implemented.');
  }
}
