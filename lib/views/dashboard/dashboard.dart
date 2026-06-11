import 'dart:typed_data';
import 'dart:ui';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/views/proxies/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  // Returns an animation scoped to [begin..end] of the entrance timeline
  Animation<double> _interval(double begin, double end) => CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  Widget _enter(Widget child, double from, double to, {double slideY = 20}) {
    final anim = _interval(from, to);
    return AnimatedBuilder(
      animation: anim,
      child: child,
      builder: (_, w) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, slideY * (1 - anim.value)),
          child: w,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: appName,
      actions: [
        IconButton(
          icon: const Icon(Icons.support_agent),
          tooltip: '联系客服：evebrown810@gmail.com',
          onPressed: () => launchUrl(
            Uri.parse('mailto:evebrown810@gmail.com'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.language),
          tooltip: '官网',
          onPressed: () => launchUrl(
            Uri.parse('${xboardApi.webBaseUrl}/'),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
      body: Stack(
        children: [
          // Ambient gradient background
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1565C0).withOpacity(0.07),
                    Colors.transparent,
                    const Color(0xFF42A5F5).withOpacity(0.05),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                _enter(const _ModeToggle(), 0.0, 0.55),
                const Spacer(),
                _enter(const _PowerButton(), 0.1, 0.65, slideY: 28),
                const SizedBox(height: 10),
                _enter(const _ConnectionTime(), 0.2, 0.72),
                const SizedBox(height: 12),
                _enter(const _TrafficCard(), 0.28, 0.80),
                const Spacer(),
                _enter(const _NodeSelector(), 0.38, 1.0),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mode Toggle ───────────────────────────────────────────────────────────

class _ModeToggle extends ConsumerWidget {
  const _ModeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final cs = context.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          _ModeOption(
            label: '智能分流',
            subtitle: 'Rule',
            icon: Icons.alt_route_rounded,
            isSelected: mode == Mode.rule,
            onTap: () => appController.changeMode(Mode.rule),
            selectedGradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            ),
            selectedColor: const Color(0xFF1565C0),
          ),
          const SizedBox(width: 4),
          _ModeOption(
            label: '全局代理',
            subtitle: 'Global',
            icon: Icons.public_rounded,
            isSelected: mode == Mode.global,
            onTap: () => appController.changeMode(Mode.global),
            selectedGradient: const LinearGradient(
              colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
            ),
            selectedColor: const Color(0xFF6A1B9A),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Gradient? selectedGradient;

  const _ModeOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.selectedColor,
    this.selectedGradient,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: isSelected ? selectedGradient : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: selectedColor.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : cs.onSurfaceVariant.opacity50,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? Colors.white : cs.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? Colors.white.withOpacity(0.75)
                          : cs.onSurfaceVariant.opacity50,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Power Button ──────────────────────────────────────────────────────────

class _PowerButton extends ConsumerStatefulWidget {
  const _PowerButton();

  @override
  ConsumerState<_PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends ConsumerState<_PowerButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _rippleController;
  bool _isStart = false;

  @override
  void initState() {
    super.initState();
    _isStart = ref.read(isStartProvider);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    ref.listenManual(isStartProvider, (prev, next) {
      if (next != _isStart) {
        _isStart = next;
        _updatePulse();
      }
    }, fireImmediately: true);
  }

  void _updatePulse() {
    if (!mounted) return;
    final coreStatus = ref.read(coreStatusProvider);
    if (coreStatus == CoreStatus.connecting) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void _handleToggle() {
    _isStart = !_isStart;
    setState(() {});
    // Ensure system proxy is enabled when turning on
    if (_isStart) {
      final networkSetting = ref.read(networkSettingProvider);
      if (!networkSetting.systemProxy) {
        ref.read(networkSettingProvider.notifier).update(
          (state) => state.copyWith(systemProxy: true),
        );
      }
    }
    debouncer.call(FunctionTag.updateStatus, () {
      appController.updateStatus(_isStart, isInit: !ref.read(initProvider));
    }, duration: commonDuration);
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    final coreStatus = ref.watch(coreStatusProvider);
    final cs = context.colorScheme;

    final isConnected = coreStatus == CoreStatus.connected;
    final isConnecting = coreStatus == CoreStatus.connecting;

    if (isConnecting && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isConnecting && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    // Use _isStart for immediate visual feedback (before core status updates)
    final isOn = _isStart;

    final Color buttonColor;
    final Color iconColor;
    final Color glowColor;

    if (isOn && isConnected) {
      // Fully connected — bright green with glow
      buttonColor = const Color(0xFF4CAF50);
      iconColor = Colors.white;
      glowColor = const Color(0xFF4CAF50).withAlpha(100);
    } else if (isOn && isConnecting) {
      // Connecting — green pulse
      buttonColor = const Color(0xFF66BB6A);
      iconColor = Colors.white;
      glowColor = const Color(0xFF66BB6A).withAlpha(60);
    } else if (isOn) {
      // Toggled on but core hasn't reported yet — light green
      buttonColor = const Color(0xFF66BB6A);
      iconColor = Colors.white;
      glowColor = const Color(0xFF66BB6A).withAlpha(40);
    } else {
      // Off — gray
      buttonColor = Colors.grey.shade300;
      iconColor = Colors.grey.shade500;
      glowColor = Colors.transparent;
    }

    // Manage ripple
    if (isConnected) {
      if (!_rippleController.isAnimating) _rippleController.repeat();
    } else {
      if (_rippleController.isAnimating) {
        _rippleController.stop();
        _rippleController.reset();
      }
    }

    final button = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isOn
            ? (isConnected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [buttonColor, buttonColor.withOpacity(0.75)],
                  ))
            : null,
        color: isOn ? null : buttonColor,
        boxShadow: [
          if (isOn)
            BoxShadow(
              color: glowColor,
              blurRadius: isConnected ? 44 : 22,
              spreadRadius: isConnected ? 12 : 5,
            ),
          BoxShadow(
            color: isOn ? buttonColor.withAlpha(70) : Colors.black.withAlpha(18),
            blurRadius: isOn ? 18 : 8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isConnecting
              ? SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: iconColor,
                  ),
                )
              : Icon(
                  Icons.power_settings_new_rounded,
                  key: ValueKey(isConnected),
                  size: 54,
                  color: iconColor,
                ),
        ),
      ),
    );

    return GestureDetector(
      onTap: hasProfile ? _handleToggle : null,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = isConnecting ? _pulseAnimation.value : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple rings when connected
              if (isConnected) ...[
                _RippleRing(
                  controller: _rippleController,
                  phase: 0.0,
                  color: buttonColor,
                ),
                _RippleRing(
                  controller: _rippleController,
                  phase: 0.45,
                  color: buttonColor,
                ),
              ],
              button,
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Ripple Ring ───────────────────────────────────────────────────────────

class _RippleRing extends StatelessWidget {
  final AnimationController controller;
  final double phase;
  final Color color;

  const _RippleRing({
    required this.controller,
    required this.phase,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = ((controller.value + phase) % 1.0);
        final size = 130 + t * 90.0;
        final opacity = (1.0 - t) * 0.35;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(opacity),
              width: 2.5,
            ),
          ),
        );
      },
    );
  }
}

// ─── Connection Time ───────────────────────────────────────────────────────

class _ConnectionTime extends ConsumerStatefulWidget {
  const _ConnectionTime();

  @override
  ConsumerState<_ConnectionTime> createState() => _ConnectionTimeState();
}

class _ConnectionTimeState extends ConsumerState<_ConnectionTime>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathCtrl;
  late final Animation<double> _breathAnim;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _breathAnim = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runTime = ref.watch(runTimeProvider);
    final timeText = utils.getTimeText(runTime);
    final coreStatus = ref.watch(coreStatusProvider);
    final isStart = ref.watch(isStartProvider);
    final cs = context.colorScheme;

    final isConnected = isStart && coreStatus == CoreStatus.connected;

    // Drive breathing animation
    if (isConnected) {
      if (!_breathCtrl.isAnimating) _breathCtrl.repeat(reverse: true);
    } else {
      if (_breathCtrl.isAnimating) {
        _breathCtrl.stop();
        _breathCtrl.reset();
      }
    }

    final String statusLabel;
    final Color statusColor;

    if (!isStart) {
      statusLabel = '未连接';
      statusColor = cs.onSurfaceVariant.withOpacity(0.5);
    } else if (isConnected) {
      statusLabel = '已连接';
      statusColor = Colors.green.shade400;
    } else {
      statusLabel = '连接中...';
      statusColor = cs.primary;
    }

    return Column(
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 400),
          style: (context.textTheme.headlineMedium ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w300,
            letterSpacing: 4,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: isConnected ? Colors.green.shade400 : cs.onSurface,
          ),
          child: Text(timeText),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.25), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Breathing dot
              AnimatedBuilder(
                animation: _breathAnim,
                builder: (_, __) => Transform.scale(
                  scale: isConnected ? _breathAnim.value : 1.0,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                      boxShadow: isConnected
                          ? [
                              BoxShadow(
                                color: statusColor.withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: context.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Traffic Card ──────────────────────────────────────────────────────────

class _TrafficCard extends ConsumerWidget {
  const _TrafficCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traffics = ref.watch(trafficsProvider);
    final totalTraffic = ref.watch(totalTrafficProvider);
    final cs = context.colorScheme;
    final last = traffics.list.isEmpty ? Traffic() : traffics.list.last;

    const upColor = Color(0xFF1565C0);
    final downColor = Colors.green.shade500;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerLow,
            const Color(0xFF1565C0).withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          // Upload chip
          Expanded(
            child: _SpeedChip(
              icon: Icons.arrow_upward_rounded,
              label: '上传',
              speed: '${last.up.traffic.show}/s',
              total: totalTraffic.up.traffic.show,
              color: upColor,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: cs.outlineVariant.withOpacity(0.3),
          ),
          // Download chip
          Expanded(
            child: _SpeedChip(
              icon: Icons.arrow_downward_rounded,
              label: '下载',
              speed: '${last.down.traffic.show}/s',
              total: totalTraffic.down.traffic.show,
              color: downColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String speed;
  final String total;
  final Color color;

  const _SpeedChip({
    required this.icon,
    required this.label,
    required this.speed,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                speed,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '总计 $total',
                style: context.textTheme.labelSmall?.copyWith(
                  color: color.withOpacity(0.6),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Node Selector ─────────────────────────────────────────────────────────

// 自动选择分组的 now 拿不到时，按已测延迟挑选最低延迟节点作为展示回退
String? _lowestDelayNode(WidgetRef ref, Group group) {
  String? best;
  int? bestDelay;
  for (final p in group.all) {
    if (!_isUserSelectableProxy(p)) continue;
    if (p.type == 'URLTest') continue;
    final d = ref.watch(getDelayProvider(proxyName: p.name));
    if (d == null || d <= 0) continue;
    if (bestDelay == null || d < bestDelay) {
      bestDelay = d;
      best = p.name;
    }
  }
  return best;
}

class _NodeSelector extends ConsumerWidget {
  const _NodeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsState = ref.watch(currentGroupsStateProvider);
    final selectedMap = ref.watch(selectedMapProvider);
    final cs = context.colorScheme;
    final groups = groupsState.value;

    if (groups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cs.outlineVariant.withAlpha(40),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.dns_rounded, color: cs.onSurfaceVariant.opacity50, size: 22),
            const SizedBox(width: 12),
            Text(
              '暂无可用节点',
              style: context.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant.opacity50,
              ),
            ),
          ],
        ),
      );
    }

    // Use the first Selector-type group as the primary proxy group
    final selectorGroups = groups.where((g) => g.type == GroupType.Selector).toList();
    final primaryGroup = selectorGroups.isNotEmpty ? selectorGroups.first : groups.first;
    // currentGroupsStateProvider 会把 now 抹成空串（见 providers/state.dart），
    // 所以这里改读原始 groupsProvider 拿核心真实的 now（自动选择实测选中的节点）。
    final rawGroups = ref.watch(groupsProvider);
    String rawNow(String groupName) {
      for (final g in rawGroups) {
        if (g.name == groupName) return g.realNow;
      }
      return '';
    }

    // directSel: 用户对主选择组的显式选择（可能为空）。
    final directSel = selectedMap[primaryGroup.name];
    final primaryNow = directSel ?? rawNow(primaryGroup.name);

    // 找出作为主选择组直接成员的"自动选择"(URLTest) 分组
    final autoMembers = <Group>[
      for (final g in groups)
        if (g.type == GroupType.URLTest &&
            primaryGroup.all.any((p) => p.name == g.name))
          g,
    ];

    // 判断当前是否处于"自动选择"：主组直接选中的就是某个 URLTest 分组
    Group? activeAuto;
    for (final g in autoMembers) {
      if (g.name == primaryNow) {
        activeAuto = g;
        break;
      }
    }

    final String selectedName;
    final String delayTarget;
    if (activeAuto != null) {
      // 自动选择：读核心真实 now；为空时退而按延迟自行挑最低延迟节点
      var autoNode = rawNow(activeAuto.name);
      if (autoNode.isEmpty) autoNode = _lowestDelayNode(ref, activeAuto) ?? '';
      selectedName = autoNode.isNotEmpty ? '自动选择 · $autoNode' : '自动选择';
      delayTarget = autoNode.isNotEmpty ? autoNode : primaryNow;
    } else {
      selectedName = primaryNow;
      delayTarget = selectedName;
    }
    final hasSelection = selectedName.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _NodeSelectionPage(
              groups: groups,
              selectedMap: selectedMap,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cs.outlineVariant.withAlpha(40),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withAlpha(80),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.dns_rounded,
                color: cs.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前节点',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.opacity60,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasSelection ? selectedName : '点击选择节点',
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: hasSelection ? cs.onSurface : cs.onSurfaceVariant.opacity50,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Delay test button (only when a node is selected)
            if (hasSelection && delayTarget.isNotEmpty)
              _DelayTestButton(proxyName: delayTarget),
            // Refresh button
            _RefreshButton(),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant.opacity50,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Delay Test Button ─────────────────────────────────────────────────────

const _delayTestUrl = 'https://www.gstatic.com/generate_204';

class _DelayTestButton extends StatefulWidget {
  final String proxyName;
  const _DelayTestButton({required this.proxyName});

  @override
  State<_DelayTestButton> createState() => _DelayTestButtonState();
}

class _DelayTestButtonState extends State<_DelayTestButton> {
  bool _testing = false;
  int? _delay; // null = 未测, <=0 = 超时, >0 = ms

  @override
  void didUpdateWidget(_DelayTestButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proxyName != widget.proxyName) {
      setState(() => _delay = null);
    }
  }

  Future<void> _test() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _delay = null;
    });
    try {
      final result = await coreController
          .getDelay(_delayTestUrl, widget.proxyName)
          .timeout(const Duration(seconds: 8));
      if (mounted) setState(() => _delay = result.value ?? -1);
    } catch (_) {
      if (mounted) setState(() => _delay = -1);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    if (_testing) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
          ),
        ),
      );
    }
    if (_delay != null) {
      final Color delayColor;
      final String delayText;
      if (_delay! <= 0) {
        delayColor = Colors.red;
        delayText = '超时';
      } else if (_delay! < 200) {
        delayColor = Colors.green;
        delayText = '${_delay}ms';
      } else if (_delay! < 500) {
        delayColor = Colors.orange;
        delayText = '${_delay}ms';
      } else {
        delayColor = Colors.red;
        delayText = '${_delay}ms';
      }
      return TextButton(
        onPressed: _test,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 6),
        ),
        child: Text(
          delayText,
          style: TextStyle(fontSize: 12, color: delayColor, fontWeight: FontWeight.w600),
        ),
      );
    }
    return IconButton(
      onPressed: _test,
      icon: Icon(Icons.network_check_rounded, color: cs.primary, size: 22),
      tooltip: '测试延迟',
      visualDensity: VisualDensity.compact,
    );
  }
}

// ─── Refresh Button ────────────────────────────────────────────────────────

class _RefreshButton extends ConsumerStatefulWidget {
  const _RefreshButton();

  @override
  ConsumerState<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends ConsumerState<_RefreshButton> {
  bool _refreshing = false;

  Future<void> _handleRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final subUrl = await xboardApi.fetchSubscribeUrl();
      if (subUrl != null && appController.isAttach) {
        final response = await request.getFileResponseForUrlDirect(subUrl);
        final disposition = response.headers.value('content-disposition');
        final userinfo = response.headers.value('subscription-userinfo');
        final bytes = response.data ?? Uint8List.fromList([]);
        final profiles = ref.read(profilesProvider);
        // 忽略 flag 参数比较 URL，避免 flag 变化导致找不到已有 profile
        String stripFlag(String u) {
          try {
            final uri = Uri.parse(u);
            final params = Map<String, String>.from(uri.queryParameters)..remove('flag');
            return uri.replace(queryParameters: params.isEmpty ? null : params).toString();
          } catch (_) {
            return u;
          }
        }
        final subUrlNorm = stripFlag(subUrl);
        final existing = profiles.cast<Profile?>().firstWhere(
          (p) => p!.url == subUrl || stripFlag(p!.url) == subUrlNorm,
          orElse: () => null,
        );
        if (existing != null) {
          final profile = await existing
              .copyWith(url: subUrl, subscriptionInfo: SubscriptionInfo.formHString(userinfo))
              .saveFileDirect(bytes);
          appController.setProfileAndAutoApply(profile);
        } else {
          final newProfile = Profile.normal(url: subUrl);
          final label = newProfile.label.takeFirstValid([
            utils.getFileNameForDisposition(disposition),
            newProfile.id.toString(),
          ]);
          final profile = await newProfile
              .copyWith(label: label, subscriptionInfo: SubscriptionInfo.formHString(userinfo))
              .saveFileDirect(bytes);
          ref.read(currentProfileIdProvider.notifier).value = profile.id;
          appController.setProfileAndAutoApply(profile);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('订阅刷新成功'),
              backgroundColor: Colors.green.shade400,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刷新失败: $e'),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _refreshing ? null : _handleRefresh,
      icon: _refreshing
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colorScheme.primary,
              ),
            )
          : Icon(
              Icons.refresh_rounded,
              color: context.colorScheme.primary,
              size: 22,
            ),
      tooltip: '刷新订阅',
      visualDensity: VisualDensity.compact,
    );
  }
}

// ─── Node Selection Helpers ────────────────────────────────────────────────

bool _isInfoNode(String name) {
  const patterns = ['剩余流量', '距离下次重置', '套餐到期', '到期', '流量重置', '套餐'];
  return patterns.any((p) => name.contains(p));
}

// Keep URLTest proxies (自动选择), filter out Fallback/other sub-group refs and info nodes
bool _isUserSelectableProxy(Proxy proxy) {
  if (_isInfoNode(proxy.name)) return false;
  // 排除内置策略节点（直连/拒绝/全局等），普通用户不需要
  const builtinNames = {
    'DIRECT', 'REJECT', 'REJECT-DROP', 'PASS', 'COMPATIBLE', 'GLOBAL',
  };
  if (builtinNames.contains(proxy.name.toUpperCase())) return false;
  // 排除子分组与直连/拒绝类型
  const rejectTypes = {
    'Fallback', 'Selector', 'LoadBalance', 'Relay', 'Direct', 'Reject',
  };
  return !rejectTypes.contains(proxy.type);
}

// ─── Node Selection Page ───────────────────────────────────────────────────

class _NodeSelectionPage extends ConsumerStatefulWidget {
  final List<Group> groups;
  final Map<String, String> selectedMap;

  const _NodeSelectionPage({
    required this.groups,
    required this.selectedMap,
  });

  @override
  ConsumerState<_NodeSelectionPage> createState() => _NodeSelectionPageState();
}

class _NodeSelectionPageState extends ConsumerState<_NodeSelectionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _refreshing = false;
  bool _testingAll = false;

  static const _regionFilters = <String, List<String>>{
    '全部': [],
    '台湾': ['台湾', 'TW', 'Taiwan'],
    '香港': ['香港', 'HK', 'Hong Kong'],
    '日本': ['日本', 'JP', 'Japan'],
    '新加坡': ['新加坡', 'SG', 'Singapore'],
    '美国': ['美国', 'US', 'United States'],
    '韩国': ['韩国', 'KR', 'Korea'],
    '其他': [],
  };

  List<String> get _tabLabels => _regionFilters.keys.toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    // 打开节点选择页时自动对全部节点测一次延迟
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleTestAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final subUrl = await xboardApi.fetchSubscribeUrl();
      if (subUrl != null && appController.isAttach) {
        final response = await request.getFileResponseForUrlDirect(subUrl);
        final disposition = response.headers.value('content-disposition');
        final userinfo = response.headers.value('subscription-userinfo');
        final bytes = response.data ?? Uint8List.fromList([]);
        final profiles = ref.read(profilesProvider);
        // 忽略 flag 参数比较 URL，避免 flag 变化导致找不到已有 profile
        String stripFlag(String u) {
          try {
            final uri = Uri.parse(u);
            final params = Map<String, String>.from(uri.queryParameters)..remove('flag');
            return uri.replace(queryParameters: params.isEmpty ? null : params).toString();
          } catch (_) {
            return u;
          }
        }

        final subUrlNorm = stripFlag(subUrl);
        final existing = profiles.cast<Profile?>().firstWhere(
          (p) => p!.url == subUrl || stripFlag(p!.url) == subUrlNorm,
          orElse: () => null,
        );
        if (existing != null) {
          final profile = await existing
              .copyWith(url: subUrl, subscriptionInfo: SubscriptionInfo.formHString(userinfo))
              .saveFileDirect(bytes);
          appController.setProfileAndAutoApply(profile);
        } else {
          final newProfile = Profile.normal(url: subUrl);
          final label = newProfile.label.takeFirstValid([
            utils.getFileNameForDisposition(disposition),
            newProfile.id.toString(),
          ]);
          final profile = await newProfile
              .copyWith(label: label, subscriptionInfo: SubscriptionInfo.formHString(userinfo))
              .saveFileDirect(bytes);
          ref.read(currentProfileIdProvider.notifier).value = profile.id;
          appController.setProfileAndAutoApply(profile);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('订阅刷新成功'),
            backgroundColor: Colors.green.shade400,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('刷新失败: $e'),
          backgroundColor: Colors.red.shade400,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _handleTestAll() async {
    if (_testingAll) return;
    setState(() => _testingAll = true);
    try {
      final groups = ref.read(currentGroupsStateProvider).value;
      final selectorGroups = groups.where((g) => g.type == GroupType.Selector).toList();
      final proxies = selectorGroups
          .expand((g) => g.all.where(_isUserSelectableProxy))
          .where((p) => p.type != 'URLTest')
          .toList();
      // 官方批量测速：结果写入 getDelayProvider，节点列表自动显示延迟
      await delayTest(proxies);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('测速完成'),
          backgroundColor: Colors.green.shade400,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _testingAll = false);
    }
  }

  List<Proxy> _filterProxies(List<Proxy> proxies, String region) {
    if (region == '全部') return proxies;
    if (region == '其他') {
      final allKeywords = _regionFilters.values
          .where((v) => v.isNotEmpty)
          .expand((v) => v)
          .toList();
      return proxies.where((p) {
        return !allKeywords.any(
          (kw) => p.name.toLowerCase().contains(kw.toLowerCase()),
        );
      }).toList();
    }
    final keywords = _regionFilters[region] ?? [];
    return proxies.where((p) {
      return keywords.any(
        (kw) => p.name.toLowerCase().contains(kw.toLowerCase()),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final groupsState = ref.watch(currentGroupsStateProvider);
    final selectedMap = ref.watch(selectedMapProvider);
    final groups = groupsState.value;

    // Only show Selector-type groups; hide URLTest/Fallback groups
    final mainGroups = groups.where((g) => g.type == GroupType.Selector).toList();
    // 只展示主分组（首个 Selector，与仪表盘"当前节点"一致），
    // 从而扁平化为单一节点列表，不再出现 GLOBAL/netflix 等分组分类
    final primaryGroups =
        mainGroups.isNotEmpty ? [mainGroups.first] : mainGroups;

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择节点'),
        actions: [
          IconButton(
            onPressed: _testingAll ? null : _handleTestAll,
            icon: _testingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check_rounded),
            tooltip: '测试全部延迟',
          ),
          IconButton(
            onPressed: _refreshing ? null : _handleRefresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: '刷新订阅',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
          labelStyle: context.textTheme.bodyMedium?.toSoftBold,
          unselectedLabelStyle: context.textTheme.bodyMedium,
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabLabels.map((region) {
          return _NodeListForRegion(
            region: region,
            groups: primaryGroups,
            selectedMap: selectedMap,
            filterProxies: _filterProxies,
          );
        }).toList(),
      ),
    );
  }
}

class _NodeListForRegion extends ConsumerWidget {
  final String region;
  final List<Group> groups;
  final Map<String, String> selectedMap;
  final List<Proxy> Function(List<Proxy>, String) filterProxies;

  const _NodeListForRegion({
    required this.region,
    required this.groups,
    required this.selectedMap,
    required this.filterProxies,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: groups.length,
      itemBuilder: (context, groupIndex) {
        final group = groups[groupIndex];
        // Pre-filter: remove info nodes and non-URLTest sub-group refs
        final preFiltered = group.all.where(_isUserSelectableProxy).toList();
        // Separate URLTest proxies (自动选择) from real proxies
        final autoSelectProxies = preFiltered.where((p) => p.type == 'URLTest').toList();
        final realProxies = filterProxies(
          preFiltered.where((p) => p.type != 'URLTest').toList(),
          region,
        );
        final currentSelected = selectedMap[group.name] ?? group.realNow;

        // In non-全部 tabs, hide if no real proxies match the region
        if (realProxies.isEmpty && region != '全部') return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (groups.length > 1) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
                child: Text(
                  group.name,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            // Show URLTest proxies (自动选择) with special icon, only in 全部 tab
            if (region == '全部')
              ...autoSelectProxies.map((proxy) {
                final isSelected = proxy.name == currentSelected;
                return _NodeTile(
                  name: '自动选择',
                  subtitle: '自动测速选择最优节点',
                  isSelected: isSelected,
                  icon: Icons.flash_auto_rounded,
                  onTap: () {
                    appController.changeProxyDebounce(group.name, proxy.name);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('已选择 自动选择'),
                        backgroundColor: Colors.green.shade400,
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                );
              }),
            ...realProxies.map((proxy) {
              final isSelected = proxy.name == currentSelected;
              return _NodeTile(
                name: proxy.name,
                subtitle: proxy.type,
                isSelected: isSelected,
                onTap: () {
                  appController.changeProxyDebounce(group.name, proxy.name);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已选择 ${proxy.name}'),
                      backgroundColor: Colors.green.shade400,
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                trailing: Consumer(
                  builder: (context, ref, _) {
                    final delay = ref.watch(
                      getDelayProvider(proxyName: proxy.name),
                    );
                    if (delay == null) return const SizedBox.shrink();
                    final Color delayColor;
                    if (delay == 0) {
                      delayColor = Colors.red;
                    } else if (delay < 200) {
                      delayColor = Colors.green;
                    } else if (delay < 500) {
                      delayColor = Colors.orange;
                    } else {
                      delayColor = Colors.red;
                    }
                    return Text(
                      delay == 0 ? '超时' : '${delay}ms',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: delayColor,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _NodeTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? trailing;

  const _NodeTile({
    required this.name,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected
            ? cs.primaryContainer.withAlpha(80)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? cs.primary.withAlpha(60)
                    : cs.outlineVariant.withAlpha(30),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: cs.primary),
                  const SizedBox(width: 12),
                ],
                if (isSelected && icon == null) ...[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? cs.primary : cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant.opacity50,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
