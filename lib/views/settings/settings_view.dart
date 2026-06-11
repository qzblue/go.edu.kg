import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/about.dart';
import 'package:fl_clash/views/access.dart';
import 'package:fl_clash/views/application_setting.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/views/config/config.dart';
import 'package:fl_clash/views/hotkey.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' show dirname, join;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/advanced.dart';
import '../developer.dart';
import '../theme.dart';

const _settingsStoreKey = PageStorageKey<String>('settings');

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  bool _subAutoUpdate = true;
  int _subUpdateIntervalDays = 3;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionSettings();
  }

  Future<void> _loadSubscriptionSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _subAutoUpdate = prefs.getBool('sub_auto_update') ?? true;
      _subUpdateIntervalDays = prefs.getInt('sub_update_interval_days') ?? 3;
      _prefsLoaded = true;
    });
  }

  Future<void> _setSubAutoUpdate(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sub_auto_update', value);
    setState(() {
      _subAutoUpdate = value;
    });
  }

  Future<void> _setSubUpdateIntervalDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sub_update_interval_days', days);
    setState(() {
      _subUpdateIntervalDays = days;
    });
  }

  void _showUpdateLog(BuildContext context) {
    final profiles = ref.read(profilesProvider);
    globalState.showCommonDialog(
      context: context,
      child: CommonDialog(
        title: '更新日志',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
        child: profiles.isEmpty
            ? const Text('暂无配置文件')
            : ListView(
                shrinkWrap: true,
                children: profiles
                    .map(
                      (p) => ListTile(
                        title: Text(p.label.isEmpty ? '未命名' : p.label),
                        subtitle: Text(
                          p.lastUpdateDate != null
                              ? DateFormat('yyyy-MM-dd HH:mm:ss')
                                  .format(p.lastUpdateDate!)
                              : '从未更新',
                        ),
                        trailing: const Icon(Icons.update),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }

  Widget _buildNavigationMenuItem(NavigationItem navigationItem) {
    return ListItem.open(
      leading: navigationItem.icon,
      title: Text(Intl.message(navigationItem.label.name)),
      subtitle: navigationItem.description != null
          ? Text(Intl.message(navigationItem.description!))
          : null,
      delegate: OpenDelegate(widget: navigationItem.builder(context)),
    );
  }

  Widget _buildNavigationMenu(List<NavigationItem> navigationItems) {
    return Column(
      children: [
        for (final navigationItem in navigationItems) ...[
          _buildNavigationMenuItem(navigationItem),
          navigationItems.last != navigationItem
              ? const Divider(height: 0)
              : Container(),
        ],
      ],
    );
  }

  List<Widget> _getSubscriptionSection() {
    if (!_prefsLoaded) return [];

    final intervalOptions = <int, String>{
      1: '1天',
      2: '2天',
      3: '3天',
      5: '5天',
      7: '7天',
    };

    return generateSection(
      title: '订阅设置',
      items: [
        ListItem(
          leading: const Icon(Icons.sync),
          title: const Text('自动更新订阅'),
          subtitle: Text(_subAutoUpdate ? '已开启' : '已关闭'),
          trailing: Switch(
            value: _subAutoUpdate,
            onChanged: (value) => _setSubAutoUpdate(value),
          ),
          onTap: () => _setSubAutoUpdate(!_subAutoUpdate),
        ),
        ListItem<int>.options(
          leading: const Icon(Icons.schedule),
          title: const Text('更新间隔'),
          subtitle: Text(intervalOptions[_subUpdateIntervalDays] ?? '3天'),
          delegate: OptionsDelegate(
            title: '更新间隔',
            options: intervalOptions.keys.toList(),
            onChanged: (int? days) {
              if (days != null) _setSubUpdateIntervalDays(days);
            },
            textBuilder: (days) => intervalOptions[days] ?? '$days天',
            value: _subUpdateIntervalDays,
          ),
        ),
        ListItem(
          leading: const Icon(Icons.history),
          title: const Text('更新日志'),
          subtitle: const Text('查看各配置文件的最近更新时间'),
          onTap: () => _showUpdateLog(context),
        ),
      ],
    );
  }

  List<Widget> _getSettingList() {
    return generateSection(
      title: context.appLocalizations.settings,
      items: [
        const _ThemeItem(),
        if (system.isDesktop) const _HotkeyItem(),
        if (system.isWindows) const _LoopbackItem(),
        if (system.isAndroid) const _AccessItem(),
        const _ConfigItem(),
        const _AdvancedConfigItem(),
        const _SettingItem(),
      ],
    );
  }

  List<Widget> _getOtherList(bool enableDeveloperMode) {
    return generateSection(
      title: context.appLocalizations.other,
      items: [
        const _DisclaimerItem(),
        if (enableDeveloperMode) const _DeveloperItem(),
        const _InfoItem(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm2 = ref.watch(
      appSettingProvider.select(
        (state) => VM2(state.locale, state.developerMode),
      ),
    );
    final items = [
      ..._getSubscriptionSection(),
      Consumer(
        builder: (_, ref, _) {
          final state = ref.watch(moreToolsSelectorStateProvider);
          if (state.navigationItems.isEmpty) {
            return Container();
          }
          return Column(
            children: [
              ListHeader(title: context.appLocalizations.more),
              _buildNavigationMenu(state.navigationItems),
            ],
          );
        },
      ),
      ..._getSettingList(),
      ..._getOtherList(vm2.b),
    ];
    return CommonScaffold(
      title: '设置',
      body: ListView.builder(
        key: _settingsStoreKey,
        itemCount: items.length,
        itemBuilder: (_, index) => items[index],
        padding: const EdgeInsets.only(bottom: 20),
      ),
    );
  }
}

class _ThemeItem extends StatelessWidget {
  const _ThemeItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.style),
      title: Text(context.appLocalizations.theme),
      subtitle: Text(context.appLocalizations.themeDesc),
      delegate: OpenDelegate(widget: const ThemeView()),
    );
  }
}

class _HotkeyItem extends StatelessWidget {
  const _HotkeyItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.keyboard),
      title: Text(context.appLocalizations.hotkeyManagement),
      subtitle: Text(context.appLocalizations.hotkeyManagementDesc),
      delegate: OpenDelegate(widget: const HotKeyView()),
    );
  }
}

class _LoopbackItem extends StatelessWidget {
  const _LoopbackItem();

  @override
  Widget build(BuildContext context) {
    return ListItem(
      leading: const Icon(Icons.lock),
      title: Text(context.appLocalizations.loopback),
      subtitle: Text(context.appLocalizations.loopbackDesc),
      onTap: () {
        windows?.runas(
          '"${join(dirname(Platform.resolvedExecutable), "EnableLoopback.exe")}"',
          '',
        );
      },
    );
  }
}

class _AccessItem extends StatelessWidget {
  const _AccessItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.view_list),
      title: Text(context.appLocalizations.accessControl),
      subtitle: Text(context.appLocalizations.accessControlDesc),
      delegate: OpenDelegate(widget: const AccessView()),
    );
  }
}

