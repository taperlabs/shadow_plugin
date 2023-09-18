import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shadow/shadow.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  int _counter = 0;
  final _shadowPlugin = Shadow();
  StreamSubscription<dynamic>? microphoneEventSubscription;
  StreamSubscription<dynamic>? screenCaptureEventSubscription;
  StreamSubscription<dynamic>? eventSubscription;

  final micConfig = {
    'fileName': 'FlutterCustomMicrophone.m4a',
    'format': 'mpeg4AAC',
    'channels': 'stereo',
    'sampleRate': 'rate48K'
  };

  final systemAudioConfig = {
    'fileName': 'FlutterCustomSystemAudio.m4a',
    'format': 'mpeg4AAC',
    'channels': 'stereo',
    'sampleRate': 'rate48K'
  };

  // static const micEventChannel = EventChannel('phoenixMicEventChannel');
  // static const eventChannel = EventChannel('phoenixEventChannel');

  @override
  void initState() {
    super.initState();
    // initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = await _shadowPlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  //Microphone
  Future startMicRecording() async {
    try {
      // await _shadowPlugin.startMicRecordingWithConfig(micConfig);
      await _shadowPlugin.startMicRecordingWithDefault();
      // await _shadowPlugin.startMicRecording();
      // print(result);
      print("startMicRecording called successfully ✅");
      microphoneEventSubscription =
          _shadowPlugin.microphoneEvents.listen((event) {
        print("마이크 오디오 이벤트 스트림 테스트입니다");
        print(event);

        if (event['type'] == 'screenRecordingStatus') {
          setState(() {
            _counter = event['elapsedTime'];
          });
        }
      }, onError: (error) {
        print(error);
      });
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future stopMicRecording() async {
    try {
      await _shadowPlugin.stopMicRecording();
      microphoneEventSubscription?.cancel();

      // print(result);
      print("stopMicRecording called successfully");
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future startSystemAudioOnlyCapture() async {
    try {
      // final result = await _shadowPlugin.startSystemAudioRecordingWithConfig(systemAudioConfig);
      await _shadowPlugin.startSystemAudioRecordingWithDefault();

      screenCaptureEventSubscription =
          _shadowPlugin.screenCaptureEvents.listen((event) {
        print("시스템 오디오 이벤트 스트림 테스트입니다");
        print(event);

        if (event['type'] == 'screenRecordingStatus') {
          setState(() {
            _counter = event['elapsedTime'];
          });
        }
      }, onError: (error) {
        print(error);
      });
      print("startSystemAudioOnlyCapture called successfully");
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future stopSystemAudioOnlyCapture() async {
    try {
      // final result = await _shadowPlugin.stopSystemAudioRecording();
      await _shadowPlugin.stopScreenCapture();
      screenCaptureEventSubscription?.cancel();
      print("stopSystemAudioOnlyCapture called successfully");
    } on PlatformException catch (e) {
      print(e);
    }
  }

  //Screen Capture
  Future startScreenCapture() async {
    try {
      // final result = await _shadowPlugin.startScreenCapture();

      // await _shadowPlugin
      // .startSystemAudioRecordingWithConfig(systemAudioConfig);
      // await _shadowPlugin.startSystemAudioRecordingWithDefault();

      // await _shadowPlugin.startSystemAndMicAudioRecordingWithConfig()

      await _shadowPlugin.startSystemAndMicAudioRecordingWithConfig(
          systemAudioConfig: systemAudioConfig, micConfig: micConfig);

      // await _shadowPlugin.startSystemAndMicAudioRecordingWithDefault();

      print('startScreenCapture called successfully');

      screenCaptureEventSubscription =
          _shadowPlugin.screenCaptureEvents.listen((event) {
        print("시스템 오디오 이벤트 스트림 테스트입니다");
        print(event);

        if (event['type'] == 'screenRecordingStatus') {
          setState(() {
            _counter = event['elapsedTime'];
          });
        }
      }, onError: (error) {
        print(error);
      });
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future stopScreenCapture() async {
    try {
      // final result = await _shadowPlugin.stopScreenCapture();
      await _shadowPlugin.stopRecordingMicAndSystemAudio();
      // await _shadowPlugin.stopScreenCapture();
      screenCaptureEventSubscription?.cancel();

      print('stopScreenCapture called successfully');
    } on PlatformException catch (e) {
      print(e);
    }
  }

//--------------------------------------@@@ 이하 테스트 코드 @@@--------------------------------------//
  Future startRecording(
      Future Function() startFunction, Stream<dynamic> eventStream) async {
    try {
      await startFunction();
      print("${startFunction.toString()} called successfully ✅");
      eventSubscription = eventStream.listen((event) {
        handleEvent(event);
      }, onError: (error) {
        print(error);
      });
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future stopRecording(Future Function() stopFunction,
      StreamSubscription<dynamic>? eventSubscription) async {
    try {
      await stopFunction();
      eventSubscription?.cancel();
      print("${stopFunction.toString()} called successfully");
    } on PlatformException catch (e) {
      print(e);
    }
  }

  void handleEvent(dynamic event) {
    print(event);
    if (event['type'] == 'screenRecordingStatus') {
      setState(() {
        _counter = event['elapsedTime'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Shadow Plugin Example App'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('Timer ⬇️ ⏰:'),
              Text('$_counter',
                  style: Theme.of(context).textTheme.headlineMedium),
              CustomButton(
                  "ScreenCapture 버튼",
                  () => startRecording(
                      _shadowPlugin.startSystemAndMicAudioRecordingWithDefault,
                      _shadowPlugin.screenCaptureEvents)),
              CustomButton(
                  "Stop ScreenCapture 버튼",
                  () => stopRecording(
                      _shadowPlugin.stopRecordingMicAndSystemAudio,
                      screenCaptureEventSubscription)),
              CustomButton(
                  "Start Microphone Recording 버튼",
                  () => startRecording(
                      _shadowPlugin.startMicRecordingWithDefault,
                      _shadowPlugin.microphoneEvents)),
              CustomButton(
                  "Stop Microphone Recording 버튼",
                  () => stopRecording(_shadowPlugin.stopMicRecording,
                      microphoneEventSubscription)),
              CustomButton(
                  "Start System Audio Only Capturing",
                  () => startRecording(
                      _shadowPlugin.startSystemAudioRecordingWithDefault,
                      _shadowPlugin.screenCaptureEvents)),
              CustomButton(
                  "Stop System Audio Only Capturing",
                  () => stopRecording(_shadowPlugin.stopScreenCapture,
                      screenCaptureEventSubscription)),
              // ... [rest of the buttons]
            ],
          ),
        ),
      ),
    );
  }

//  Text('Running on: $_platformVersion\n'),
  // @override
  // Widget build(BuildContext context) {
  //   return MaterialApp(
  //     home: Scaffold(
  //       appBar: AppBar(
  //         title: const Text('Shadow Plugin Example App'),
  //       ),
  //       body: Center(
  //         child: Column(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           children: <Widget>[
  //             const Text(
  //               'Timer ⬇️ ⏰:',
  //             ),
  //             Text(
  //               '$_counter',
  //               style: Theme.of(context).textTheme.headlineMedium,
  //             ),
  //             TextButton(
  //               onPressed: () {
  //                 startScreenCapture();
  //               },
  //               child: const Text('ScreenCapture 버튼'),
  //             ),
  //             TextButton(
  //               onPressed: () {
  //                 stopScreenCapture();
  //               },
  //               child: const Text('Stop ScreenCapture 버튼'),
  //             ),
  //             TextButton(
  //               onPressed: () {
  //                 startMicRecording();
  //               },
  //               child: const Text('Start Microphone Recording 버튼'),
  //             ),
  //             TextButton(
  //               onPressed: () {
  //                 stopMicRecording();
  //               },
  //               child: const Text('Stop Microphone Recording 버튼'),
  //             ),
  //             TextButton(
  //               onPressed: () {
  //                 startSystemAudioOnlyCapture();
  //               },
  //               child: const Text('Start System Audio Only Capturing'),
  //             ),
  //             TextButton(
  //               onPressed: () {
  //                 stopSystemAudioOnlyCapture();
  //               },
  //               child: const Text('Stop System Audio Only Capturing'),
  //             ),
  //             TextButton(
  //               onPressed: () {
  //                 // getFilePath("FlutterSystemAudio.m4a");
  //               },
  //               child: const Text('Start System Audio + Mic Capturing'),
  //             ),
  //             TextButton(
  //               onPressed: () {
  //                 // getFilePath("FlutterSystemAudio.m4a");
  //               },
  //               child: const Text('Stop System Audio + Mic Capturing'),
  //             ),
  //             // TextButton(
  //             //   onPressed: () {
  //             //     // getFilePath("FlutterSystemAudio.m4a");
  //             //   },
  //             //   child: const Text('Get File Path 버튼'),
  //             // ),
  //             // TextButton(
  //             //   onPressed: () {},
  //             //   child: const Text('FileIO 버튼'),
  //             // ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
}

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  CustomButton(this.label, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
