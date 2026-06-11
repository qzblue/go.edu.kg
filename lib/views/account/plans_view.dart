import 'package:dio/dio.dart';
import 'package:fl_clash/common/xboard_api.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/account/orders_view.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PlansView extends StatefulWidget {
  final VoidCallback? onPlanPurchased;

  const PlansView({super.key, this.onPlanPurchased});

  @override
  State<PlansView> createState() => _PlansViewState();
}

class _PlansViewState extends State<PlansView> {
  List<dynamic> _plans = [];
  bool _loading = true;

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

  String _formatPrice(dynamic price) {
    if (price == null) return '免费';
    final p = price is num ? price : num.tryParse(price.toString()) ?? 0;
    return '¥${(p / 100).toStringAsFixed(2)}';
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
    return '${size.toStringAsFixed(0)} ${units[i]}';
  }

  // 返回 (价格, 周期标签)，找到第一个非空的价格
  (dynamic, String)? _getFirstAvailablePrice(Map<String, dynamic> plan) {
    const priceKeys = [
      ('month_price', '月'),
      ('quarter_price', '季'),
      ('half_year_price', '半年'),
      ('year_price', '年'),
      ('two_year_price', '两年'),
      ('three_year_price', '三年'),
      ('onetime_price', '次'),
    ];
    for (final (key, label) in priceKeys) {
      if (plan[key] != null) return (plan[key], label);
    }
    return null;
  }

  void _showPlanDetail(Map<String, dynamic> plan) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PlanDetailPage(
          plan: plan,
          onPlanPurchased: widget.onPlanPurchased,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('套餐购买')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? const Center(child: Text('暂无可用套餐'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _plans.length,
                  itemBuilder: (context, index) {
                    final plan = _plans[index] as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showPlanDetail(plan),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      plan['name']?.toString() ?? '未知套餐',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Builder(builder: (_) {
                                    final priceInfo = _getFirstAvailablePrice(plan);
                                    if (priceInfo == null) return const SizedBox.shrink();
                                    return Text(
                                      '${_formatPrice(priceInfo.$1)}/${priceInfo.$2}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    );
                                  }),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '流量: ${_formatBytes(plan['transfer_enable'])}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '点击查看详情并购买',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// HTML 实体解码
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
      .replaceAll('&mdash;', '—')
      .replaceAll('&ndash;', '–')
      .replaceAll('&bull;', '•')
      .replaceAll('&copy;', '©')
      .replaceAll('&reg;', '®')
      .replaceAll('&trade;', '™')
      .replaceAll('&times;', '×')
      .replaceAll('&divide;', '÷')
      .replaceAll('&laquo;', '«')
      .replaceAll('&raquo;', '»')
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
        final code = int.tryParse(m.group(1)!);
        return code != null ? String.fromCharCode(code) : m.group(0)!;
      })
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
        final code = int.tryParse(m.group(1)!, radix: 16);
        return code != null ? String.fromCharCode(code) : m.group(0)!;
      });
}

// 简单的 HTML 转 Widget 方法
List<InlineSpan> _parseHtmlToSpans(String html) {
  final spans = <InlineSpan>[];
  String text = html;
  // 替换常见 HTML 标签为文本
  text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
  text = text.replaceAll(RegExp(r'</div>'), '\n');
  text = text.replaceAll(RegExp(r'</p>'), '\n');
  text = text.replaceAll(RegExp(r'</li>'), '\n');
  text = text.replaceAll(RegExp(r'<li[^>]*>'), '  • ');
  text = text.replaceAll(RegExp(r'</h[1-6]>'), '\n');

  // 处理加粗
  final parts = text.split(RegExp(r'</?(?:strong|b)>'));
  for (int i = 0; i < parts.length; i++) {
    // 去除剩余 HTML 标签
    String clean = parts[i].replaceAll(RegExp(r'<[^>]*>'), '');
    // 解码 HTML 实体
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

Widget buildHtmlContent(String html, BuildContext context) {
  final spans = _parseHtmlToSpans(html);
  if (spans.isEmpty) return const SizedBox.shrink();
  return SelectableText.rich(
    TextSpan(
      style: Theme.of(context).textTheme.bodyMedium,
      children: spans,
    ),
  );
}

// 套餐周期定义
class _PlanPeriod {
  final String key;
  final String label;
  _PlanPeriod(this.key, this.label);
}

final _periods = [
  _PlanPeriod('month_price', '月付'),
  _PlanPeriod('quarter_price', '季付'),
  _PlanPeriod('half_year_price', '半年付'),
  _PlanPeriod('year_price', '年付'),
  _PlanPeriod('two_year_price', '两年付'),
  _PlanPeriod('three_year_price', '三年付'),
  _PlanPeriod('onetime_price', '一次性'),
];

class _PlanDetailPage extends StatefulWidget {
  final Map<String, dynamic> plan;
  final VoidCallback? onPlanPurchased;

  const _PlanDetailPage({required this.plan, this.onPlanPurchased});

  @override
  State<_PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends State<_PlanDetailPage> {
  String _selectedPeriod = 'month_price';
  final _couponController = TextEditingController();
  bool _purchasing = false;
  String? _couponMessage;

  List<_PlanPeriod> get _availablePeriods {
    return _periods
        .where((p) => widget.plan[p.key] != null)
        .toList();
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '免费';
    final p = price is num ? price : num.tryParse(price.toString()) ?? 0;
    return '¥${(p / 100).toStringAsFixed(2)}';
  }

  @override
  void initState() {
    super.initState();
    final available = _availablePeriods;
    if (available.isNotEmpty) {
      _selectedPeriod = available.first.key;
    }
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _checkCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    try {
      final result = await xboardApi.checkCoupon(
        code,
        widget.plan['id'] as int,
      );
      if (mounted) {
        setState(() {
          _couponMessage = result['message']?.toString() ?? '优惠券有效';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _couponMessage = '优惠券无效');
      }
    }
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
        if (mounted) {
          // 跳转到订单页
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => OrdersView(
                onOrderPaid: () {
                  widget.onPlanPurchased?.call();
                },
              ),
            ),
          );
        }
      } else {
        globalState.showNotifier(result['message']?.toString() ?? '创建订单失败');
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

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final colorScheme = Theme.of(context).colorScheme;
    final available = _availablePeriods;

    return Scaffold(
      appBar: AppBar(title: Text(plan['name']?.toString() ?? '套餐详情')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 套餐说明（HTML内容）
            if (plan['content'] != null && plan['content'].toString().isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '套餐说明',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      buildHtmlContent(plan['content'].toString(), context),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // 选择周期
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择周期',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
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
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 优惠券
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '优惠券',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
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
                            ),
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
                      Text(
                        _couponMessage!,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 购买按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _purchasing ? null : _purchase,
                child: _purchasing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        '立即购买 ${_formatPrice(plan[_selectedPeriod])}',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
