import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shadow/shadow.dart';
import 'package:shadow/shadow_platform_interface.dart';

void main() {
  runApp(const MyApp());
}

enum WindowState {
  closed,
  preListening,
  listening,
}

class LsofEntry {
  final String appName;
  final String port;
  final String pid;
  final DateTime startTime;

  LsofEntry(this.appName, this.port, this.pid, this.startTime);

  Map<String, dynamic> toDictionary() {
    return {'appName': appName, 'port': port, 'pid': pid, 'startTime': startTime.toIso8601String()};
  }

  bool get isConnectionOlderThanNSeconds {
    return DateTime.now().difference(startTime).inSeconds >= 2;
  }
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
  String isInMeeting = "미팅 ❌";
  final _shadowPlugin = Shadow();

  //Stream Subscriptions
  StreamSubscription<dynamic>? microphoneEventSubscription;
  StreamSubscription<dynamic>? screenCaptureEventSubscription;
  StreamSubscription<dynamic>? eventSubscription;
  StreamSubscription<dynamic>? microphonePermissionSubscription;
  StreamSubscription<dynamic>? screenRecordingPermissionSubscription;
  StreamSubscription<dynamic>? nudgeSubscription;
  StreamSubscription<dynamic>? micAudioLevelSubscription;

  StreamSubscription<dynamic>? multiWindowEventStreamSubscription;
  StreamSubscription<dynamic>? multiWindowStatusEventStreamSubscription;

  String dropdownValue = '';

  List<String> audioInputDeviceList = [];

  int windowState = 0;

//Configs
  final micConfig = {
    'fileName': 'FlutterCustomMicrophone.m4a',
    'format': 'mpeg4AAC',
    'channels': 'stereo',
    'sampleRate': 'rate48K',
    'filePath': 'ApplicationSupportDirectory'
  };

  final systemAudioConfig = {
    'fileName': 'FlutterCustomSystemAudio.m4a',
    'format': 'mpeg4AAC',
    'channels': 'stereo',
    'sampleRate': 'rate48K',
    'filePath': 'ApplicationSupportDirectory'
  };

  Timer? timer;
  bool _isInMeeting = false;
  final Map<String, LsofEntry> entries = {};
  final List<String> whitelistAppNames = [
    "Around",
    "Discord",
    "zoom.us",
    "Slack",
    "GoogleChromeHelper",
    "com.apple",
    "MicrosoftEdgeHelper",
    "ArcHelper",
    "plugin-co", //firefox
  ];

  List tempProcessList = [];
  List processList = [];
  Process? process;

  late HotKey _hotKey;
  bool isRecording = false;
  String? currentUuid;

  @override
  void initState() {
    super.initState();
    _setupHotkey();
    getAudioInputDeviceList();
    _setupMultiWindowStatusEventStream();

    // initPlatformState();
  }

  @override
  void dispose() {
    print("dispose called !!!!@!@!@!@");
    _shadowPlugin.stopShadowServer();
    multiWindowStatusEventStreamSubscription?.cancel();
    hotKeyManager.unregister(_hotKey);
    super.dispose();
  }

  setListeningConfig() {
    final listeningConfig = {
      'userName': "Phoenix",
      'sysFileName': "systemFileName",
      'micFileName': "micFileName",
      'convUuid': "convUuid",
    };
  }

  void _setupMultiWindowStatusEventStream() {
    // Cancel the previous subscription if it exists
    if (multiWindowStatusEventStreamSubscription != null) {
      multiWindowStatusEventStreamSubscription?.cancel();
    }

    // Set up a new subscription
    multiWindowStatusEventStreamSubscription = _shadowPlugin.multiWindowStatusEvents.listen((event) {
      print('Flutter-side: $event');

      // Parse the event
      final isRecording = event['isRecording'];
      final windowStateString = event['windowState'];
      WindowState windowState;

      print('isRecording: $isRecording, windowStateString: $windowStateString');

      // Map the string to the enum
      switch (windowStateString) {
        case 'closed':
          windowState = WindowState.closed;
          break;
        case 'preListening':
          windowState = WindowState.preListening;
          break;
        case 'listening':
          windowState = WindowState.listening;
          break;
        default:
          throw Exception('Unknown window state: $windowStateString');
      }

      // Handle the event using the enum
      print('WindowState: $windowState, isRecording: $isRecording');

      // Additional handling based on windowState and isRecording
    }, onError: (error) {
      print('Error from event stream: $error');
    });
  }

