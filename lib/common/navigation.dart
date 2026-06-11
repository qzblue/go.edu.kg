import 'package:fl_clash/common/xboard_api.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/views.dart';
import 'package:flutter/material.dart';

class Navigation {
  static Navigation? _instance;

  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
  }) {
    return [
      NavigationItem(
        keep: false,
        icon: Icon(Icons.dashboard_rounded),
        label: PageLabel.dashboard,
        builder: (_) =>
            const DashboardView(key: GlobalObjectKey(PageLabel.dashboard)),
        modes: [NavigationItemMode.mobile, NavigationItemMode.desktop],
      ),
      NavigationItem(
        icon: Icon(Icons.account_circle_rounded),
        label: PageLabel.account,
        builder: (_) =>
            const AccountView(key: GlobalObjectKey(PageLabel.account)),
        modes: [NavigationItemMode.mobile, NavigationItemMode.desktop],
      ),
      // 商城仅在 Xboard 后端启用；SSPanel 套餐购买走网页端
      if (!isSSPanel)
        NavigationItem(
          icon: Icon(Icons.store_rounded),
          label: PageLabel.store,
          builder: (_) =>
              const StoreView(key: GlobalObjectKey(PageLabel.store)),
          modes: [NavigationItemMode.mobile, NavigationItemMode.desktop],
        ),
      NavigationItem(
        icon: Icon(Icons.cable_rounded),
        label: PageLabel.connections,
        builder: (_) =>
            const ConnectionsView(key: GlobalObjectKey(PageLabel.connections)),
        modes: [NavigationItemMode.mobile, NavigationItemMode.desktop],
      ),
      NavigationItem(
        icon: Icon(Icons.settings_rounded),
        label: PageLabel.settings,
        builder: (_) =>
            const SettingsView(key: GlobalObjectKey(PageLabel.settings)),
        modes: [NavigationItemMode.mobile, NavigationItemMode.desktop],
      ),
      // Legacy items kept for backward compatibility but hidden from nav
      NavigationItem(
        icon: const Icon(Icons.article),
        label: PageLabel.proxies,
        builder: (_) =>
            const ProxiesView(key: GlobalObjectKey(PageLabel.proxies)),
        modes: [],
      ),
      NavigationItem(
        icon: Icon(Icons.folder),
        label: PageLabel.profiles,
        builder: (_) =>
            const ProfilesView(key: GlobalObjectKey(PageLabel.profiles)),
        modes: [],
      ),
      NavigationItem(
        icon: Icon(Icons.view_timeline),
        label: PageLabel.requests,
        builder: (_) =>
            const RequestsView(key: GlobalObjectKey(PageLabel.requests)),
        modes: [],
      ),
      NavigationItem(
        icon: Icon(Icons.adb),
        label: PageLabel.logs,
        builder: (_) => const LogsView(key: GlobalObjectKey(PageLabel.logs)),
        modes: [],
      ),
      NavigationItem(
        icon: Icon(Icons.construction),
        label: PageLabel.tools,
        builder: (_) => const ToolsView(key: GlobalObjectKey(PageLabel.tools)),
        modes: [],
      ),
      NavigationItem(
        icon: Icon(Icons.storage),
        label: PageLabel.resources,
        builder: (_) =>
            const ResourcesView(key: GlobalObjectKey(PageLabel.resources)),
        modes: [],
      ),
    ];
  }

  Navigation._internal();

  factory Navigation() {
    _instance ??= Navigation._internal();
    return _instance!;
  }
}

final navigation = Navigation();
