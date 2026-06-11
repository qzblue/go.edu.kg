import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:flutter/material.dart';

class _AnnouncementItem {
  final String title;
  final String content;
  const _AnnouncementItem({required this.title, required this.content});
  factory _AnnouncementItem.fromJson(Map<String, dynamic> j) =>
      _AnnouncementItem(
        title: j['title'] as String? ?? '',
        content: j['content'] as String? ?? '',
      );
}

Future<void> fetchAndShowAnnouncements(BuildContext context) async {
  if (!xboardApi.isLoggedIn) {
    if (!context.mounted) return;
    globalState.showCommonDialog(
      context: context,
      child: CommonDialog(
        title: '公告通知',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
        child: const Text('请先登录后再查看公告'),
      ),
    );
    return;
  }

  List<_AnnouncementItem> items = [];
  String? error;
  try {
    final result = await xboardApi.getNotices();
    final list = result['data'];
    if (list is List) {
      items = list
          .whereType<Map<String, dynamic>>()
          .map(_AnnouncementItem.fromJson)
          .toList();
    }
  } catch (e) {
    error = '网络请求失败，请检查网络连接';
  }
  if (!context.mounted) return;
  globalState.showCommonDialog(
    context: context,
    child: CommonDialog(
      title: '公告通知',
      overrideScroll: items.length > 1,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
      child: error != null
          ? Text(error)
          : items.isEmpty
              ? const Text('暂无公告')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].title,
                            style: Theme.of(ctx).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(items[i].content),
                      ],
                    ),
                  ),
                ),
    ),
  );
}