  void _setupNewEventStream() {
    // Cancel the previous subscription if it exists
    // multiWindowEventStreamSubscription?.cancel();

    // Set up a new subscription
    multiWindowEventStreamSubscription = _shadowPlugin.multiWindowEvents.listen((event) {
      print('Flutter-side: $event');

      if (event != null && event['windowState'] != null) {
        setState(() {
          windowState = event['windowState'];
        });
      }

      if (event != null && event['isRecording'] == true) {
        setState(() {
          isRecording = event['isRecording'];
        });
      } else {
        setState(() {
          isRecording = false;
          currentUuid = null;
        });
        multiWindowEventStreamSubscription?.cancel();
        multiWindowEventStreamSubscription = null;
      }
      // Handle the event
    }, onError: (error) {
      print('Error from event stream: $error');
    });
  }

  void _setupHotkey() async {
    _hotKey = HotKey(
      key: PhysicalKeyboardKey.keyS,
      modifiers: [HotKeyModifier.control, HotKeyModifier.meta],
      scope: HotKeyScope.system,
    );

    await hotKeyManager.register(
      _hotKey,
      keyDownHandler: (hotKey) async {
        print('Hotkey pressed: ${hotKey.identifier}, ${hotKey.physicalKey.debugName}, ${hotKey.scope} ${hotKey.modifiers}');
        final key = hotKey.physicalKey.debugName!;
        final modifiers = hotKey.modifiers!.map((modifier) => modifier.toString()).toList();
        final listeningConfig = {
          'userName': "Phoenix",
          'micFileName': "hotkey",
          'sysFileName': "hotkey",
          'isAudioSaveOn': false,
        };

        await _shadowPlugin.createNewWindow(listeningConfig: listeningConfig);
        ;
        //Send event to Swift
      },
    );
  }

  runStream() async {
    // Dart uses Futures and Streams for asynchronous operations
    var newProcess = await Process.start('/usr/bin/log', [
      'stream',
      '--predicate',
      "subsystem == 'com.apple.controlcenter' AND (eventMessage CONTAINS 'Recent activity attributions changed to' OR eventMessage CONTAINS 'Active activity attributions changed to')"
    ]);

    process = newProcess;

    // Setting up a subscription to listen to the output
    newProcess.stdout.transform(utf8.decoder).listen((data) {
      print(data); // Printing the data received
    }).onError((error) {
      print('Error occurred: $error');
    });

    // You can also handle stderr in a similar way if needed
  }

  void stopStream() {
    process?.kill();
  }

  Future<void> _createNewWindow() async {
    // try {1

    final listeningConfig = {
      'userName': "Phoenix",
      'micFileName': "ggggggggg",
      'sysFileName': "ggggggggg",
    };

    await _shadowPlugin.createNewWindow(listeningConfig: listeningConfig);
    if (multiWindowEventStreamSubscription == null) {
      _setupNewEventStream();
    }
  }

  Future<void> _startListening() async {
    final listeningConfig = {
      'userName': "Phoenix",
      'micFileName': "ggggggggg",
      'sysFileName': "ggggggggg",
    };

    await _shadowPlugin.startListening(listeningConfig: listeningConfig);
    if (multiWindowEventStreamSubscription == null) {
      _setupNewEventStream();
    }
  }

  Future<void> _stopListening() async {
    await _shadowPlugin.stopListening();
  }

