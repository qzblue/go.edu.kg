import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/hotkey_manager.dart';
import 'package:fl_clash/manager/manager.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/xboard_api.dart';
import 'controller.dart';
import 'models/models.dart';
import 'pages/pages.dart';
import 'providers/auth.dart';
import 'providers/database.dart';
import 'views/auth/login_view.dart';
import 'views/account/plans_view.dart';

class Application extends ConsumerStatefulWidget {
  const Application({super.key});

  @override
  ConsumerState<Application> createState() => ApplicationState();
}

class ApplicationState extends ConsumerState<Application> {
  Timer? _autoUpdateProfilesTaskTimer;
  bool _preHasVpn = false;
  bool _appReady = false;
  bool _isFreshLogin = false;

  final _pageTransitionsTheme = const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: commonSharedXPageTransitions,
      TargetPlatform.windows: commonSharedXPageTransitions,
      TargetPlatform.linux: commonSharedXPageTransitions,
      TargetPlatform.macOS: commonSharedXPageTransitions,
    },
  );

  ColorScheme _getAppColorScheme({
    required Brightness brightness,
    int? primaryColor,
  }) {
    return ref.read(genColorSchemeProvider(brightness));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await xboardApi.loadToken();
      ref.read(authTokenProvider.notifier).set(xboardApi.token);
      if (xboardApi.isLoggedIn) {
        await _initApp();
      } else {
        // 未登录时也要显示窗口
        window?.show();
      }
    });
  }

  Future<void> _initApp() async {
    if (appController.isAttach) {
      if (!_appReady && mounted) setState(() => _appReady = true);
      return;
    }
    final currentContext = globalState.navigatorKey.currentContext;
    if (currentContext != null) {
      await appController.attach(currentContext, ref);
    } else {
      exit(0);
    }
    _autoUpdateProfilesTask();
    appController.initLink();
    app?.initShortcuts();
    window?.show();
    if (mounted) setState(() => _appReady = true);
    // attach 完成后检查用户套餐并获取订阅
    await _fetchUserInfoAndSubscribe();
  }

  Future<void> _fetchUserInfoAndSubscribe() async {
    try {
      // 先获取用户信息
      final userResult = await xboardApi.getUserInfo();
      Map<String, dynamic>? userInfo;
      if (userResult['data'] is Map) {
        userInfo = Map<String, dynamic>.from(userResult['data']);
        ref.read(userInfoProvider.notifier).set(userInfo);
      }

      // 检查是否有套餐
      final hasPlan = userInfo != null && userInfo['plan_id'] != null;

      if (!hasPlan) {
        // 没有套餐，弹出套餐购买页
        final ctx = globalState.navigatorKey.currentContext;
        if (ctx != null) {
          await Navigator.of(ctx).push(
            MaterialPageRoute(
              builder: (_) => PlansView(
                onPlanPurchased: () {
                  // 购买完成后重新获取订阅
                  _addSubscribeProfile();
                },
              ),
            ),
          );
        }
        return;
      }

      // 只在首次登录或无配置文件时才拉取订阅
      final profiles = ref.read(profilesProvider);
      if (_isFreshLogin || profiles.isEmpty) {
        await _addSubscribeProfile();
      }
      _isFreshLogin = false;
    } catch (e) {
      commonPrint.log('获取用户信息失败: $e');
    }
  }

  Future<void> _addSubscribeProfile() async {
    try {
      final subUrl = await xboardApi.fetchSubscribeUrl();
      commonPrint.log('订阅地址: $subUrl');
      if (subUrl != null && appController.isAttach) {
        // 直连下载订阅，跳过核心验证（避免 validateConfig 路径解析问题）
        final response = await request.getFileResponseForUrlDirect(subUrl);
        final disposition = response.headers.value('content-disposition');
        final userinfo = response.headers.value('subscription-userinfo');
        final bytes = response.data ?? Uint8List.fromList([]);

        final profiles = ref.read(profilesProvider);
        final existing = profiles.cast<Profile?>().firstWhere(
          (p) => p!.url == subUrl,
          orElse: () => null,
        );

        if (existing != null) {
          // 已存在，更新
          final profile = await existing
              .copyWith(
                subscriptionInfo: SubscriptionInfo.formHString(userinfo),
              )
              .saveFileDirect(bytes);
          appController.setProfileAndAutoApply(profile);
        } else {
          // 新增
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
          // 首次添加需要手动触发配置应用
          await appController.applyProfile(force: true);
        }
        commonPrint.log('订阅配置已添加/更新');
      }
    } catch (e) {
      commonPrint.log('获取订阅失败: $e');
    }
  }

  void _autoUpdateProfilesTask() {
    _autoUpdateProfilesTaskTimer = Timer(const Duration(minutes: 20), () async {
      await appController.autoUpdateProfiles();
      _autoUpdateProfilesTask();
    });
  }

  Widget _buildPlatformState({required Widget child}) {
    if (system.isDesktop) {
      return WindowManager(
        child: TrayManager(
          child: HotKeyManager(child: ProxyManager(child: child)),
        ),
      );
    }
    return AndroidManager(child: TileManager(child: child));
  }

  Widget _buildState({required Widget child}) {
    return AppStateManager(
      child: CoreManager(
        child: ConnectivityManager(
          onConnectivityChanged: (results) async {
            commonPrint.log('connectivityChanged ${results.toString()}');
            appController.updateLocalIp();
            final hasVpn = results.contains(ConnectivityResult.vpn);
            if (_preHasVpn == hasVpn) {
              appController.addCheckIp();
            }
            _preHasVpn = hasVpn;
          },
          child: child,
        ),
      ),
    );
  }

  Widget _buildPlatformApp({required Widget child}) {
    if (system.isDesktop) {
      return WindowHeaderContainer(child: child);
    }
    return VpnManager(child: child);
  }

  Widget _buildApp({required Widget child}) {
    return StatusManager(child: ThemeManager(child: child));
  }

  Widget _buildHome() {
    final loggedIn = ref.watch(isLoggedInProvider);
    if (_appReady && loggedIn) {
      return const HomePage();
    }
    return LoginView(
      onLoginSuccess: () {
        _isFreshLogin = true;
        ref.read(authTokenProvider.notifier).set(xboardApi.token);
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _initApp();
        });
      },
    );
  }

  @override
  Widget build(context) {
    return Consumer(
      builder: (_, ref, child) {
        final locale = ref.watch(
          appSettingProvider.select((state) => state.locale),
        );
        final themeProps = ref.watch(themeSettingProvider);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: globalState.navigatorKey,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          builder: (_, child) {
            if (!_appReady) {
              return AppEnvManager(child: child!);
            }
            return AppEnvManager(
              child: _buildApp(
                child: _buildPlatformState(
                  child: _buildState(child: _buildPlatformApp(child: child!)),
                ),
              ),
            );
          },
          scrollBehavior: BaseScrollBehavior(),
          title: appName,
          locale: utils.getLocaleForString(locale),
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          themeMode: themeProps.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            pageTransitionsTheme: _pageTransitionsTheme,
            colorScheme: _getAppColorScheme(
              brightness: Brightness.light,
              primaryColor: themeProps.primaryColor,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            pageTransitionsTheme: _pageTransitionsTheme,
            colorScheme: _getAppColorScheme(
              brightness: Brightness.dark,
              primaryColor: themeProps.primaryColor,
            ).toPureBlack(themeProps.pureBlack),
          ),
          home: _buildHome(),
        );
      },
    );
  }

  @override
  Future<void> dispose() async {
    linkManager.destroy();
    _autoUpdateProfilesTaskTimer?.cancel();
    await coreController.destroy();
    await appController.handleExit();
    super.dispose();
  }
}
