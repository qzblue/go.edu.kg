import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/xboard_api.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/auth.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

// ---------------------------------------------------------------------------
// Period definitions
// ---------------------------------------------------------------------------

class _PlanPeriod {
  final String key;
  final String label;
  const _PlanPeriod(this.key, this.label);
}

const _periods = [
  _PlanPeriod('month_price', '月付'),
  _PlanPeriod('quarter_price', '季付'),
  _PlanPeriod('half_year_price', '半年付'),
  _PlanPeriod('year_price', '年付'),
  _PlanPeriod('two_year_price', '两年付'),
  _PlanPeriod('three_year_price', '三年付'),
  _PlanPeriod('onetime_price', '一次性'),
];

// Period filter: key is the name keyword to match (empty = all)
const _periodFilterChips = [
  _PlanPeriod('', '全部'),
  _PlanPeriod('月', '月付'),
  _PlanPeriod('季', '季付'),
  _PlanPeriod('年', '年付'),
];

// Level filter: key is the name keyword to match (empty = all)
const _levelFilterChips = [
  _PlanPeriod('', '全部'),
  _PlanPeriod('高速', '高速'),
  _PlanPeriod('豪华', '豪华'),
];

// Safe int conversion helper
int? _toIntSafe(dynamic v) =>
    v == null ? null : (v is int ? v : int.tryParse(v.toString()));

// ---------------------------------------------------------------------------
// HTML helpers (mirrors plans_view.dart)
// ---------------------------------------------------------------------------

String _decodeHtmlEntities(String text) {
  return text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&hellip;', '...')
      .replaceAll('&mdash;', '\u2014')
      .replaceAll('&ndash;', '\u2013')
      .replaceAll('&bull;', '\u2022')
      .replaceAll('&copy;', '\u00A9')
      .replaceAll('&reg;', '\u00AE')
      .replaceAll('&trade;', '\u2122')
      .replaceAll('&times;', '\u00D7')
      .replaceAll('&divide;', '\u00F7')
      .replaceAll('&laquo;', '\u00AB')
      .replaceAll('&raquo;', '\u00BB')
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
        final code = int.tryParse(m.group(1)!);
        return code != null ? String.fromCharCode(code) : m.group(0)!;
      })
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
        final code = int.tryParse(m.group(1)!, radix: 16);
        return code != null ? String.fromCharCode(code) : m.group(0)!;
      });
}

