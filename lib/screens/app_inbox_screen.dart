import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../models/clevertap_models.dart';
import '../services/clevertap_service.dart';

/// A Flutter-rendered CleverTap App Inbox.
///
/// CleverTap also ships a native inbox UI (`CleverTapPlugin.showInbox`, exposed
/// here through the overflow menu), but rendering it in Flutter keeps the app's
/// theming and works identically on both platforms.
/// See https://developer.clevertap.com/docs/flutter-app-inbox
class AppInboxScreen extends StatefulWidget {
  const AppInboxScreen({super.key});

  @override
  State<AppInboxScreen> createState() => _AppInboxScreenState();
}

class _AppInboxScreenState extends State<AppInboxScreen> {
  @override
  void initState() {
    super.initState();
    // The inbox may already have been populated before this screen was opened.
    CleverTapService.instance.refreshInbox();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CleverTapService>(
      builder: (context, ct, _) {
        final messages = ct.inboxMessages;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications',
                style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              if (ct.inboxUnreadCount > 0)
                IconButton(
                  tooltip: 'Mark all as read',
                  icon: const Icon(Icons.done_all),
                  onPressed: ct.markAllInboxMessagesRead,
                ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'native') ct.showNativeInbox(isDark: isDark);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'native',
                    child: Text('Open native inbox'),
                  ),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: ct.refreshInbox,
            child: messages.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _InboxTile(
                      message: messages[index],
                      isDark: isDark,
                    ),
                  ),
          ),
        );
      },
    );
  }

  /// Kept scrollable so pull-to-refresh still works with no messages.
  Widget _buildEmptyState(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_off_outlined,
                size: 80,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No new notifications',
                style: TextStyle(
                  fontSize: 18,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We will notify you when something new arrives.',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One inbox message. Raises the CleverTap "viewed" event when it scrolls into
/// existence and the "clicked" event on tap.
class _InboxTile extends StatefulWidget {
  final CtInboxMessage message;
  final bool isDark;

  const _InboxTile({required this.message, required this.isDark});

  @override
  State<_InboxTile> createState() => _InboxTileState();
}

class _InboxTileState extends State<_InboxTile> {
  @override
  void initState() {
    super.initState();
    CleverTapService.instance.markInboxMessageViewed(widget.message.messageId);
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final content = message.primary;
    final unread = !message.isRead;

    return Dismissible(
      key: ValueKey(message.messageId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) =>
          CleverTapService.instance.deleteInboxMessage(message.messageId),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: content != null && content.hasMedia
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: content.mediaUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 56,
                    height: 56,
                    color: Colors.black12,
                  ),
                  errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported),
                ),
              )
            : CircleAvatar(
                backgroundColor:
                    unread ? Colors.blue.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                child: Icon(
                  Icons.notifications,
                  color: unread ? Colors.blue : Colors.grey,
                ),
              ),
        title: Text(
          content?.title.isNotEmpty == true ? content!.title : 'Notification',
          style: TextStyle(
            fontWeight: unread ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content != null && content.message.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(content.message, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (message.date != null) ...[
              const SizedBox(height: 6),
              Text(
                DateFormat('d MMM, h:mm a').format(message.date!),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
        trailing: unread
            ? Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () =>
            CleverTapService.instance.markInboxMessageClicked(message.messageId),
      ),
    );
  }
}
