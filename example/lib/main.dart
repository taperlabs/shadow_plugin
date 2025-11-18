import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shadow/shadow.dart';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

import 'package:uuid/uuid.dart';

import 'package:shadow_example/websocket_manager.dart';

void main() {
  runApp(const MyApp());
}

class AudioFileName {
  final String convUuid;

  const AudioFileName({required this.convUuid});

  String get systemAudioWav => '$convUuid-SystemAudio.wav';
  String get micRecordingWav => '$convUuid-MicRecording.wav';
  String get mergedAudioWav => '$convUuid-MergedAudio.wav';
  String get noSilenceWav => '$convUuid-NoSilence.wav';
  String get modifiedMicRecordingWav => '$convUuid-ModifiedMicRecording.wav';
  String get modifiedMergedAudioWav => '$convUuid-Modified-MergedAudio.wav';

  String get systemAudioM4a => '$convUuid-SystemAudio.m4a';
  String get micRecordingM4a => '$convUuid-MicRecording.m4a';
  String get mergedAudioM4a => '$convUuid-MergedAudio.m4a';
  String get noSilenceM4a => '$convUuid-NoSilence.m4a';
  String get modifiedMicRecordingM4a => '$convUuid-ModifiedMicRecording.m4a';
  String get modifiedMergedAudioM4a => '$convUuid-Modified-MergedAudio.m4a';
}

class MyUUID {
  /// Generates a UUID (v4) without dashes.
  static String createUUID() {
    return const Uuid().v4().replaceAll('-', '');
  }
}

enum WindowState {
  closed,
  preListening,
  listening,
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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
  StreamSubscription<dynamic>? listeningEventStreamSubscription;

  final webSocketManager = WebsocketManager();
  String currentUUID = '';
  String prevUUID = '';

  String dropdownValue = '';

  List<String> audioInputDeviceList = [];

  WindowState windowState = WindowState.closed;

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

  late HotKey _hotKey;
  bool isRecording = false;
  String? currentUuid;

  @override
  void initState() {
    super.initState();
    _setupHotkey();
    getAudioInputDeviceList();
    _setupMultiWindowStatusEventStream();
    _setupListeningStatusEventStream();
    _shadowPlugin.setNativeCallHandler(_handleNativeCall);

    // initPlatformState();
  }

  Future<void> testUpdateCaptureTarget() async {
    try {
      final windowConfig = {
        'type': 'noCapture',
        // 'windowTitle': "Google Meet - Meet - ",
      };

      final result = await _shadowPlugin.updateCaptureTarget(windowConfig);
      print("Update Capture Target Success ✅: $result");
    } on PlatformException catch (e) {
      print("Update Capture Target Error ❌: ${e.code} - ${e.message}");
    }
  }

  Future<void> testEnumerateWindows() async {
    try {
      final result = await _shadowPlugin.enumerateWindows();
      print("=== Enumerate Windows Success ✅ ===");

      if (result is Map<dynamic, dynamic>) {
        final windows = result['windows'] as List<dynamic>? ?? [];
        final displays = result['displays'] as List<dynamic>? ?? [];

        print("\n🖥️ Displays (${displays.length}):");
        for (var display in displays) {
          print("  Display ID: ${display['displayID']}");
          print("  Name: ${display['localizedName']}");
          print("  Size: ${display['width']} x ${display['height']}");
          print("  Position: (${display['x']}, ${display['y']})");
          print("  ---");
        }

        print("\n🪟 Windows (${windows.length}):");
        for (var window in windows) {
          print("  Window ID: ${window['windowID']}");
          print("  Title: ${window['title']}");
          print("  App: ${window['owningApplicationName']}");
          print("  Bundle ID: ${window['bundleID']}");
          print("  Size: ${window['width']} x ${window['height']}");
          print("  Position: (${window['x']}, ${window['y']})");
          print("  Active: ${window['isActive']}");
          print("  ---");
        }
      }
    } on PlatformException catch (e) {
      print("Enumerate Windows Error ❌: ${e.code} - ${e.message}");
    }
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    print("Flutter received a native call: ${call.method} with arguments: ${call.arguments}");

    // Handle different method calls from native code
    switch (call.method) {
      case 'onCaptureTargetSelected':
        // Handle capture target selection from Swift
        final data = Map<String, dynamic>.from(call.arguments);
        final type = data['type'];

        print("Capture Target Selected:");
        print("  Type: $type");

        if (type == 'noCapture') {
          print("  No capture selected");
        } else {
          // WindowInfo or DisplayInfo data
          print("  Full data: $data");

          // Common fields for both window and display
          if (data.containsKey('windowID')) {
            // WindowInfo
            print("  Window ID: ${data['windowID']}");
            print("  Title: ${data['title']}");
            print("  App: ${data['owningApplicationName']}");
            print("  Bundle ID: ${data['bundleID']}");
            print("  Position: (${data['x']}, ${data['y']})");
            print("  Size: ${data['width']} x ${data['height']}");
            print("  Is Active: ${data['isActive']}");
          } else if (data.containsKey('displayID')) {
            // DisplayInfo
            print("  Display ID: ${data['displayID']}");
            print("  Name: ${data['localizedName']}");
            print("  Position: (${data['x']}, ${data['y']})");
            print("  Size: ${data['width']} x ${data['height']}");
          }
        }

        // You can update UI state here if needed
        // setState(() {
        //   // Update some state based on the selected target
        // });
        break;

      case 'someNativeMethod':
        // Handle the method and log the arguments
        print("Handling someNativeMethod with arguments: ${call.arguments}");
        break;

      default:
        throw PlatformException(
          code: 'Unimplemented',
          message: 'Method ${call.method} not implemented in Flutter.',
        );
    }
  }

