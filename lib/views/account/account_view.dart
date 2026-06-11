import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/auth.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountView extends ConsumerStatefulWidget {
  const AccountView({super.key});

  @override
  ConsumerState<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends ConsumerState<AccountView> {
  bool _loadingUserInfo = false;
  String? _planName;

  @override
  void initState() {
    super.initState();
    _refreshUserInfo();
  }

  Future<void> _refreshUserInfo() async {
    if (!xboardApi.isLoggedIn) return;
    setState(() => _loadingUserInfo = true);
    try {
      final result = await xboardApi.getUserInfo();
      if (result['data'] is Map) {
        final userInfo = Map<String, dynamic>.from(result['data']);
        ref.read(userInfoProvider.notifier).set(userInfo);

        final planId = userInfo['plan_id'];
        if (planId != null) {
          try {
            final plansResult = await xboardApi.getPlans();
            if (plansResult['data'] is List) {
              final plans = plansResult['data'] as List;
              final matched = plans.cast<Map<String, dynamic>?>().firstWhere(
                    (p) => p?['id']?.toString() == planId.toString(),
                    orElse: () => null,
                  );
              if (mounted && matched != null) {
                setState(() {
                  _planName = matched['name']?.toString();
                });
              }
            }
          } catch (e) {
            commonPrint.log('获取套餐信息错误: $e');
          }
        }
      }
    } catch (e) {
      commonPrint.log('获取用户信息错误: $e');
    }
    if (mounted) setState(() => _loadingUserInfo = false);
  }

  Future<void> _logout() async {
    final res = await globalState.showMessage(
      message: const TextSpan(text: '确定要退出登录吗？'),
      title: '退出登录',
    );
    if (res != true) return;
    await xboardApi.clearToken();
    ref.read(authTokenProvider.notifier).set(null);
    ref.read(userInfoProvider.notifier).set(null);
  }

  String _formatBytes(dynamic bytes) {
    if (bytes == null) return '0 B';
    final b = bytes is int ? bytes : int.tryParse(bytes.toString()) ?? 0;
    if (b <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double size = b.toDouble();
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${units[i]}';
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '未知';
    final ts =
        timestamp is int ? timestamp : int.tryParse(timestamp.toString()) ?? 0;
    if (ts <= 0) return '未知';
    final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  int _remainingDays(dynamic expiredAt) {
    if (expiredAt == null) return 0;
    final ts = expiredAt is int
        ? expiredAt
        : int.tryParse(expiredAt.toString()) ?? 0;
    if (ts <= 0) return 0;
    final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final diff = date.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  @override
  Widget build(BuildContext context) {
    final userInfo = ref.watch(userInfoProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CommonScaffold(
      title: '用户中心',
      actions: [
        IconButton(
          icon: _loadingUserInfo
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onSurface,
                  ),
                )
              : const Icon(Icons.refresh_rounded),
          onPressed: _loadingUserInfo ? null : _refreshUserInfo,
        ),
      ],
      body: _loadingUserInfo && userInfo == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ---- Account Overview Card ----
                _SectionCard(
                  icon: Icons.person_rounded,
                  title: '账户概览',
                  colorScheme: colorScheme,
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.email_outlined,
                        label: '账户',
                        value: userInfo?['email']?.toString() ?? '未知',
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: '注册时间',
                        value: _formatTimestamp(userInfo?['created_at']),
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.login_outlined,
                        label: '最近登录',
                        value: _formatTimestamp(userInfo?['last_login_at']),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ---- Membership Info Card ----
                _SectionCard(
                  icon: Icons.workspace_premium_rounded,
                  title: '等级信息',
                  colorScheme: colorScheme,
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.card_membership_outlined,
                        label: '当前套餐',
                        value: _planName ?? (userInfo?['plan_id'] != null ? '已订阅' : '无套餐'),
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.event_outlined,
                        label: '到期时间',
                        value: _formatTimestamp(userInfo?['expired_at']),
                      ),
                      const SizedBox(height: 12),
                      Builder(builder: (_) {
                        final days = _remainingDays(userInfo?['expired_at']);
                        final isExpired = days <= 0 && userInfo?['expired_at'] != null;
                        return _DetailRow(
                          icon: Icons.hourglass_bottom_outlined,
                          label: '剩余天数',
                          value: isExpired ? '已过期' : '$days 天',
                          valueColor: days <= 7
                              ? colorScheme.error
                              : colorScheme.onSurface,
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ---- Traffic Usage Card ----
                _SectionCard(
                  icon: Icons.data_usage_rounded,
                  title: '流量使用',
                  colorScheme: colorScheme,
                  child: Builder(builder: (_) {
                    final u = _parseIntSafe(userInfo?['u']);
                    final d = _parseIntSafe(userInfo?['d']);
                    final total = _parseIntSafe(userInfo?['transfer_enable']);
                    final used = u + d;
                    final percent =
                        total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
                    final isHigh = percent >= 0.8;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_formatBytes(used)} / ${_formatBytes(total)}',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isHigh
                                    ? colorScheme.errorContainer
                                    : const Color(0xFF28A745)
                                        .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(percent * 100).toStringAsFixed(1)}%',
                                style: textTheme.labelSmall?.copyWith(
                                  color: isHigh
                                      ? colorScheme.onErrorContainer
                                      : const Color(0xFF28A745),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: percent,
                            minHeight: 10,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(
                              isHigh
                                  ? colorScheme.error
                                  : const Color(0xFF28A745),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _TrafficChip(
                                icon: Icons.arrow_upward_rounded,
                                label: '上传',
                                value: _formatBytes(u),
                                color: colorScheme.tertiary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TrafficChip(
                                icon: Icons.arrow_downward_rounded,
                                label: '下载',
                                value: _formatBytes(d),
                                color: colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 12),

                // ---- Quick Actions Card ----
                _SectionCard(
                  icon: Icons.bolt_rounded,
                  title: '快捷操作',
                  colorScheme: colorScheme,
                  child: Column(
                    children: [
                      // 商城仅 Xboard 后端启用；SSPanel 套餐购买走网页端
                      if (!isSSPanel) ...[
                        _ActionButton(
                          icon: Icons.store_rounded,
                          label: '商城',
                          subtitle: '浏览和购买套餐',
                          colorScheme: colorScheme,
                          onTap: () {
                            appController.toPage(PageLabel.store);
                          },
                        ),
                        Divider(
                            height: 1,
                            color:
                                colorScheme.outlineVariant.withOpacity(0.5)),
                      ],
                      _ActionButton(
                        icon: Icons.bar_chart_rounded,
                        label: '流量明细',
                        subtitle: '查看详细流量使用记录',
                        colorScheme: colorScheme,
                        onTap: () async {
                          final uri = Uri.parse(
                              isSSPanel ? '${xboardApi.webBaseUrl}/user'
                                  : 'https://cn3.yudijiasu.vip/#/traffic');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                      Divider(
                          height: 1,
                          color: colorScheme.outlineVariant.withOpacity(0.5)),
                      _ActionButton(
                        icon: Icons.refresh_rounded,
                        label: '刷新信息',
                        subtitle: '重新获取账户数据',
                        colorScheme: colorScheme,
                        onTap: () {
                          _refreshUserInfo();
                          globalState.showNotifier('正在刷新用户信息...');
                        },
                      ),
                      Divider(
                          height: 1,
                          color:
                              colorScheme.outlineVariant.withOpacity(0.5)),
                      _ActionButton(
                        icon: Icons.logout_rounded,
                        label: '退出登录',
                        subtitle: '退出当前账户',
                        colorScheme: colorScheme,
                        isDestructive: true,
                        onTap: _logout,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  int _parseIntSafe(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }
}

// ---------------------------------------------------------------------------
// Section card wrapper
// ---------------------------------------------------------------------------
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final ColorScheme colorScheme;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.colorScheme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail row (icon + label + value)
// ---------------------------------------------------------------------------
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? colorScheme.onSurface,
                ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Traffic upload/download chip
// ---------------------------------------------------------------------------
class _TrafficChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _TrafficChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick action button
// ---------------------------------------------------------------------------
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.colorScheme,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = isDestructive ? colorScheme.error : colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive
                    ? colorScheme.errorContainer
                    : colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isDestructive
                    ? colorScheme.onErrorContainer
                    : colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: fgColor,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
