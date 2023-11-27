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
  String _micPermissionStatus = "Mic Permission Value";
  bool _isScreenRecordingPermissionGranted = false;
  final _shadowPlugin = Shadow();

  //Stream Subscriptions
  StreamSubscription<dynamic>? microphoneEventSubscription;
  StreamSubscription<dynamic>? screenCaptureEventSubscription;
  StreamSubscription<dynamic>? eventSubscription;
  StreamSubscription<dynamic>? microphonePermissionSubscription;
  StreamSubscription<dynamic>? screenRecordingPermissionSubscription;
  StreamSubscription<dynamic>? nudgeSubscription;

//Configs
  final micConfig = {'fileName': 'FlutterCustomMicrophone.m4a', 'format': 'mpeg4AAC', 'channels': 'stereo', 'sampleRate': 'rate48K'};

  final systemAudioConfig = {'fileName': 'FlutterCustomSystemAudio.m4a', 'format': 'mpeg4AAC', 'channels': 'stereo', 'sampleRate': 'rate48K'};

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
      platformVersion = await _shadowPlugin.getPlatformVersion() ?? 'Unknown platform version';
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

  Future deleteFile(String fileName) async {
    await _shadowPlugin.deleteFileIfExists(fileName);
  }

  //Microphone
  Future startMicRecording() async {
    try {
      // await _shadowPlugin.startMicRecordingWithConfig(micConfig);
      await _shadowPlugin.startMicRecordingWithDefault();
      // await _shadowPlugin.startMicRecording();
      // print(result);
      print("startMicRecording called successfully ✅");
      microphoneEventSubscription = _shadowPlugin.microphoneEvents.listen((event) {
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

      screenCaptureEventSubscription = _shadowPlugin.screenCaptureEvents.listen((event) {
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

      await _shadowPlugin.startSystemAndMicAudioRecordingWithConfig(systemAudioConfig: systemAudioConfig, micConfig: micConfig);

      // await _shadowPlugin.startSystemAndMicAudioRecordingWithDefault();

      print('startScreenCapture called successfully');

      screenCaptureEventSubscription = _shadowPlugin.screenCaptureEvents.listen((event) {
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
  Future requestPermission(Future Function() requestFunction) async {
    try {
      await requestFunction();
      print("requestPermission called successfully ✅");
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future requestMicPermissionWithEvents(Future Function() requestFunction, Stream<dynamic> eventStream) async {
    try {
      microphonePermissionSubscription = eventStream.listen((event) {
        print("Microphone Permission 🎤 Event입니다 $event");
        setState(() {
          _micPermissionStatus = event;
        });
      }, onError: (error) {
        print(error);
      });
      requestFunction();

      print("requestPermission called successfully ✅");
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future requestScreenRecordingPermissionWithEvents(Future Function() requestFunction, Stream<dynamic> eventStream) async {
    try {
      screenCaptureEventSubscription = eventStream.listen((event) {
        print("Screen Recording 🎥 Event입니다z $event");
        setState(() {
          _isScreenRecordingPermissionGranted = event;
        });
      }, onError: (error) {
        print(error);
      });
      requestFunction();

      print("requestPermission called successfully ✅");
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future stopRequestingPermission(StreamSubscription<dynamic>? event) async {
    try {
      event?.cancel();
      print("stopRequestingPermission called successfully ✅");
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future startRecording(Future Function() startFunction, Stream<dynamic> eventStream) async {
    // if (_isRecordingInProgress) {
    //   print("Recording is already in progress. Ignoring the start command.");
    //   return;
    // }

    // _isRecordingInProgress = true;

    try {
      await startFunction();
      print("${startFunction.toString()} called successfully ✅");
      screenCaptureEventSubscription = eventStream.listen((event) {
        handleEvent(event);
      }, onError: (error) {
        print(error);
      });
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future stopRecording(Future Function() stopFunction, StreamSubscription<dynamic>? eventSubscription) async {
    try {
      await stopFunction();
      eventSubscription?.cancel();
      print("${stopFunction.toString()} called successfully");
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future startNudging() async {
    try {
      nudgeSubscription = _shadowPlugin.nudgeEvents.listen(
        (event) {
          print("Nudge Event입니다 $event");
        },
        onError: (error) {
          print(error);
        },
      );
      print("startNudging called successfully ✅");
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future cancelNudging() async {
    try {
      nudgeSubscription?.cancel();
      print("cancelNudging called successfully ✅");
    } on PlatformException catch (e) {
      print(e);
    }
  }

  void handleEvent(dynamic event) {
    print(event);
    if (event['type'] == 'screenRecordingStatus' || event['type'] == 'microphoneStatus') {
      setState(() {
        _counter = event['elapsedTime'];
      });
    }
  }

  Future<void> checkMicPermission() async {
    bool granted = await _shadowPlugin.isMicPermissionGranted();
    print("Microphone Permission: $granted");
  }

  Future<void> checkScreenPermission() async {
    bool granted = await _shadowPlugin.isScreenPermissionGranted();
    print("Screen Permission: $granted");
  }

  Future<void> getAllScreenRecordingPermissionStatuses() async {
    Map<String, dynamic> result = await _shadowPlugin.getAllScreenPermissionStatuses();
    print("getAllScreenRecordingPermissionStatuses: $result");
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
              Text('$_counter', style: Theme.of(context).textTheme.headlineMedium),
              Text('$_micPermissionStatus', style: Theme.of(context).textTheme.headlineMedium),
              Text('$_isScreenRecordingPermissionGranted', style: Theme.of(context).textTheme.headlineMedium),
              CustomButton(
                  "Request Microhpone Permission",
                  () => requestMicPermissionWithEvents(
                        _shadowPlugin.requestMicPermission,
                        _shadowPlugin.microphonePermissionEvents,
                      )),
              CustomButton(
                  "Request Screen Permission",
                  () => requestScreenRecordingPermissionWithEvents(
                        _shadowPlugin.requestScreenPermission,
                        _shadowPlugin.screenRecordingPermissionEvents,
                      )),
              CustomButton(
                "Stop Microphone Permission Request Stream 버튼",
                () => stopRequestingPermission(microphonePermissionSubscription),
              ),
              CustomButton(
                "Stop Screen Recording Permission Request Stream 버튼",
                () => stopRequestingPermission(screenCaptureEventSubscription),
              ),
              CustomButton(
                "Open Mic System Setting 버튼",
                () => _shadowPlugin.openMicSystemSetting(),
              ),
              CustomButton(
                "Open Screen Recording System Setting 버튼",
                () => _shadowPlugin.openScreenSystemSetting(),
              ),
              CustomButton(
                "Is Microphone Permission Granted 버튼",
                () => checkMicPermission(),
              ),
              CustomButton(
                "Is Screen Recording Permission Granted 버튼",
                () => checkScreenPermission(),
              ),
              CustomButton("ScreenCapture 버튼",
                  () => startRecording(_shadowPlugin.startSystemAndMicAudioRecordingWithDefault, _shadowPlugin.screenCaptureEvents)),
              // () => startScreenCapture()),
              CustomButton(
                  "Stop ScreenCapture 버튼", () => stopRecording(_shadowPlugin.stopRecordingMicAndSystemAudio, screenCaptureEventSubscription)),
              CustomButton(
                  "Start Microphone Recording 버튼", () => startRecording(_shadowPlugin.startMicRecordingWithDefault, _shadowPlugin.microphoneEvents)),
              CustomButton("Stop Microphone Recording 버튼", () => stopRecording(_shadowPlugin.stopMicRecording, microphoneEventSubscription)),
              CustomButton("Start System Audio Only Capturing",
                  () => startRecording(_shadowPlugin.startSystemAudioRecordingWithDefault, _shadowPlugin.screenCaptureEvents)),
              CustomButton("Stop System Audio Only Capturing", () => stopRecording(_shadowPlugin.stopScreenCapture, screenCaptureEventSubscription)),
              CustomButton(
                "Delete File 버튼",
                () => deleteFile("FlutterSystemAudio.m4a"),
              ),
              CustomButton(
                "Relaunch 버튼",
                () => _shadowPlugin.restartApp(),
              ),
              CustomButton(
                "start Nudging Button",
                () => getAllScreenRecordingPermissionStatuses(),
              ),
              CustomButton(
                "Start Nudging",
                () => startNudging(),
              ),
              CustomButton(
                "Cancel Nudging",
                () => cancelNudging(),
              )
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
