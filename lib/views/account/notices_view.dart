import 'package:fl_clash/common/xboard_api.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';

class NoticesView extends StatefulWidget {
  const NoticesView({super.key});

  @override
  State<NoticesView> createState() => _NoticesViewState();
}

class _NoticesViewState extends State<NoticesView> {
  List<dynamic> _notices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotices();
  }

  Future<void> _fetchNotices() async {
    setState(() => _loading = true);
    try {
      final result = await xboardApi.getNotices();
      if (result['data'] is List) {
        _notices = result['data'];
      }
    } catch (e) {
      globalState.showNotifier('获取公告失败: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final ts = timestamp is int ? timestamp : int.tryParse(timestamp.toString()) ?? 0;
    if (ts <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('公告')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notices.isEmpty
              ? const Center(child: Text('暂无公告'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notices.length,
                  itemBuilder: (context, index) {
                    final notice = _notices[index] as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notice['title']?.toString() ?? '公告',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatTime(notice['created_at']),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              notice['content']?.toString() ?? '',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