  connectWebSocket(String uuid) {
    webSocketManager.connect(uuid: uuid);
  }

  disConnectWebSocket(String uuid) {
    webSocketManager.disconnect(uuid);
  }

  testStartListening() async {
    final convUuid = MyUUID.createUUID();
    final audioFileName = AudioFileName(convUuid: convUuid);

    currentUUID = convUuid;

    var micFileName = audioFileName.micRecordingM4a;
    var systemFileName = audioFileName.systemAudioM4a;

    print("convUuid: ${currentUUID} micFileName: $micFileName -- systemFileName: $systemFileName");

    final listeningConfig = {
      'userName': "Phoenix",
      'micFileName': micFileName,
      'sysFileName': systemFileName,
      'uuid': currentUUID,
      'shouldScreenshotCapture': true
    };

    await _shadowPlugin.testStartListening(listeningConfig: listeningConfig);
    connectWebSocket(currentUUID);
  }

  testStopListening() async {
    await _shadowPlugin.testStopListening();
  }

  void _setupListeningStatusEventStream() {
    if (listeningEventStreamSubscription != null) {
      listeningEventStreamSubscription?.cancel();
    }

    listeningEventStreamSubscription = _shadowPlugin.listeningStatusEvents.listen((event) async {
      print('Flutter-side listening Event Stream: $event');

      try {
        // Convert event to Map (assuming it's already a JSON-like structure)
        final eventData = Map<String, dynamic>.from(event);

        if (eventData.containsKey("isInPersonMeeting")) {
          final isInPersonMeeting = eventData["isInPersonMeeting"];
          print('isInPersonMeeting: $isInPersonMeeting');
          webSocketManager.sendIsInPersonMeeting(currentUUID, isInPersonMeeting);
          return;
        }

        if (eventData["type"] == "system_audio_error") {
          // Handle system audio error
          print("System audio error: ${eventData["error_message"]}");
          print("Error code: ${eventData["error_code"]}");
          print("Segment index: ${eventData["segment_index"]}");

          await testStopListening();

          // Take appropriate action for system audio errors
          // For example, you might want to stop the current listening session
          // disConnectWebSocket(currentUUID);
          return;
        }

        // Extract required fields
        final String micAudio = eventData["microphone_segment"] ?? "";
        final String sysAudio = eventData["system_audio_segment"] ?? "";
        final bool isFinishedListening = eventData.containsKey("isFinishedListening") ? eventData["isFinishedListening"] : true;

        if (eventData["isCancelledListening"]) {
          print("Listening is cancelled");
          disConnectWebSocket(currentUUID);
          return;
        }
        webSocketManager.sendMessage(currentUUID, micAudio, sysAudio, isFinishedListening);
      } catch (e) {
        print("Error parsing event data: $e");
      }
    }, onError: (error) {
      print('Error from event stream: $error');
    });
  }

  @override
  void dispose() {
    print("dispose called !!!!@!@!@!@");
    _shadowPlugin.stopShadowServer();
    multiWindowStatusEventStreamSubscription?.cancel();
    listeningEventStreamSubscription?.cancel();
    hotKeyManager.unregister(_hotKey);
    super.dispose();
  }

