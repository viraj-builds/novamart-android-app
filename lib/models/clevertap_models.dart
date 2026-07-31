import 'dart:convert';

/// Helpers for the loosely-typed JSON that the CleverTap native SDKs hand back.
/// Payloads arrive either as a decoded `Map` or as a JSON `String` depending on
/// the platform, so every parser here is defensive on purpose.
Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Not JSON — fall through and treat as absent.
    }
  }
  return null;
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return decoded;
    } catch (_) {
      // Not JSON — fall through and treat as empty.
    }
  }
  return const [];
}

/// One renderable slide/page of a Native Display unit or an Inbox message.
/// Both features share CleverTap's `content[]` shape.
class CtContent {
  final String title;
  final String titleColor;
  final String message;
  final String messageColor;
  final String mediaUrl;
  final String actionUrl;

  const CtContent({
    required this.title,
    required this.titleColor,
    required this.message,
    required this.messageColor,
    required this.mediaUrl,
    required this.actionUrl,
  });

  factory CtContent.fromJson(dynamic raw) {
    final json = _asMap(raw) ?? const {};
    final title = _asMap(json['title']) ?? const {};
    final message = _asMap(json['message']) ?? const {};
    final media = _asMap(json['media']) ?? const {};
    final action = _asMap(json['action']) ?? const {};
    final actionUrl = _asMap(action['url']) ?? const {};
    // CleverTap nests the tap-through URL per platform.
    final android = _asMap(actionUrl['android']) ?? const {};
    final ios = _asMap(actionUrl['ios']) ?? const {};

    return CtContent(
      title: (title['text'] ?? '').toString(),
      titleColor: (title['color'] ?? '').toString(),
      message: (message['text'] ?? '').toString(),
      messageColor: (message['color'] ?? '').toString(),
      mediaUrl: (media['url'] ?? '').toString(),
      actionUrl: (android['text'] ?? ios['text'] ?? '').toString(),
    );
  }

  bool get hasMedia => mediaUrl.isNotEmpty;
}

/// A CleverTap Native Display unit.
/// See https://docs.clevertap.com/docs/native-display
class CtDisplayUnit {
  /// `wzrk_id` — required when raising viewed/clicked events back to CleverTap.
  final String unitId;
  final String type;
  final List<CtContent> contents;

  /// Custom key-value pairs configured on the campaign. Used here to decide
  /// which screen the unit belongs on and where a tap should navigate.
  final Map<String, dynamic> customKV;

  const CtDisplayUnit({
    required this.unitId,
    required this.type,
    required this.contents,
    required this.customKV,
  });

  static CtDisplayUnit? fromJson(dynamic raw) {
    final json = _asMap(raw);
    if (json == null) return null;

    final unitId = (json['wzrk_id'] ?? json['unitID'] ?? json['ti'] ?? '').toString();
    if (unitId.isEmpty) return null;

    final contents = _asList(json['content'])
        .map(CtContent.fromJson)
        .where((c) => c.title.isNotEmpty || c.message.isNotEmpty || c.hasMedia)
        .toList();
    if (contents.isEmpty) return null;

    return CtDisplayUnit(
      unitId: unitId,
      type: (json['type'] ?? 'simple').toString(),
      contents: contents,
      customKV: _asMap(json['custom_kv']) ?? const {},
    );
  }

  CtContent get primary => contents.first;

  /// Campaigns tag themselves with a `screen` KV so a single dashboard can feed
  /// several placements in the app. Untagged units render on Home.
  String get targetScreen => (customKV['screen'] ?? 'home').toString();
}

/// A CleverTap App Inbox message, used by the custom Flutter-rendered inbox.
/// See https://developer.clevertap.com/docs/flutter-app-inbox
class CtInboxMessage {
  final String messageId;
  final bool isRead;
  final DateTime? date;
  final String type;
  final List<CtContent> contents;
  final List<String> tags;
  final Map<String, dynamic> customKV;

  const CtInboxMessage({
    required this.messageId,
    required this.isRead,
    required this.date,
    required this.type,
    required this.contents,
    required this.tags,
    required this.customKV,
  });

  static CtInboxMessage? fromJson(dynamic raw) {
    final json = _asMap(raw);
    if (json == null) return null;

    final messageId = (json['id'] ?? json['_id'] ?? '').toString();
    if (messageId.isEmpty) return null;

    final msg = _asMap(json['msg']) ?? const {};
    final contents = _asList(msg['content']).map(CtContent.fromJson).toList();

    // `date` is epoch seconds on both platforms.
    final rawDate = json['date'];
    DateTime? date;
    if (rawDate is num) {
      date = DateTime.fromMillisecondsSinceEpoch(rawDate.toInt() * 1000);
    }

    return CtInboxMessage(
      messageId: messageId,
      isRead: json['isRead'] == true || json['read'] == 1 || json['read'] == true,
      date: date,
      type: (msg['type'] ?? 'simple').toString(),
      contents: contents,
      tags: _asList(msg['tags']).map((t) => t.toString()).toList(),
      customKV: _asMap(msg['custom_kv']) ?? const {},
    );
  }

  CtContent? get primary => contents.isEmpty ? null : contents.first;
}
