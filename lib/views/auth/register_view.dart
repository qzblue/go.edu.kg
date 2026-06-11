import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/xboard_api.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

const _emailWhitelist = [
  'qq.com',
  '163.com',
  'yahoo.com',
  'sina.com',
  '126.com',
  'outlook.com',
  'yeah.net',
  'foxmail.com',
];

class RegisterView extends ConsumerStatefulWidget {
  final VoidCallback onRegisterSuccess;

  const RegisterView({super.key, required this.onRegisterSuccess});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailCodeController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _loading = false;
  bool _sendingCode = false;
  bool _obscurePassword = true;
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailCodeController.dispose();
    _inviteCodeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  bool _validateEmailSuffix(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return false;
    return _emailWhitelist.contains(parts[1].toLowerCase());
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      globalState.showNotifier('请输入邮箱');
      return;
    }
    if (!_validateEmailSuffix(email)) {
      globalState.showNotifier('仅支持以下邮箱: ${_emailWhitelist.join(", ")}');
      return;
    }
    setState(() => _sendingCode = true);
    try {
      final result = await xboardApi.sendEmailVerify(email);
      if (result['status'] == 'success') {
        globalState.showNotifier('验证码已发送，请查收邮箱');
        if (mounted) setState(() => _countdown = 60);
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_countdown <= 1) {
            timer.cancel();
            if (mounted) setState(() => _countdown = 0);
          } else {
            if (mounted) setState(() => _countdown--);
          }
        });
      } else {
        globalState.showNotifier(result['message']?.toString() ?? '发送失败');
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ?? '发送失败')
          : '网络错误: ${e.message}';
      globalState.showNotifier(msg.toString());
    } catch (e) {
      globalState.showNotifier('发送失败: $e');
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final emailCode = _emailCodeController.text.trim();
    final inviteCode = _inviteCodeController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      globalState.showNotifier('请输入邮箱和密码');
      return;
    }
    if (!_validateEmailSuffix(email)) {
      globalState.showNotifier('仅支持以下邮箱: ${_emailWhitelist.join(", ")}');
      return;
    }
    if (emailCode.isEmpty) {
      globalState.showNotifier('请输入邮箱验证码');
      return;
    }
    if (password != confirmPassword) {
      globalState.showNotifier('两次输入的密码不一致');
      return;
    }
    setState(() => _loading = true);
    try {
      // register() 内部已完成凭证持久化，统一返回 {success, message}
      final result = await xboardApi.register(
        email: email,
        password: password,
        emailCode: emailCode,
        inviteCode: inviteCode.isEmpty ? null : inviteCode,
      );
      if (result['success'] == true) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        widget.onRegisterSuccess();
      } else {
        globalState.showNotifier(result['message']?.toString() ?? '注册失败');
      }
    } catch (e) {
      globalState.showNotifier('注册失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
              ),
            ),
          ),
          // Card content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/icon.png',
                        width: 64,
                        height: 64,
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '注册$appName',
                          maxLines: 1,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '支持邮箱: ${_emailWhitelist.join(", ")}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // 邮箱
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: '邮箱',
                          hintText: '请输入邮箱地址',
                          prefixIcon: const Icon(Icons.email_outlined),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // 邮箱验证码
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _emailCodeController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: '邮箱验证码',
                                hintText: '请输入验证码',
                                prefixIcon: const Icon(Icons.verified_outlined),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 56,
                            child: FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: (_sendingCode || _countdown > 0) ? null : _sendCode,
                              child: Text(
                                _countdown > 0 ? '${_countdown}s' : '发送验证码',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // 密码
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: '密码',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // 确认密码
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: '确认密码',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // 邀请码（可选）
                      TextField(
                        controller: _inviteCodeController,
                        decoration: InputDecoration(
                          labelText: '邀请码（可选）',
                          hintText: '如有邀请码请输入',
                          prefixIcon: const Icon(Icons.card_giftcard_outlined),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
                          ),
                        ),
                        onSubmitted: (_) => _register(),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: _loading
                                ? null
                                : const LinearGradient(
                                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                                  ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _loading ? Colors.grey[300] : Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _loading ? null : _register,
                            child: _loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text(
                                    '注册',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Drag area (title bar substitute) — lets user move window
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 48,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
            ),
          ),
          // Back button on gradient background
          Positioned(
            top: 12,
            left: 12,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: '返回',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // Close button on gradient background
          Positioned(
            top: 12,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: '关闭',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
