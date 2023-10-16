import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'shadow_platform_interface.dart';

/// An implementation of [ShadowPlatform] that uses method channels.
class MethodChannelShadow extends ShadowPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('shadow');
  final _micEventChannel = const EventChannel('phoenixMicEventChannel');
  final _screenCaptureEventChannel = const EventChannel('phoenixEventChannel');

  final _microphonePermissionEventChannel =
      const EventChannel('phoenixMicrophonePermissionEventChannel');
  final _screenRecordingPermissionEventChannel =
      const EventChannel('phoenixScreenRecordingPermissionEventChannel');

  //Event Streams
  @override
  Stream<dynamic> get microphoneEvents =>
      _micEventChannel.receiveBroadcastStream();

  @override
  Stream<dynamic> get screenCaptureEvents =>
      _screenCaptureEventChannel.receiveBroadcastStream();

  @override
  Stream<dynamic> get microphonePermissionEvents =>
      _microphonePermissionEventChannel.receiveBroadcastStream();

  @override
  Stream<dynamic> get screenRecordingPermissionEvents =>
      _screenRecordingPermissionEventChannel.receiveBroadcastStream();

  @override
  Future<void> deleteFileIfExists(String fileName) async {
    return methodChannel
        .invokeMethod('deleteFileIfExists', {'fileName': fileName});
  }

  @override
  Future<void> openMicSystemSetting() async {
    return methodChannel.invokeMethod('openMicSystemSetting');
  }

  @override
  Future<void> openScreenSystemSetting() async {
    return methodChannel.invokeMethod('openScreenSystemSetting');
  }

  @override
  Future<bool> isMicPermissionGranted() async {
    final result =
        await methodChannel.invokeMethod<bool>('isMicPermissionGranted');
    return result ?? false;
  }

  @override
  Future<bool> isScreenPermissionGranted() async {
    final result =
        await methodChannel.invokeMethod<bool>('isScreenPermissionGranted');
    return result ?? false;
  }

  @override
  Future<void> requestScreenPermission() async {
    return methodChannel.invokeMethod('requestScreenPermission');
  }

  @override
  Future<void> requestMicPermission() async {
    return methodChannel.invokeMethod('requestMicPermission');
  }

  //Test
  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  //SystemAudio
  @override
  Future startSystemAudioRecordingWithDefault() async {
    return methodChannel.invokeMethod('startSystemAudioRecordingWithDefault');
  }

  @override
  Future startSystemAudioRecordingWithConfig(
      [Map<String, dynamic>? config]) async {
    return methodChannel.invokeMethod(
        'startSystemAudioRecordingWithConfig', config);
  }

  //ScreenCapture
  @override
  Future<void> startScreenCapture() async {
    return methodChannel.invokeMethod('startScreenCapture');
  }

  @override
  Future<void> stopScreenCapture() async {
    return methodChannel.invokeMethod('stopScreenCapture');
  }

  //Microphone
  @override
  Future<void> startMicRecordingWithDefault() async {
    return methodChannel.invokeMethod('startMicRecordingWithDefault');
  }

  @override
  Future<void> startMicRecordingWithConfig(
      [Map<String, dynamic>? config]) async {
    return methodChannel.invokeMethod('startMicRecordingWithConfig', config);
  }

  @override
  Future<void> startMicRecording() async {
    return methodChannel.invokeMethod('startMicRecording');
  }

  @override
  Future<void> stopMicRecording() async {
    return methodChannel.invokeMethod('stopMicRecording');
  }

  @override
  Future<void> startSystemAndMicAudioRecordingWithDefault() async {
    return methodChannel
        .invokeMethod('startSystemAndMicAudioRecordingWithDefault');
  }

  @override
  Future<void> startSystemAndMicAudioRecordingWithConfig({
    Map<String, dynamic>? systemAudioConfig,
    Map<String, dynamic>? micConfig,
  }) async {
    final arguments = {
      'systemAudioConfig': systemAudioConfig,
      'micConfig': micConfig,
    };
    return methodChannel.invokeMethod(
        'startSystemAndMicAudioRecordingWithConfig', arguments);
  }

  @override
  Future<void> stopRecordingMicAndSystemAudio() async {
    return methodChannel.invokeMethod('stopSystemAndMicAudioRecording');
  }
}