List<InlineSpan> _parseHtmlToSpans(String html) {
  final spans = <InlineSpan>[];
  String text = html;
  text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
  text = text.replaceAll(RegExp(r'</div>'), '\n');
  text = text.replaceAll(RegExp(r'</p>'), '\n');
  text = text.replaceAll(RegExp(r'</li>'), '\n');
  text = text.replaceAll(RegExp(r'<li[^>]*>'), '  \u2022 ');
  text = text.replaceAll(RegExp(r'</h[1-6]>'), '\n');

  final parts = text.split(RegExp(r'</?(?:strong|b)>'));
  for (int i = 0; i < parts.length; i++) {
    String clean = parts[i].replaceAll(RegExp(r'<[^>]*>'), '');
    clean = _decodeHtmlEntities(clean);
    if (clean.isEmpty) continue;
    if (i % 2 == 1) {
      spans.add(TextSpan(
        text: clean,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
    } else {
      spans.add(TextSpan(text: clean));
    }
  }
  return spans;
}

Widget _buildHtmlContent(String html, BuildContext context) {
  final spans = _parseHtmlToSpans(html);
  if (spans.isEmpty) return const SizedBox.shrink();
  return SelectableText.rich(
    TextSpan(
      style: Theme.of(context).textTheme.bodyMedium,
      children: spans,
    ),
  );
}

// ---------------------------------------------------------------------------
// Format helpers
// ---------------------------------------------------------------------------

String _formatPrice(dynamic price) {
  if (price == null) return '免费';
  final p = price is num ? price : num.tryParse(price.toString()) ?? 0;
  return '\u00A5${(p / 100).toStringAsFixed(2)}';
}

String _formatBytes(dynamic bytes) {
  if (bytes == null) return '无限制';
  final b = bytes is int ? bytes : int.tryParse(bytes.toString()) ?? 0;
  if (b <= 0) return '无限制';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  int i = 0;
  double size = b.toDouble();
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }
  return '${size.toStringAsFixed(i >= 3 ? 1 : 0)} ${units[i]}';
}

String _formatStatus(dynamic status) {
  return switch (status) {
    0 => '待支付',
    1 => '开通中',
    2 => '已取消',
    3 => '已完成',
    4 => '已折抵',
    _ => '未知',
  };
}

Color _statusColor(dynamic status, ColorScheme cs) {
  return switch (status) {
    0 => cs.error,
    1 => cs.tertiary,
    3 => cs.primary,
    4 => cs.primary,
    _ => cs.onSurfaceVariant,
  };
}

String _formatTime(dynamic timestamp) {
  if (timestamp == null) return '';
  final ts =
      timestamp is int ? timestamp : int.tryParse(timestamp.toString()) ?? 0;
  if (ts <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String _formatPeriodLabel(dynamic period) {
  return switch (period?.toString()) {
    'month_price' => '月付',
    'quarter_price' => '季付',
    'half_year_price' => '半年付',
    'year_price' => '年付',
    'two_year_price' => '两年付',
    'three_year_price' => '三年付',
    'onetime_price' => '一次性',
    _ => period?.toString() ?? '',
  };
}

(dynamic, String)? _getFirstAvailablePrice(Map<String, dynamic> plan) {
  for (final p in _periods) {
    if (plan[p.key] != null) return (plan[p.key], p.label);
  }
  return null;
}

// ---------------------------------------------------------------------------
// StoreView  --  main tabbed page
// ---------------------------------------------------------------------------

class StoreView extends ConsumerStatefulWidget {
  final VoidCallback? onPlanPurchased;

  const StoreView({super.key, this.onPlanPurchased});

  @override
  ConsumerState<StoreView> createState() => _StoreViewState();
}

class _StoreViewState extends ConsumerState<StoreView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _orderTabKey = GlobalKey<_OrderHistoryTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Text(
          '套餐购买',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '套餐列表'),
            Tab(text: '订单记录'),
          ],
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorSize: TabBarIndicatorSize.label,
          dividerHeight: 0.5,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PlanListTab(
            onPlanPurchased: widget.onPlanPurchased,
            switchToOrders: () {
              _tabController.animateTo(1);
              Future.microtask(() => _orderTabKey.currentState?._fetchOrders());
            },
          ),
          _OrderHistoryTab(key: _orderTabKey, onOrderPaid: widget.onPlanPurchased),
        ],
      ),
    );
  }
}

// ===========================================================================
// Tab 1 : Plan List
// ===========================================================================

class _PlanListTab extends ConsumerStatefulWidget {
  final VoidCallback? onPlanPurchased;
  final VoidCallback? switchToOrders;

  const _PlanListTab({this.onPlanPurchased, this.switchToOrders});

  @override
  ConsumerState<_PlanListTab> createState() => _PlanListTabState();
}

