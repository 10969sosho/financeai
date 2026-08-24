import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_session.dart';
import '../models/message.dart';
import 'api_client.dart';
import 'auth_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref.read(apiClientProvider));
});

class ChatService {
  final ApiClient _apiClient;

  ChatService(this._apiClient);

  Future<List<ChatSession>> getSessions() async {
    final response = await _apiClient.dio.get('/sessions');
    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => ChatSession.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ChatSession> createSession() async {
    final response = await _apiClient.dio.post('/sessions');
    return ChatSession.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteSession(int id) async {
    await _apiClient.dio.delete('/sessions/$id');
  }

  Future<List<Message>> getMessages(int sessionId) async {
    final response = await _apiClient.dio.get('/sessions/$sessionId/messages');
    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Message> sendMessage(String body, {int? sessionId}) async {
    final response = await _apiClient.dio.post(
      '/chat',
      data: {
        'body': body,
        if (sessionId != null) 'session_id': sessionId,
      },
    );

    final messageData = response.data['data']['message'] as Map<String, dynamic>;
    return Message.fromJson(messageData);
  }
}
