import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/xboard_api.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/auth/register_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

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
      final result = await xboardApi.login(email, password);
      final data = result['data'];
      String? authData;
      if (data is Map) {
        authData = data['auth_data']?.toString();
      } else if (data is String) {
        authData = data;
      }
      if (authData != null && authData.isNotEmpty) {
        final token = authData.startsWith('Bearer ')
            ? authData.substring(7)
            : authData;
        await xboardApi.saveToken(token);
        await _saveCredentials(email, password);
        if (mounted) widget.onLoginSuccess();
      } else {
        globalState.showNotifier(result['message']?.toString() ?? '登录失败');
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ?? '网络错误')
          : '网络错误: ${e.message}';
      globalState.showNotifier(msg.toString());
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
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(32),
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
                        width: 80,
                        height: 80,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '雨滴云',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '登录以继续',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: '邮箱',
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
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 16),
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
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            activeColor: const Color(0xFF1565C0),
                            onChanged: (v) => setState(() => _rememberMe = v ?? false),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _rememberMe = !_rememberMe),
                            child: Text(
                              '记住账号密码',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text(
                                    '登录',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _goToRegister,
                        child: const Text(
                          '没有账号？注册',
                          style: TextStyle(color: Color(0xFF1565C0)),
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
          // Close button on gradient background
          Positioned(
            top: 12,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: '关闭',
              onPressed: () => exit(0),
            ),
          ),
        ],
      ),
    );
  }
}
