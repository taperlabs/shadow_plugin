import 'package:flutter_test/flutter_test.dart';
import 'package:shadow/shadow.dart';
import 'package:shadow/shadow_platform_interface.dart';
import 'package:shadow/shadow_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockShadowPlatform with MockPlatformInterfaceMixin implements ShadowPlatform {
  @override
  Stream<dynamic> get microphoneEvents => Stream.empty();

  @override
  Stream<dynamic> get screenCaptureEvents => Stream.empty();

  @override
  Stream<dynamic> get microphonePermissionEvents => Stream.empty();

  @override
  Stream<dynamic> get screenRecordingPermissionEvents => Stream.empty();

  @override
  Stream<dynamic> get nudgeEvents => Stream.empty();

  @override
  Stream<dynamic> get micAudioLevelEvents => Stream.empty();

  @override
  Stream<dynamic> get screenCaptureKitBugEvents => Stream.empty();

  @override
  Future<void> restartApp() async {}

  @override
  Future<dynamic> getDefaultAudioInputDevice() async {}

  @override
  Future<dynamic> setAudioInputDevice(String deviceName) async {}

  @override
  Future<dynamic> getAudioInputDeviceList() async {}

  @override
  Future<void> deleteFileIfExists(String fileName) async {}

  @override
  Future<void> openMicSystemSetting() async {}

  @override
  Future<void> openScreenSystemSetting() async {}

  @override
  Future<Map<String, dynamic>> getAllScreenPermissionStatuses() async {
    return {}; // Mocked to always return an empty map for this example
  }

  @override
  Future<bool> isMicPermissionGranted() async {
    return true; // Mocked to always return true for this example
  }

  @override
  Future<bool> isScreenPermissionGranted() async {
    return true; // Mocked to always return true for this example
  }

  @override
  Future<void> requestScreenPermission() async {}

  @override
  Future<void> requestMicPermission() async {}

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  //SystemAudio
  @override
  Future<void> startSystemAudioRecordingWithDefault() async {}

  @override
  Future<void> startSystemAudioRecordingWithConfig([Map<String, dynamic>? config]) async {}

  //ScreenCapture
  @override
  Future<void> startScreenCapture() async {}

  @override
  Future<void> stopScreenCapture() async {}

  //Microphone
  @override
  Future<void> startMicRecordingWithDefault() async {}

  @override
  Future<void> startMicRecordingWithConfig([Map<String, dynamic>? config]) async {}

  @override
  Future<void> startMicRecording() async {}

  @override
  Future<void> stopMicRecording() async {}

  @override
  Future<void> startSystemAndMicAudioRecordingWithDefault() async {}

  @override
  Future<void> startSystemAndMicAudioRecordingWithConfig({Map<String, dynamic>? systemAudioConfig, Map<String, dynamic>? micConfig}) async {}

  @override
  Future<void> stopRecordingMicAndSystemAudio() async {}
}

void main() {
  final ShadowPlatform initialPlatform = ShadowPlatform.instance;

  test('$MethodChannelShadow is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelShadow>());
  });

  test('getPlatformVersion', () async {
    Shadow shadowPlugin = Shadow();
    MockShadowPlatform fakePlatform = MockShadowPlatform();
    ShadowPlatform.instance = fakePlatform;

    expect(await shadowPlugin.getPlatformVersion(), '42');
  });
}