class _ConfigItem extends StatelessWidget {
  const _ConfigItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.edit),
      title: Text(context.appLocalizations.basicConfig),
      subtitle: Text(context.appLocalizations.basicConfigDesc),
      delegate: OpenDelegate(widget: const ConfigView()),
    );
  }
}

class _AdvancedConfigItem extends StatelessWidget {
  const _AdvancedConfigItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.build),
      title: Text(context.appLocalizations.advancedConfig),
      subtitle: Text(context.appLocalizations.advancedConfigDesc),
      delegate: OpenDelegate(widget: const AdvancedConfigView()),
    );
  }
}

class _SettingItem extends StatelessWidget {
  const _SettingItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.settings),
      title: Text(context.appLocalizations.application),
      subtitle: Text(context.appLocalizations.applicationDesc),
      delegate: OpenDelegate(widget: const ApplicationSettingView()),
    );
  }
}

class _DisclaimerItem extends StatelessWidget {
  const _DisclaimerItem();

  @override
  Widget build(BuildContext context) {
    return ListItem(
      leading: const Icon(Icons.gavel),
      title: Text(context.appLocalizations.disclaimer),
      onTap: () async {
        final isDisclaimerAccepted = await appController.showDisclaimer();
        if (!isDisclaimerAccepted) {
          appController.handleExit();
        }
      },
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.info),
      title: Text(context.appLocalizations.about),
      delegate: OpenDelegate(widget: const AboutView()),
    );
  }
}

class _DeveloperItem extends StatelessWidget {
  const _DeveloperItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.developer_board),
      title: Text(context.appLocalizations.developerMode),
      delegate: OpenDelegate(widget: const DeveloperView()),
    );
  }
}
