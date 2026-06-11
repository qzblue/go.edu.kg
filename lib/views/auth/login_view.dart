import 'dart:io';

import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/xboard_api.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/auth/register_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

// iOS 风格调色板
const _accent = Color(0xFF007AFF);
const _label = Color(0xFF1C1C1E);
const _secondary = Color(0xFF8E8E93);
const _hairline = Color(0xFFE5E5EA);

const _rememberKey = 'login_remember';
const _savedEmailKey = 'login_email';
const _savedPasswordKey = 'login_password';

class LoginView extends ConsumerStatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginView({super.key, required this.onLoginSuccess});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_rememberKey) ?? false;
    if (remember) {
      final email = prefs.getString(_savedEmailKey) ?? '';
      final password = prefs.getString(_savedPasswordKey) ?? '';
      if (mounted) {
        setState(() {
          _rememberMe = true;
          _emailController.text = email;
          _passwordController.text = password;
        });
      }
    }
  }

  Future<void> _saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool(_rememberKey, true);
      await prefs.setString(_savedEmailKey, email);
      await prefs.setString(_savedPasswordKey, password);
    } else {
      await prefs.remove(_rememberKey);
      await prefs.remove(_savedEmailKey);
      await prefs.remove(_savedPasswordKey);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      globalState.showNotifier('请输入邮箱和密码');
      return;
    }
    setState(() => _loading = true);
    try {
      // login() 内部已完成凭证持久化，统一返回 {success, message}
      final result = await xboardApi.login(email, password);
      if (result['success'] == true) {
        await _saveCredentials(email, password);
        if (mounted) widget.onLoginSuccess();
      } else {
        globalState.showNotifier(result['message']?.toString() ?? '登录失败');
      }
    } catch (e) {
      globalState.showNotifier('登录失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterView(onRegisterSuccess: widget.onLoginSuccess),
      ),
    );
  }

  /// 邀请制说明（iOS 原生弹窗）
  void _showInviteInfo(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('关于注册'),
        content: const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            '本产品由在美华人自发组建的协会搭建，是专为短期回国的在美华人提供的'
            '联网工具。\n\n'
            '目前采用协会内部邀请制度，暂不对外公开注册与销售。'
            '如需账号，请通过协会内部邀请获取。',
            style: TextStyle(fontSize: 13, height: 1.45),
            textAlign: TextAlign.start,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: Stack(
        children: [
          // 极淡的纵向背景渐变（iOS 质感，非高饱和）
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFFEDF0F5)],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 56),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/icon.png',
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        appName,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: _label,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '欢迎回来，登录以继续',
                      style: TextStyle(fontSize: 15, color: _secondary),
                    ),
                    const SizedBox(height: 36),
                    // iOS 分组式输入框
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _hairline),
                      ),
                      child: Column(
                        children: [
                          _iosField(
                            controller: _emailController,
                            hint: '邮箱',
                            icon: CupertinoIcons.mail,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 48),
                            child: Divider(
                                height: 1, thickness: 1, color: _hairline),
                          ),
                          _iosField(
                            controller: _passwordController,
                            hint: '密码',
                            icon: CupertinoIcons.lock,
                            obscure: _obscurePassword,
                            suffix: GestureDetector(
                              onTap: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              child: Icon(
                                _obscurePassword
                                    ? CupertinoIcons.eye_slash
                                    : CupertinoIcons.eye,
                                size: 20,
                                color: _secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 记住账号密码（iOS 开关）
                    Row(
                      children: [
                        const Text(
                          '记住账号密码',
                          style: TextStyle(fontSize: 15, color: _label),
                        ),
                        const Spacer(),
                        CupertinoSwitch(
                          value: _rememberMe,
                          onChanged: (v) => setState(() => _rememberMe = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // 登录按钮（iOS 实心圆角）
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        borderRadius: BorderRadius.circular(14),
                        color: _accent,
                        disabledColor: _accent.withOpacity(0.5),
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const CupertinoActivityIndicator(
                                color: Colors.white)
                            : const Text(
                                '登录',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      // SSPanel 为邀请制：点击展示协会说明而非注册表单
                      onTap: () => isSSPanel
                          ? _showInviteInfo(context)
                          : _goToRegister(),
                      child: const Text(
                        '没有账号？注册',
                        style: TextStyle(color: _accent, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 顶部拖拽区（桌面端移动窗口）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 44,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
            ),
          ),
          // 右上角关闭（iOS 风格圆形按钮）
          Positioned(
            top: 14,
            right: 14,
            child: _CircleButton(
              icon: CupertinoIcons.xmark,
              onTap: () => exit(0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iosField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _secondary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 16, color: _label),
              cursorColor: _accent,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    const TextStyle(color: Color(0xFFB7B7BC), fontSize: 16),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 17),
              ),
              onSubmitted: (_) => _login(),
            ),
          ),
          if (suffix != null) ...[const SizedBox(width: 8), suffix],
        ],
      ),
    );
  }
}

/// iOS 风格的圆形浅底图标按钮
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 15, color: _secondary),
      ),
    );
  }
}
