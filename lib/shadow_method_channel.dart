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
  final _micAudioLevelEventChannel = const EventChannel('micAudioLevelEventChannel');

  final _multiWindowEventChannel = const EventChannel('multiWindowEventChannel');

  final _microphonePermissionEventChannel = const EventChannel('phoenixMicrophonePermissionEventChannel');
  final _screenRecordingPermissionEventChannel = const EventChannel('phoenixScreenRecordingPermissionEventChannel');
  final _nudgeEventChannel = const EventChannel('phoenixNudgeEventChannel');
  final _screenCaptureKitBugEventChannel = const EventChannel('screenCaptureKitBugEventChannel');

  //Recording Event Streams
  @override
  Stream<dynamic> get microphoneEvents => _micEventChannel.receiveBroadcastStream();

  @override
  Stream<dynamic> get screenCaptureEvents => _screenCaptureEventChannel.receiveBroadcastStream();

  //Permission Event Streams
  @override
  Stream<dynamic> get microphonePermissionEvents => _microphonePermissionEventChannel.receiveBroadcastStream();

  @override
  Stream<dynamic> get screenRecordingPermissionEvents => _screenRecordingPermissionEventChannel.receiveBroadcastStream();

  //Nudge
  @override
  Stream<dynamic> get nudgeEvents => _nudgeEventChannel.receiveBroadcastStream();

  @override
  Stream<dynamic> get micAudioLevelEvents => _micAudioLevelEventChannel.receiveBroadcastStream('micAudioLevel');

  @override
  Stream<dynamic> get screenCaptureKitBugEvents => _screenCaptureKitBugEventChannel.receiveBroadcastStream();

  @override
  Stream<dynamic> get multiWindowEvents => _multiWindowEventChannel.receiveBroadcastStream();

  @override
  Future<void> stopListening() async {
    return methodChannel.invokeMethod('stopListening');
  }

  @override
  Future<void> startListening({
    Map<String, dynamic>? listeningConfig,
  }) async {
    final arguments = {
      'listeningConfig': listeningConfig,
    };
    return methodChannel.invokeMethod('startListening', arguments);
  }

  @override
  Future<void> sendHotKeyEvent(String key, List<String> modifiers) async {
    // Passing arguments as a Map
    final arguments = <String, dynamic>{
      'key': key,
      'modifiers': modifiers,
    };
    await methodChannel.invokeMethod('sendHotKeyEvent', arguments);
  }

  @override
  Future<void> createNewWindow({
    Map<String, dynamic>? listeningConfig,
  }) async {
    final arguments = {
      'listeningConfig': listeningConfig,
    };
    return methodChannel.invokeMethod('createNewWindow', arguments);
  }

  @override
  Future<void> stopShadowServer() async {
    return methodChannel.invokeMethod('stopShadowServer');
  }

  @override
  Future<dynamic> startShadowServer() async {
    return methodChannel.invokeMethod('startShadowServer');
  }

  @override
  Future<dynamic> getDefaultAudioInputDevice() async {
    return methodChannel.invokeMethod('getDefaultAudioInputDevice');
  }

  @override
  Future<dynamic> setAudioInputDevice(String deviceName) async {
    return methodChannel.invokeMethod('setAudioInputDevice', {'deviceName': deviceName});
  }

  @override
  Future<dynamic> getAudioInputDeviceList() async {
    return methodChannel.invokeMethod('getAudioInputDeviceList');
  }

  @override
  Future<void> deleteFileIfExists(String fileName) async {
    return methodChannel.invokeMethod('deleteFileIfExists', {'fileName': fileName});
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
  Future<void> restartApp() async {
    return methodChannel.invokeMethod('restartApp');
  }

  @override
  Future<Map<String, dynamic>> getAllScreenPermissionStatuses() async {
    final result = await methodChannel.invokeMethod('getAllScreenPermissionStatuses');
    if (result is Map<dynamic, dynamic>) {
      return result.cast<String, dynamic>();
    }
    return {};
  }
  // Future<Map<String, dynamic>> getAllScreenPermissionStatuses() async {
  //   final result = await methodChannel.invokeMethod<Map<String, dynamic>>('getAllScreenPermissionStatuses');
  //   return result ?? {};
  // }

  @override
  Future<bool> isMicPermissionGranted() async {
    final result = await methodChannel.invokeMethod<bool>('isMicPermissionGranted');
    return result ?? false;
  }

  @override
  Future<bool> isScreenPermissionGranted() async {
    final result = await methodChannel.invokeMethod<bool>('isScreenPermissionGranted');
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
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  //SystemAudio
  @override
  Future startSystemAudioRecordingWithDefault() async {
    return methodChannel.invokeMethod('startSystemAudioRecordingWithDefault');
  }

  @override
  Future startSystemAudioRecordingWithConfig([Map<String, dynamic>? config]) async {
    return methodChannel.invokeMethod('startSystemAudioRecordingWithConfig', config);
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
  Future<void> startMicRecordingWithConfig([Map<String, dynamic>? config]) async {
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
    return methodChannel.invokeMethod('startSystemAndMicAudioRecordingWithDefault');
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
    return methodChannel.invokeMethod('startSystemAndMicAudioRecordingWithConfig', arguments);
  }

  @override
  Future<void> stopRecordingMicAndSystemAudio() async {
    return methodChannel.invokeMethod('stopSystemAndMicAudioRecording');
  }
}