  finalLsofTest() async {
    Timer test = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        ProcessResult results = await Process.run('lsof', ['-i', 'UDP:40000-69999']);
        var lines = results.stdout.split('\n').skip(1);
        var pattern = RegExp(r'UDP \*(?!:).*[^->]$');

        var filteredProcesses =
            lines.where((line) => line.trim().isNotEmpty && !pattern.hasMatch(line) && !line.contains('->') && !line.contains('*')).map(
          (line) {
            print("Line - $line");
            var item = line.replaceAll(RegExp(r'\s{2,}'), ' ').split(' ');
            return {
              'command': item.first.replaceAll('\\x20', ''),
              'pid': item[1],
              'port': item.last.split(':').last,
              'firstRunAt': DateTime.now().millisecondsSinceEpoch,
            };
          },
        ).toList();

        // 필터링 된 라인이 있으면 임시 프로세스 목록에 추가
        tempProcessList.addAll(filteredProcesses.where((newProcess) => !tempProcessList.any((process) => process['pid'] == newProcess['pid'])));

        // 임시 프로세스 리스트가 없으면 종료
        if (tempProcessList.isEmpty) return;

        // 임시 프로세스 목록에서 5초 이상 머무른 프로세스 체크
        var addedProcesses = tempProcessList.where((tempProcess) {
          if ((tempProcess['command'] == 'Microsoft' || tempProcess['command'] == 'Google') &&
              DateTime.now().millisecondsSinceEpoch - tempProcess['firstRunAt'] < 5000) return false;
          return !processList.any((process) => process['pid'] == tempProcess['pid']);
        }).toList();

        // 프로세스 목록에 추가하며 START 넛지 주기
        if (addedProcesses.isNotEmpty) {
          processList.addAll(addedProcesses);
          print('Added to processList: $addedProcesses');
        }

        // 종료된 프로세스 체크
        tempProcessList.removeWhere((tempProcess) => !filteredProcesses.any((process) => process['pid'] == tempProcess['pid']));
        var removedProcesses = processList.where((process) => !tempProcessList.any((tempProcess) => tempProcess['pid'] == process['pid'])).toList();

        // 프로세스 목록에서 제거하며 END 넛지 주기
        if (removedProcesses.isNotEmpty) {
          processList.removeWhere((process) => removedProcesses.contains(process));
          print('Removed from processList: $removedProcesses');
        }
      },
    );
  }

  Future<String> runLsofCommand() async {
    final result = await Process.run('lsof', ['-i', 'UDP:40000-69999', '+c', '30']);
    return result.stdout as String;
  }

  List<LsofEntry> parseLsofOutput(String output) {
    final lines = output.split('\n').skip(1);
    // final pattern = RegExp(r'UDP (\*|\d{1,3}(\.\d{1,3}){3}):([4-6]\d{4,5})(?!.*->)');
    var pattern = RegExp(r'UDP \*(?!:).*[^->]$');
    final foundPIDs = <String>{};

    return lines
        .map((line) {
          final words = line.split(' ').where((str) => str.isNotEmpty).toList();
          if (words.isNotEmpty) {
            final matchedLine = pattern.firstMatch(line);

            if (matchedLine != null) {
              final appName = words[0];
              final appNameWithoutSpaces = appName.replaceAll('\\x20', '');
              print(appNameWithoutSpaces);

              final portPattern = RegExp(r':(\d+)$');
              final portMatch = portPattern.firstMatch(words.last);
              final bool isAppNameInWhitelist = whitelistAppNames.any((whitelistAppName) => appNameWithoutSpaces.startsWith(whitelistAppName));

              if (portMatch != null && isAppNameInWhitelist) {
                final pid = words[1];
                foundPIDs.add(pid);

                entries[pid] = entries.putIfAbsent(pid, () => LsofEntry(words[0], portMatch.group(1)!, pid, DateTime.now()));

                return LsofEntry(words[0], portMatch.group(1)!, words[1], DateTime.now());
              }
            }
          }
        })
        .where((item) => item != null)
        .toList()
        .cast<LsofEntry>();
  }

  void updateEntries(List<LsofEntry> parsedLines) {
    final foundPIDs = parsedLines.map((entry) => entry.pid).toSet();
    print("foundPID, $foundPIDs");
    entries.removeWhere((key, value) => !foundPIDs.contains(key));
  }

  void updateMeetingStatus() {
    if (entries.isEmpty) {
      print("No entries found");
      if (_isInMeeting) {
        print("You were in a meeting but now you are not");
        _isInMeeting = false;
      }
      setState(() {
        isInMeeting = "미팅 ❌";
      });
    }

    if (entries.isNotEmpty) {
      entries.values.forEach((entry) {
        if (entry.isConnectionOlderThanNSeconds) {
          print("Meeting is longer than 5 seconds");
          _isInMeeting = true;
          setState(() {
            isInMeeting = "미팅 ✅";
          });
        }
      });
    }
  }

  detectInMeetingSession2() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final output = await runLsofCommand();
      final parsedLines = parseLsofOutput(output);
      updateEntries(parsedLines);
      updateMeetingStatus();
      print(parsedLines.map((entry) => entry.toDictionary()).toList());
    });
  }

  detectInMeetingSession() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final result = await Process.run('lsof', ['-i', 'UDP:40000-69999']);
      final output = result.stdout as String;

      final lines = output.split('\n').skip(1);

      final pattern = RegExp(r'UDP (\*|\d{1,3}(\.\d{1,3}){3}):([4-6]\d{4,5})(?!.*->)');
      final foundPIDs = <String>{};

      final parsedLines = lines
          .map((line) {
            final words = line.split(' ').where((str) => str.isNotEmpty).toList();

            if (words.isNotEmpty) {
              final matchedLine = pattern.firstMatch(line);

              if (matchedLine != null) {
                final appName = words[0];
                final portPattern = RegExp(r':(\d+)$');
                final portMatch = portPattern.firstMatch(words.last);

                if (portMatch != null && whitelistAppNames.contains(appName)) {
                  final pid = words[1];
                  foundPIDs.add(pid);

                  entries[pid] = entries.putIfAbsent(pid, () => LsofEntry(words[0], portMatch.group(1)!, pid, DateTime.now()));

                  return LsofEntry(words[0], portMatch.group(1)!, words[1], DateTime.now());
                }
              }
            }
          })
          .where((item) => item != null)
          .toList()
          .cast<LsofEntry>();

      entries.removeWhere((key, value) => !foundPIDs.contains(key));

      if (entries.isEmpty) {
        print("No entries found");
        if (_isInMeeting) {
          print("You were in a meeting but now you are not");
          _isInMeeting = false;
        }
        setState(() {
          isInMeeting = "미팅 ❌";
        });
      }

      if (entries.isNotEmpty) {
        entries.values.forEach((entry) {
          if (entry.isConnectionOlderThanNSeconds) {
            print("Meeting is longer than 5 seconds");
            _isInMeeting = true;
            setState(() {
              isInMeeting = "미팅 ✅";
            });
          }
        });
      }

      print(parsedLines.map((entry) => entry.toDictionary()).toList());
    });
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
      await _shadowPlugin.startMicRecordingWithConfig(micConfig);
      // await _shadowPlugin.startMicRecordingWithDefault();
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
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        await startFunction();
        print("${startFunction.toString()} called successfully ✅");
        microphoneEventSubscription = eventStream.listen((event) {
          handleEvent(event);
        }, onError: (error) {
          print(error);
        });

        micAudioLevelSubscription = _shadowPlugin.micAudioLevelEvents.listen((event) {
          print("Mic Audio Level Event입니다 $event");
          handleEvent(event);
        }, onError: (error) {
          print(error);
        });
      } on PlatformException catch (e) {
        print(e);
      }
    });
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
        (event) async {
          print("Nudge Event입니다 $event");
          if (event['isInMeeting']) {
            // await startMicRecording();
            final listeningConfig = {
              'userName': "Phoenix",
              'micFileName': "ggggggggg",
              'systemFileName': "ggggggggg",
            };
            _shadowPlugin.startListening(listeningConfig: listeningConfig);

            setState(() {
              isInMeeting = "미팅 ✅";
            });
          } else {
            _shadowPlugin.stopListening();

            setState(() {
              isInMeeting = "미팅 ❌";
            });
          }
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
    // Check if the event is a Map, which indicates a recording status event.
    if (event is Map<dynamic, dynamic>) {
      print(event);
      // Now it's safe to assume event is a map and access its 'type' key.
      if (event['type'] != null && event['type'] == 'screenRecordingStatus' || event['type'] == 'microphoneStatus') {
        if (event['elapsedTime'] != null) {
          setState(() {
            _counter = event['elapsedTime'];
          });
        }
      }
    } else if (event is num) {
      // Assuming microphone levels are sent as numeric values.
      // Handle the microphone level event.
      // For example, you might want to display this level in your UI.
      print('Mic level: $event');
    } else {
      // Handle unexpected event format.
      print('Unexpected event format: $event');
    }
  }

  // void handleEvent(dynamic event) {
  //   print(event);
  //   if (event['type'] != null && event['type'] == 'screenRecordingStatus' || event['type'] == 'microphoneStatus' && event['elapsedTime'] != null) {
  //     setState(() {
  //       _counter = event['elapsedTime'];
  //     });
  //   }

  //   // if (event['type'] == 'screenRecordingStatus' || event['type'] == 'microphoneStatus' && event['elapsedTime'] != null) {
  //   //   setState(() {
  //   //     _counter = event['elapsedTime'];
  //   //   });
  //   // }
  // }

  Future<void> checkMicPermission() async {
    bool granted = await _shadowPlugin.isMicPermissionGranted();
    print("Microphone Permission: $granted");
  }

  Future<void> checkScreenPermission() async {
    bool granted = await _shadowPlugin.isScreenPermissionGranted();
    _shadowPlugin.screenCaptureKitBugEvents.listen((event) {
      print("Screen Capture Kit Bug Event입니다 $event");
    }, onError: (error) {
      print(error);
    });
    print("Screen Permission: $granted");
  }

  Future<void> getAllScreenRecordingPermissionStatuses() async {
    Map<String, dynamic> result = await _shadowPlugin.getAllScreenPermissionStatuses();
    setState(() {
      _micPermissionStatus = result['micPermissionStatus'].toString();
    });
    print("getAllScreenRecordingPermissionStatuses: $result");
  }

  Future<dynamic> getAudioInputDeviceList() async {
    var result = await _shadowPlugin.getAudioInputDeviceList();
    print("AudioDeviceList result type: ${result.runtimeType} $result");

    // assign the result to the audioInputDeviceList
    audioInputDeviceList = result.cast<String>();
    print("initState called $audioInputDeviceList");
    setState(() {
      if (audioInputDeviceList.isNotEmpty) {
        dropdownValue = audioInputDeviceList.first;
      }
    });

    print("Audio Input Device List: $audioInputDeviceList");
  }

  Future<dynamic> setAudioInputDevice(String deviceName) async {
    print("deviceName:$deviceName");

    var result = await _shadowPlugin.setAudioInputDevice(deviceName);
    print("Audio Input Device Set: $result");
  }

  Future<dynamic> getAudioInputDevice() async {
    var result = await _shadowPlugin.getDefaultAudioInputDevice();
    print("Audio Input Device: $result");
  }

  Future<void> startShadowServer() async {
    final response = await _shadowPlugin.startShadowServer();
    print("Shadow Server Response: $response");
  }

  Future<void> stopShadowServer() async {
    await _shadowPlugin.stopShadowServer();
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
              Text('$isInMeeting', style: Theme.of(context).textTheme.headlineMedium),

              CustomButton("Create createNewWindow", () => _createNewWindow()),
              CustomButton("Start Listening", () => _startListening()),
              CustomButton("Stop Listening", () => _stopListening()),

              CustomButton(
                  "Request Microhpone Permission",
                  () => requestMicPermissionWithEvents(
                        _shadowPlugin.requestMicPermission,
                        _shadowPlugin.microphonePermissionEvents,
                      )),
              // CustomButton("RUN LOOF COMMAND", () => finalLsofTest()),
              // CustomButton("Run log stream --predicate", () => runStream()),
              // CustomButton("stop log stream --predicate", () => stopStream()),
              CustomButton("Get Current Default Audio Input Device", () => getAudioInputDevice()),
              CustomButton("Get Audio Input Devices 🎤", () => getAudioInputDeviceList()),
              CustomButton("Set Audio Input Devices 🎤", () => setAudioInputDevice("")),

              DropdownButton<String>(
                value: dropdownValue,
                icon: const Icon(Icons.arrow_downward),
                iconSize: 24,
                elevation: 16,
                style: const TextStyle(color: Colors.deepPurple),
                underline: Container(
                  height: 2,
                  color: Colors.deepPurpleAccent,
                ),
                onChanged: (String? newValue) {
                  setAudioInputDevice(newValue ?? '');

                  setState(() {
                    dropdownValue = newValue ?? '';
                    print('Dropdown selected: $dropdownValue');
                  });
                },
                items: audioInputDeviceList.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),

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
              // CustomButton(
              //   "get  screen recording all permissions button",
              //   () => getAllScreenRecordingPermissionStatuses(),
              // ),
              // CustomButton(
              //   "Stop Screen Recording Permission Request Stream 버튼",
              //   () => stopRequestingPermission(screenCaptureEventSubscription),
              // ),
              // CustomButton(
              //   "Open Mic System Setting 버튼",
              //   () => _shadowPlugin.openMicSystemSetting(),
              // ),
              // CustomButton(
              //   "Open Screen Recording System Setting 버튼",
              //   () => _shadowPlugin.openScreenSystemSetting(),
              // ),
              // CustomButton(
              //   "Is Microphone Permission Granted 버튼",
              //   () => checkMicPermission(),
              // ),
              // CustomButton(
              //   "Is Screen Recording Permission Granted 버튼",
              //   () => checkScreenPermission(),
              // ),
              // CustomButton(
              //     "ScreenCapture 버튼", () => startRecording(_shadowPlugin.startSystemAndMicAudioRecordingWithDefault, _shadowPlugin.microphoneEvents)),
              // // () => startScreenCapture()),
              // CustomButton(
              //     "Stop ScreenCapture 버튼", () => stopRecording(_shadowPlugin.stopRecordingMicAndSystemAudio, screenCaptureEventSubscription)),
              // CustomButton(
              //     "Start Microphone Recording 버튼", () => startRecording(_shadowPlugin.startMicRecordingWithDefault, _shadowPlugin.microphoneEvents)),
              // CustomButton("Stop Microphone Recording 버튼", () => stopRecording(_shadowPlugin.stopMicRecording, microphoneEventSubscription)),
              // CustomButton("Start System Audio Only Capturing",
              //     () => startRecording(_shadowPlugin.startSystemAudioRecordingWithDefault, _shadowPlugin.screenCaptureEvents)),
              // CustomButton("Stop System Audio Only Capturing", () => stopRecording(_shadowPlugin.stopScreenCapture, screenCaptureEventSubscription)),
              // CustomButton(
              //   "Delete File 버튼",
              //   () => deleteFile("FlutterSystemAudio.m4a"),
              // ),
              // CustomButton(
              //   "Relaunch 버튼",
              //   () => _shadowPlugin.restartApp(),
              // ),
              CustomButton(
                "Start Nudging",
                () => startNudging(),
              ),
              CustomButton(
                "Cancel Nudging",
                () => cancelNudging(),
              ),
              CustomButton(
                "Start Shadow Server",
                () => startShadowServer(),
              ),
              CustomButton(
                "Stop Shadow Server",
                () => stopShadowServer(),
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
