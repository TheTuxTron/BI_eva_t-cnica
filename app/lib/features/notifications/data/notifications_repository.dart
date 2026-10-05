import 'package:equatable/equatable.dart';

import '../../../core/cache/cache_store.dart';
import '../../../core/cache/resource.dart';
import '../../../core/network/api_client.dart';

class AppNotification extends Equatable {
  const AppNotification({required this.id, required this.title, required this.body, this.deeplink, required this.createdAt, this.read = false});
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        deeplink: j['deeplink'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        read: (j['read'] as bool?) ?? false,
      );
  final String id, title, body;
  final String? deeplink;
  final DateTime createdAt;
  final bool read;

  AppNotification markRead() => AppNotification(id: id, title: title, body: body, deeplink: deeplink, createdAt: createdAt, read: true);

  @override
  List<Object?> get props => [id, read];
}

class Inbox extends Equatable {
  const Inbox(this.items, this.unread);
  factory Inbox.fromJson(Object? json) {
    final j = Map<String, dynamic>.from(json! as Map);
    return Inbox((j['items'] as List).map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map))).toList(), (j['unread'] as num).toInt());
  }
  final List<AppNotification> items;
  final int unread;
  @override
  List<Object?> get props => [items, unread];
}

class NotificationsRepository {
  NotificationsRepository(this.api, this.cache);
  final ApiClient api;
  final CacheStore cache;

  Stream<Resource<Inbox>> watchInbox() =>
      staleWhileRevalidate(cache: cache, key: 'inbox', fetch: () => api.get<Json>('/v1/notifications'), decode: Inbox.fromJson);

  Future<Inbox> since(DateTime since) async => Inbox.fromJson(await api.get<Json>('/v1/notifications', query: {'since': since.toUtc().toIso8601String()}));

  Future<void> markRead(String id) => api.post<dynamic>('/v1/notifications/$id/read');

  Future<void> markAllRead() => api.post<dynamic>('/v1/notifications/read-all');

  Future<bool> registerDevice(String token, String platform) async {
    final j = await api.post<Json>('/v1/devices', body: {'token': token, 'platform': platform});
    return (j['fcmEnabled'] as bool?) ?? false;
  }
}