  setListeningConfig() {
    final listeningConfig = {
      'userName': "Phoenix",
      'micFileName': "micAudio.m4a",
      'sysFileName': "sysAudio.m4a",
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
      final windowCloseType = event['windowCloseType'];

      if (windowCloseType == 'cancel') {
        print("cancel detected");
        disConnectWebSocket(currentUUID);
      }
      // WindowState windowState;

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
    print("Hotkey setup called");

    await hotKeyManager.unregisterAll(); // Clear any existing registrations

    _hotKey = HotKey(
      key: PhysicalKeyboardKey.keyS,
      modifiers: [HotKeyModifier.control, HotKeyModifier.meta],
      scope: HotKeyScope.system,
    );

    print("Hotkey setup called ${_hotKey.identifier}");

    await hotKeyManager.register(
      _hotKey,
      keyDownHandler: (hotKey) async {
        print('Hotkey pressed: ${hotKey.identifier}, ${hotKey.physicalKey.debugName}, ${hotKey.scope} ${hotKey.modifiers}');

        if (windowState == WindowState.listening) {
          await testStopListening();
          return;
        }

        await testStartListening();

        // await _shadowPlugin.testStartListening();

        // final key = hotKey.physicalKey.debugName!;
        // final modifiers = hotKey.modifiers!.map((modifier) => modifier.toString()).toList();
        // final listeningConfig = {
        //   'userName': "Phoenix",
        //   'micFileName': "micAudio.m4a",
        //   'sysFileName': "sysAudio.m4a",
        //   'isAudioSaveOn': true,
        // };

        // await _shadowPlugin.createNewWindow(listeningConfig: listeningConfig);

        //Send event to Swift
      },
    );
  }

  Future<void> _createNewWindow() async {
    final listeningConfig = {
      'userName': "Phoenix",
      'micFileName': "micAudio.m4a",
      'sysFileName': "sysAudio.m4a",
      'hotkeys': '^+⌘',
    };

    await _shadowPlugin.createNewWindow(listeningConfig: listeningConfig);
    if (multiWindowEventStreamSubscription == null) {
      _setupNewEventStream();
    }
  }

  Future<void> _startListening() async {
    final listeningConfig = {
      'userName': "Phoenix",
      'micFileName': "micAudio.m4a",
      'sysFileName': "sysAudio.m4a",
    };

    await _shadowPlugin.startListening(listeningConfig: listeningConfig);
    if (multiWindowEventStreamSubscription == null) {
      _setupNewEventStream();
    }
  }

  Future<void> _stopListening() async {
    await _shadowPlugin.stopListening();
  }

  Future deleteFile(String fileName) async {
    await _shadowPlugin.deleteFileIfExists(fileName);
  }

  //Microphone
  Future startMicRecording() async {
    try {
      await _shadowPlugin.startMicRecordingWithConfig(micConfig);
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
      await _shadowPlugin.startSystemAndMicAudioRecordingWithConfig(systemAudioConfig: systemAudioConfig, micConfig: micConfig);

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
              'micFileName': "micAudio.m4a",
              'sysFileName': "sysAudio.m4a",
            };
            await _shadowPlugin.startListening(listeningConfig: listeningConfig);

            setState(() {
              isInMeeting = "미팅 ✅ - zzzz";
            });
          } else {
            print("event['isInMeeting'] is false -- ${event['isInMeeting']}");
            await _shadowPlugin.stopListening();
            print("Stopped listening successfully.");
            setState(() {
              isInMeeting = "미팅 ❌ --- yyyy";
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

  Future<bool> checkSystemAudioPermission() async {
    bool granted = await _shadowPlugin.checkSystemAudioPermission();
    print("System Audio Permission: $granted");
    return granted;
  }

  Future<void> requestSystemAudioPermission() async {
    try {
      await _shadowPlugin.requestSystemAudioPermission();
      print("requestSystemAudioPermission called successfully");
    } on PlatformException catch (e) {
      print(e);
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
              Text('$_counter', style: Theme.of(context).textTheme.headlineMedium),
              Text('$_micPermissionStatus', style: Theme.of(context).textTheme.headlineMedium),
              Text('$_isScreenRecordingPermissionGranted', style: Theme.of(context).textTheme.headlineMedium),
              Text('$isInMeeting', style: Theme.of(context).textTheme.headlineMedium),

              // CustomButton("Weboskcet Test", () => connectWebSocket()),

              CustomButton("Check System Audio Listening Permission", () async => await checkSystemAudioPermission()),
              CustomButton("Request System Audio Listening Permission", () async => await requestSystemAudioPermission()),

              CustomButton("Test Start Listening", () => testStartListening()),
              CustomButton("Test Stop Listening", () => testStopListening()),
              CustomButton("Test Update Capture Target", () => testUpdateCaptureTarget()),
              CustomButton("Test Enumerate Windows", () => testEnumerateWindows()),

              CustomButton("Create createNewWindow", () => _createNewWindow()),
              CustomButton("Start Listening", () => _startListening()),
              CustomButton("Stop Listening", () => _stopListening()),

              CustomButton(
                  "Request Microhpone Permission",
                  () => requestMicPermissionWithEvents(
                        _shadowPlugin.requestMicPermission,
                        _shadowPlugin.microphonePermissionEvents,
                      )),
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