class _PlanListTabState extends ConsumerState<_PlanListTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _plans = [];
  bool _loading = true;

  // Filters
  String _selectedPeriodFilter = 'all';
  String _selectedLevelFilter = 'all';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() => _loading = true);
    try {
      final result = await xboardApi.getPlans();
      if (result['data'] is List) {
        _plans = result['data'];
      }
    } catch (e) {
      globalState.showNotifier('获取套餐失败: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  List<dynamic> get _filteredPlans {
    return _plans.where((raw) {
      if (raw is! Map<String, dynamic>) return false;
      final name = raw['name']?.toString() ?? '';

      // Period filter: match name keyword (empty = all)
      if (_selectedPeriodFilter.isNotEmpty) {
        if (!name.contains(_selectedPeriodFilter)) return false;
      }

      // Level filter: match name keyword (empty = all)
      if (_selectedLevelFilter.isNotEmpty) {
        if (!name.contains(_selectedLevelFilter)) return false;
      }

      return true;
    }).toList();
  }

  void _openPurchaseFlow(Map<String, dynamic> plan) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PurchasePage(
          plan: plan,
          onPlanPurchased: widget.onPlanPurchased,
          switchToOrders: widget.switchToOrders,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    final userInfo = ref.watch(userInfoProvider);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredPlans;

    return RefreshIndicator(
      onRefresh: _fetchPlans,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ----- Balance card -----
          _BalanceCard(userInfo: userInfo),
          const SizedBox(height: 16),

          // ----- Period filter -----
          Text(
            '按周期筛选',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _periodFilterChips.map((pf) {
              final selected = _selectedPeriodFilter == pf.key;
              return FilterChip(
                label: Text(pf.label),
                selected: selected,
                onSelected: (_) {
                  setState(() => _selectedPeriodFilter = pf.key);
                },
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.onPrimaryContainer,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // ----- Level filter (fixed) -----
          Text(
            '按等级筛选',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _levelFilterChips.map((lf) {
              final selected = _selectedLevelFilter == lf.key;
              return FilterChip(
                label: Text(lf.label),
                selected: selected,
                onSelected: (_) {
                  setState(() => _selectedLevelFilter = lf.key);
                },
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.onPrimaryContainer,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // ----- Plan cards -----
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 48, color: colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      '暂无符合条件的套餐',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((raw) {
              final plan = raw as Map<String, dynamic>;
              return _PlanCard(
                plan: plan,
                onTap: () => _openPurchaseFlow(plan),
              );
            }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Balance card widget
// ---------------------------------------------------------------------------

class _BalanceCard extends StatelessWidget {
  final Map<String, dynamic>? userInfo;
  const _BalanceCard({required this.userInfo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final balance = userInfo?['balance'];
    final balanceStr = _formatPrice(balance ?? 0);

    return Card(
      color: colorScheme.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                color: colorScheme.onPrimaryContainer, size: 28),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '账户余额',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  balanceStr,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan card widget
// ---------------------------------------------------------------------------

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onTap;
  const _PlanCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final priceInfo = _getFirstAvailablePrice(plan);
    final name = plan['name']?.toString() ?? '未知套餐';
    final traffic = _formatBytes(plan['transfer_enable']);
    final content = plan['content']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: name + price
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (priceInfo != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_formatPrice(priceInfo.$1)}/${priceInfo.$2}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Traffic info
              Row(
                children: [
                  Icon(Icons.data_usage_outlined,
                      size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    '流量: $traffic',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),

              // Description snippet
              if (content != null && content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _decodeHtmlEntities(
                      content.replaceAll(RegExp(r'<[^>]*>'), '')),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                      ),
                ),
              ],

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '查看详情 \u203A',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Purchase page  (plan detail + period + coupon + payment)
// ===========================================================================

class _PurchasePage extends StatefulWidget {
  final Map<String, dynamic> plan;
  final VoidCallback? onPlanPurchased;
  final VoidCallback? switchToOrders;

  const _PurchasePage({
    required this.plan,
    this.onPlanPurchased,
    this.switchToOrders,
  });

  @override
  State<_PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<_PurchasePage> {
  late String _selectedPeriod;
  final _couponController = TextEditingController();
  String? _couponMessage;
  bool _couponValid = false;

  bool _purchasing = false;

  // Payment methods
  List<dynamic> _paymentMethods = [];
  bool _loadingMethods = true;
  int? _selectedMethodId;

  List<_PlanPeriod> get _availablePeriods {
    return _periods.where((p) => widget.plan[p.key] != null).toList();
  }

  @override
  void initState() {
    super.initState();
    final available = _availablePeriods;
    _selectedPeriod = available.isNotEmpty ? available.first.key : 'month_price';
    _fetchPaymentMethods();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _fetchPaymentMethods() async {
    try {
      final result = await xboardApi.getPaymentMethods();
      final methods = result['data'];
      if (methods is List) {
        _paymentMethods = methods;
        if (methods.isNotEmpty) {
          _selectedMethodId = _toIntSafe((methods.first as Map<String, dynamic>)['id']);
        }
      }
    } catch (e) {
      // silently fail; user will see empty list
    }
    if (mounted) setState(() => _loadingMethods = false);
  }

  Future<void> _checkCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    try {
      final result = await xboardApi.checkCoupon(
        code,
        _toIntSafe(widget.plan['id']) ?? 0,
      );
      if (mounted) {
        setState(() {
          _couponMessage = result['message']?.toString() ?? '优惠券有效';
          _couponValid = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _couponMessage = '优惠券无效';
          _couponValid = false;
        });
      }
    }
  }

  Future<void> _confirmAndPurchase() async {
    final plan = widget.plan;
    final periodLabel =
        _availablePeriods.firstWhere((p) => p.key == _selectedPeriod).label;
    final price = _formatPrice(plan[_selectedPeriod]);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认购买'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('套餐', plan['name']?.toString() ?? ''),
            _infoRow('周期', periodLabel),
            _infoRow('价格', price),
            if (_couponController.text.trim().isNotEmpty && _couponValid)
              _infoRow('优惠码', _couponController.text.trim()),
            _infoRow(
              '支付方式',
              _paymentMethods
                      .whereType<Map<String, dynamic>>()
                      .where((m) => m['id'] == _selectedMethodId)
                      .map((m) => m['name']?.toString() ?? '')
                      .firstOrNull ??
                  '',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认购买'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _purchase();
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Future<void> _purchase() async {
    setState(() => _purchasing = true);
    try {
      final data = <String, dynamic>{
        'plan_id': widget.plan['id'],
        'period': _selectedPeriod,
      };
      final coupon = _couponController.text.trim();
      if (coupon.isNotEmpty) {
        data['coupon_code'] = coupon;
      }
      final result = await xboardApi.createOrder(data);
      if (result['data'] != null) {
        globalState.showNotifier('订单创建成功');

        // Immediately try to pay with selected method
        final rawData = result['data'];
        String? tradeNo;
        if (rawData is Map) {
          tradeNo = rawData['trade_no']?.toString();
        } else if (rawData is String) {
          tradeNo = rawData;
        }
        if (tradeNo != null && _selectedMethodId != null) {
          await _initiatePayment(tradeNo);
        } else {
          // Fallback: go back and switch to orders tab
          if (mounted) {
            Navigator.of(context).pop();
            widget.switchToOrders?.call();
          }
        }
      } else {
        globalState.showNotifier(
            result['message']?.toString() ?? '创建订单失败');
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ?? '创建订单失败')
          : '网络错误: ${e.message}';
      globalState.showNotifier(msg.toString());
    } catch (e) {
      globalState.showNotifier('创建订单失败: $e');
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _initiatePayment(String tradeNo) async {
    try {
      final checkoutResult =
          await xboardApi.checkout(tradeNo, _selectedMethodId!);

      final checkoutData = checkoutResult['data'];
      String? payUrl;
      if (checkoutData is String) {
        payUrl = checkoutData;
      } else if (checkoutData is Map) {
        payUrl = checkoutData['url']?.toString() ??
            checkoutData['payment_url']?.toString();
      }

      if (payUrl != null && payUrl.isNotEmpty) {
        final uri = Uri.parse(payUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            final paid = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('支付确认'),
                content:
                    const Text('请在浏览器中完成支付，支付完成后点击"已完成支付"。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('已完成支付'),
                  ),
                ],
              ),
            );
            if (paid == true) {
              try {
                await xboardApi.checkOrder(tradeNo);
              } catch (_) {}
              await _autoFetchSubscribe();
            }
          }
        } else {
          globalState.showNotifier('无法打开支付链接');
        }
      } else {
        globalState
            .showNotifier(checkoutResult['message']?.toString() ?? '支付处理中');
        await _autoFetchSubscribe();
      }

      // Go back and switch to orders
      if (mounted) {
        Navigator.of(context).pop();
        widget.switchToOrders?.call();
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ?? '支付失败')
          : '网络错误: ${e.message}';
      globalState.showNotifier(msg.toString());
    } catch (e) {
      globalState.showNotifier('支付失败: $e');
    }
  }

  Future<void> _autoFetchSubscribe() async {
    try {
      final subUrl = await xboardApi.fetchSubscribeUrl();
      if (subUrl != null && appController.isAttach) {
        final response = await request.getFileResponseForUrlDirect(subUrl);
        final disposition = response.headers.value('content-disposition');
        final userinfo = response.headers.value('subscription-userinfo');
        final bytes = response.data ?? Uint8List.fromList([]);
        final newProfile = Profile.normal(url: subUrl);
        final label = newProfile.label.takeFirstValid([
          utils.getFileNameForDisposition(disposition),
          newProfile.id.toString(),
        ]);
        final profile = await newProfile
            .copyWith(
              label: label,
              subscriptionInfo: SubscriptionInfo.formHString(userinfo),
            )
            .saveFileDirect(bytes);
        appController.putProfile(profile);
        globalState.showNotifier('订阅配置已自动添加');
      } else {
        globalState.showNotifier('支付成功，请稍后刷新获取订阅');
      }
      widget.onPlanPurchased?.call();
    } catch (e) {
      commonPrint.log('自动获取订阅失败: $e');
      globalState.showNotifier('支付成功，自动获取订阅失败，请手动刷新');
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final colorScheme = Theme.of(context).colorScheme;
    final available = _availablePeriods;

    return Scaffold(
      appBar: AppBar(
        title: Text(plan['name']?.toString() ?? '套餐详情'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Plan description (HTML) --
            if (plan['content'] != null &&
                plan['content'].toString().isNotEmpty)
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.description_outlined,
                              size: 18, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            '套餐说明',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildHtmlContent(plan['content'].toString(), context),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // -- Select period --
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '选择周期',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: available.map((period) {
                        final selected = _selectedPeriod == period.key;
                        final price = _formatPrice(plan[period.key]);
                        return ChoiceChip(
                          label: Text('${period.label}\n$price'),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _selectedPeriod = period.key);
                          },
                          selectedColor: colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            color: selected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // -- Coupon --
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.confirmation_number_outlined,
                            size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '优惠券',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _couponController,
                            decoration: InputDecoration(
                              hintText: '输入优惠码（可选）',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            onChanged: (_) {
                              if (_couponMessage != null) {
                                setState(() {
                                  _couponMessage = null;
                                  _couponValid = false;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: _checkCoupon,
                          child: const Text('验证'),
                        ),
                      ],
                    ),
                    if (_couponMessage != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _couponValid
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            size: 16,
                            color: _couponValid
                                ? colorScheme.primary
                                : colorScheme.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _couponMessage!,
                              style: TextStyle(
                                color: _couponValid
                                    ? colorScheme.primary
                                    : colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // -- Payment method --
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payment_outlined,
                            size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '支付方式',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingMethods)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (_paymentMethods.isEmpty)
                      Text('暂无可用支付方式',
                          style: TextStyle(color: colorScheme.onSurfaceVariant))
                    else
                      ..._paymentMethods
                          .whereType<Map<String, dynamic>>()
                          .map((method) {
                        final id = _toIntSafe(method['id']);
                        final name =
                            method['name']?.toString() ?? '支付方式';
                        final isSelected = _selectedMethodId == id;
                        return RadioListTile<int>(
                          value: id ?? -1,
                          groupValue: _selectedMethodId ?? -1,
                          onChanged: (v) {
                            setState(() => _selectedMethodId = v);
                          },
                          title: Text(name),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          activeColor: colorScheme.primary,
                          selected: isSelected,
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // -- Purchase button --
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _purchasing || _selectedMethodId == null
                    ? null
                    : _confirmAndPurchase,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: _purchasing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        '立即购买 ${_formatPrice(plan[_selectedPeriod])}'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Tab 2 : Order History
// ===========================================================================

class _OrderHistoryTab extends StatefulWidget {
  final VoidCallback? onOrderPaid;
  const _OrderHistoryTab({super.key, this.onOrderPaid});

  @override
  State<_OrderHistoryTab> createState() => _OrderHistoryTabState();
}

class _OrderHistoryTabState extends State<_OrderHistoryTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _orders = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _loading = true);
    try {
      final result = await xboardApi.getOrders();
      if (result['data'] is List) {
        _orders = result['data'];
      }
    } catch (e) {
      globalState.showNotifier('获取订单失败: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _payOrder(Map<String, dynamic> order) async {
    final tradeNo = order['trade_no']?.toString();
    if (tradeNo == null) return;

    try {
      final methodsResult = await xboardApi.getPaymentMethods();
      final methods = methodsResult['data'];
      if (methods == null || (methods is List && methods.isEmpty)) {
        globalState.showNotifier('暂无可用支付方式');
        return;
      }

      List<dynamic> methodList;
      if (methods is List) {
        methodList = methods;
      } else {
        globalState.showNotifier('获取支付方式失败');
        return;
      }

      if (!mounted) return;

      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('选择支付方式'),
          content: SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: methodList.length,
              itemBuilder: (_, i) {
                final method = methodList[i] as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(Icons.payment),
                  title:
                      Text(method['name']?.toString() ?? '支付方式 ${i + 1}'),
                  onTap: () => Navigator.of(ctx).pop(method),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      );

      if (selected == null) return;

      final checkoutResult = await xboardApi.checkout(
        tradeNo,
        _toIntSafe(selected['id']) ?? 0,
      );

      final checkoutData = checkoutResult['data'];
      String? payUrl;
      if (checkoutData is String) {
        payUrl = checkoutData;
      } else if (checkoutData is Map) {
        payUrl = checkoutData['url']?.toString() ??
            checkoutData['payment_url']?.toString();
      }

      if (payUrl != null && payUrl.isNotEmpty) {
        final uri = Uri.parse(payUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            final paid = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('支付确认'),
                content:
                    const Text('请在浏览器中完成支付，支付完成后点击"已完成支付"。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('已完成支付'),
                  ),
                ],
              ),
            );
            if (paid == true) {
              try {
                await xboardApi.checkOrder(tradeNo);
              } catch (_) {}
              await _fetchOrders();
              await _autoFetchSubscribe();
            }
          }
        } else {
          globalState.showNotifier('无法打开支付链接');
        }
      } else {
        globalState.showNotifier(
            checkoutResult['message']?.toString() ?? '支付处理中');
        await _fetchOrders();
        await _autoFetchSubscribe();
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ?? '支付失败')
          : '网络错误: ${e.message}';
      globalState.showNotifier(msg.toString());
    } catch (e) {
      globalState.showNotifier('支付失败: $e');
    }
  }

  Future<void> _autoFetchSubscribe() async {
    try {
      final subUrl = await xboardApi.fetchSubscribeUrl();
      if (subUrl != null && appController.isAttach) {
        final response = await request.getFileResponseForUrlDirect(subUrl);
        final disposition = response.headers.value('content-disposition');
        final userinfo = response.headers.value('subscription-userinfo');
        final bytes = response.data ?? Uint8List.fromList([]);
        final newProfile = Profile.normal(url: subUrl);
        final label = newProfile.label.takeFirstValid([
          utils.getFileNameForDisposition(disposition),
          newProfile.id.toString(),
        ]);
        final profile = await newProfile
            .copyWith(
              label: label,
              subscriptionInfo: SubscriptionInfo.formHString(userinfo),
            )
            .saveFileDirect(bytes);
        appController.putProfile(profile);
        globalState.showNotifier('订阅配置已自动添加');
      } else {
        globalState.showNotifier('支付成功，请稍后刷新获取订阅');
      }
      widget.onOrderPaid?.call();
    } catch (e) {
      commonPrint.log('自动获取订阅失败: $e');
      globalState.showNotifier('支付成功，自动获取订阅失败，请手动刷新');
    }
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final tradeNo = order['trade_no']?.toString();
    if (tradeNo == null) return;
    final confirm = await globalState.showMessage(
      message: const TextSpan(text: '确定要取消此订单吗？'),
      title: '取消订单',
    );
    if (confirm != true) return;
    try {
      await xboardApi.cancelOrder(tradeNo);
      globalState.showNotifier('订单已取消');
      await _fetchOrders();
    } catch (e) {
      globalState.showNotifier('取消失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              '暂无订单',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _fetchOrders,
              child: const Text('刷新'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index] as Map<String, dynamic>;
          final status = order['status'];
          final isPending = status == 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0.5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: name + status badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order['plan']?['name']?.toString() ??
                              '订单 #${order['trade_no'] ?? index}',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor(status, colorScheme)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _formatStatus(status),
                          style: TextStyle(
                            fontSize: 12,
                            color: _statusColor(status, colorScheme),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Period + price
                  Row(
                    children: [
                      Icon(Icons.schedule_outlined,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        _formatPeriodLabel(order['period']),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        _formatPrice(order['total_amount']),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Timestamp
                  Row(
                    children: [
                      Icon(Icons.access_time_outlined,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(order['created_at']),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),

                  // Action buttons for pending orders
                  if (isPending) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _cancelOrder(order),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('取消订单'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _payOrder(order),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('去支付'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
