import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

class WebsocketManager {
  // Base URL as a class property
  static const String _baseUrl = "ws://127.0.0.1:65520/api/v1/network/ws/listening";
  static const String _baseUrlStream = "ws://127.0.0.1:65520/api/v1/network/ws/listening/stream";

  // Each connection managed via UUID(string) keys in a Map
  final Map<String, WebSocketChannel> _channels = {};

  // Singleton pattern implementation
  static final WebsocketManager _instance = WebsocketManager._internal();

  // Factory constructor returns the single instance
  factory WebsocketManager() => _instance;

  // Private constructor for singleton pattern
  WebsocketManager._internal();

  // Connect with optional UUID (auto-generated if not provided)
  void connect({String? uuid}) {
    final String id = uuid ?? Uuid().v4();

    // Skip if already connected
    if (_channels.containsKey(id)) {
      print("WebSocket with id $id is already connected.");
      return;
    }
    const String WHISPER_SMALL = "whisper-small-mlx";
    const String WHISPER_TURBO = "whisper-turbo";
    const String WHISPER_LARGE_V3_TURBO = "whisper-large-v3-turbo";

    final uri = Uri.parse('$_baseUrlStream/$id').replace(queryParameters: {
      'whisper_model': WHISPER_SMALL,
      'whisper_language': 'en',
    });

    // Use the base URL with the UUID
    // final String url = "$_baseUrl/$id";
    final channel = WebSocketChannel.connect(uri);
    _channels[id] = channel;
    print("WebSocket connected to $uri!");

    channel.stream.listen(
      (message) {
        print("[$id] Received Message: $message");
        try {
          final decodedMessage = json.decode(message);
          print("[$id] Decoded Message: $decodedMessage");
          if (decodedMessage is Map && decodedMessage.containsKey('chunk_num')) {
            print("[$id] Received Transcript: ${decodedMessage['chunk_num']}");
          }

          if (decodedMessage is Map && decodedMessage.containsKey('error')) {
            print("[$id] Received Error: ${decodedMessage['error']}");
            disconnect(id);
          }
          if (decodedMessage is Map && decodedMessage.containsKey('whisper') && decodedMessage.containsKey('isLastSegment')) {
            if (decodedMessage['isLastSegment'] == true) {
              disconnect(id);
            }

            print("[$id] Received Whisper: ${decodedMessage['whisper']}");
          }
        } catch (e) {
          print("[$id] Failed to decode JSON message: $e");
        }
      },
      onError: (error) {
        print("[$id] WebSocket Error: $error");
        _channels.remove(id);
      },
      onDone: () {
        print("[$id] WebSocket closed");
        _channels.remove(id);
      },
    );
  }

  void sendIsInPersonMeeting(String id, bool isInPersonMeeting) {
    if (!_channels.containsKey(id)) {
      print("WebSocket with id $id is not connected!");
      return;
    }

    final jsonData = {"isInPersonMeeting": isInPersonMeeting};
    _channels[id]!.sink.add(jsonEncode(jsonData));
    print("[$id] Sent: $jsonData");
  }

  // 특정 연결에 메시지 보내기
  void sendMessage(String id, String micAudio, String sysAudio, bool isFinishedListening) {
    if (!_channels.containsKey(id)) {
      print("WebSocket with id $id is not connected!");
      return;
    }

    const String basePath = "/Users/phoenixc/Library/Application Support/com.taperlabs.shadow";
    final String micPath = "$basePath/$micAudio";
    final String sysPath = "$basePath/$sysAudio";

    final jsonData = {"mic_audio": micPath, "sys_audio": sysPath, "isFinishedListening": isFinishedListening};

    _channels[id]!.sink.add(jsonEncode(jsonData));
    print("[$id] Sent: $jsonData");
  }

  // 특정 연결 종료
  void disconnect(String id) {
    if (!_channels.containsKey(id)) {
      print("WebSocket with id $id is not connected!");
      return;
    }
    _channels[id]!.sink.close(status.normalClosure);
    _channels.remove(id);
    print("WebSocket with id $id disconnected!");
  }

  // 모든 연결 종료 (필요시)
  void disconnectAll() {
    _channels.keys.toList().forEach((id) {
      disconnect(id);
    });
  }
}
