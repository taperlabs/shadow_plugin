import 'package:flutter_test/flutter_test.dart';
import 'package:shadow/shadow.dart';
import 'package:shadow/shadow_platform_interface.dart';
import 'package:shadow/shadow_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockShadowPlatform
    with MockPlatformInterfaceMixin
    implements ShadowPlatform {
  @override
  Stream<dynamic> get microphoneEvents => Stream.empty();

  @override
  Stream<dynamic> get screenCaptureEvents => Stream.empty();

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  //SystemAudio
  @override
  Future<void> startSystemAudioRecordingWithDefault() async {}

  @override
  Future<void> startSystemAudioRecordingWithConfig(
      [Map<String, dynamic>? config]) async {}

  //ScreenCapture
  @override
  Future<void> startScreenCapture() async {}

  @override
  Future<void> stopScreenCapture() async {}

  //Microphone
  @override
  Future<void> startMicRecordingWithDefault() async {}

  @override
  Future<void> startMicRecordingWithConfig(
      [Map<String, dynamic>? config]) async {}

  @override
  Future<void> startMicRecording() async {}

  @override
  Future<void> stopMicRecording() async {}

  @override
  Future<void> startSystemAndMicAudioRecordingWithDefault() async {}

  @override
  Future<void> startSystemAndMicAudioRecordingWithConfig(
      {Map<String, dynamic>? systemAudioConfig,
      Map<String, dynamic>? micConfig}) async {}

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
