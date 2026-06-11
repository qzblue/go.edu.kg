import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/xboard_api.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class OrdersView extends StatefulWidget {
  final VoidCallback? onOrderPaid;

  const OrdersView({super.key, this.onOrderPaid});

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> {
  List<dynamic> _orders = [];
  bool _loading = true;

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

  String _formatPrice(dynamic price) {
    if (price == null) return '¥0.00';
    final p = price is num ? price : num.tryParse(price.toString()) ?? 0;
    return '¥${(p / 100).toStringAsFixed(2)}';
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final ts = timestamp is int
        ? timestamp
        : int.tryParse(timestamp.toString()) ?? 0;
    if (ts <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatPeriod(dynamic period) {
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

  Future<void> _payOrder(Map<String, dynamic> order) async {
    final tradeNo = order['trade_no']?.toString();
    if (tradeNo == null) return;

    // 获取支付方式
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

      // 选择支付方式
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
                  title: Text(method['name']?.toString() ?? '支付方式 ${i + 1}'),
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

      // 发起支付
      final checkoutResult = await xboardApi.checkout(
        tradeNo,
        selected['id'] as int,
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
        // 打开浏览器支付
        final uri = Uri.parse(payUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          // 支付后弹出提示，等用户确认已支付
          if (mounted) {
            final paid = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('支付确认'),
                content: const Text('请在浏览器中完成支付，支付完成后点击"已完成支付"。'),
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
              // 检查订单状态
              try {
                await xboardApi.checkOrder(tradeNo);
              } catch (_) {}
              await _fetchOrders();
              // 自动获取订阅并添加配置
              await _autoFetchSubscribe();
            }
          }
        } else {
          globalState.showNotifier('无法打开支付链接');
        }
      } else {
        // 可能是余额支付等直接完成的
        globalState.showNotifier(checkoutResult['message']?.toString() ?? '支付处理中');
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的订单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOrders,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('暂无订单'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index] as Map<String, dynamic>;
                    final status = order['status'];
                    final isPending = status == 0;
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
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status, colorScheme)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
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
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  _formatPeriod(order['period']),
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
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(order['created_at']),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                            if (isPending) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _cancelOrder(order),
                                      child: const Text('取消订单'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () => _payOrder(order),
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
