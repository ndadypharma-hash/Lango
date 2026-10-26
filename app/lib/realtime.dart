import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'models.dart';

/// Connexion temps réel (Socket.IO) : réception instantanée des messages traduits.
class Realtime {
  final io.Socket _socket;
  final _messages = StreamController<ChatMessage>.broadcast();
  final _reads = StreamController<String>.broadcast();

  Realtime(String baseUrl, String token)
      : _socket = io.io(
          baseUrl,
          io.OptionBuilder()
              .setTransports(['websocket'])
              .setAuth({'token': token})
              .enableReconnection()
              .disableAutoConnect()
              .build(),
        ) {
    _socket.on('message:new', (data) {
      if (data is Map) _messages.add(ChatMessage.fromJson(Map<String, dynamic>.from(data)));
    });
    _socket.on('message:read', (data) {
      if (data is Map && data['by'] != null) _reads.add(data['by'].toString());
    });
    _socket.connect();
  }

  /// Nouveaux messages, envoyés ou reçus, déjà dans la langue de l'utilisateur.
  Stream<ChatMessage> get messages => _messages.stream;

  /// Identifiant de la personne qui vient de lire mes messages.
  Stream<String> get reads => _reads.stream;

  bool get connected => _socket.connected;

  /// Envoie un message ; renvoie null si la connexion temps réel n'est pas disponible.
  Future<ChatMessage?> send(String to, String text) {
    if (!_socket.connected) return Future.value(null);
    final done = Completer<ChatMessage?>();
    _socket.emitWithAck('message:send', {'to': to, 'text': text}, ack: (res) {
      if (done.isCompleted) return;
      if (res is Map && res['ok'] == true) {
        done.complete(ChatMessage.fromJson(Map<String, dynamic>.from(res['message'])));
      } else {
        done.completeError(Exception(res is Map ? res['error'] ?? 'Envoi impossible' : 'Envoi impossible'));
      }
    });
    return done.future.timeout(const Duration(seconds: 15), onTimeout: () => null);
  }

  void dispose() {
    _socket.dispose();
    _messages.close();
    _reads.close();
  }
}
