import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/xboard_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ===========================================================================
// SSPanel-UIM 面板对接实现
// ---------------------------------------------------------------------------
// 与 Xboard 的本质差异：
//   * 认证：Cookie Session（登录后下发 uid/key/ip/email 等 cookie），非 Bearer Token
//   * 登录：POST /auth/login  (表单字段 email / passwd)，返回 {ret, msg}
//   * 用户数据：无 JSON 接口，需登录态抓取 /user 页面
//   * 订阅：/sub/{token}/clash 返回标准 Clash YAML，响应头 Subscription-Userinfo
//           直接给出 upload/download/total/expire，无需解析 HTML
// ===========================================================================

const _ssBaseUrl = 'https://go.edu.kg';
const _ssCookieKey = 'sspanel_cookie';
const _ssEmailKey = 'sspanel_email';
// 持久化缓存订阅 token：SSPanel 登录 cookie 仅 1 小时有效，但订阅地址
// /sub/{token}/clash 是公开的。缓存 token 后，即使 cookie 过期也能始终
// 取到订阅与流量信息，保证节点持续可用。
const _ssSubTokenKey = 'sspanel_sub_token';
const _ssUa =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

class SSPanelApi implements PanelApi {
  static SSPanelApi? _instance;
  late final Dio _dio;
  String? _cookie;
  String? _email;
  String? _subToken;

  SSPanelApi._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _ssBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      // 不自动跟随重定向：未登录访问 /user 会 302 回登录页，据此判断会话失效
      followRedirects: false,
      validateStatus: (s) => s != null && s < 500,
      headers: {'User-Agent': _ssUa},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_cookie != null && _cookie!.isNotEmpty) {
          options.headers['Cookie'] = _cookie;
        }
        handler.next(options);
      },
    ));
  }

  factory SSPanelApi() {
    _instance ??= SSPanelApi._internal();
    return _instance!;
  }

  @override
  String? get token => _cookie;

  @override
  bool get isLoggedIn => _cookie != null && _cookie!.isNotEmpty;

  @override
  String get webBaseUrl => _ssBaseUrl;

  // ------------------------------------------------------------------ 凭证持久化
  @override
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _cookie = prefs.getString(_ssCookieKey);
    _email = prefs.getString(_ssEmailKey);
    _subToken = prefs.getString(_ssSubTokenKey);
  }

  @override
  Future<void> saveToken(String token) async {
    _cookie = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ssCookieKey, token);
  }

  @override
  Future<void> clearToken() async {
    _cookie = null;
    _email = null;
    _subToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ssCookieKey);
    await prefs.remove(_ssEmailKey);
    await prefs.remove(_ssSubTokenKey);
  }

  Future<void> _saveEmail(String email) async {
    _email = email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ssEmailKey, email);
  }

  Future<void> _saveSubToken(String token) async {
    _subToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ssSubTokenKey, token);
  }

  /// 解析订阅 token：优先从登录态 /user 页抓取（顺便刷新缓存，应对用户在
  /// 网页端重置订阅链接）；若会话已失效（cookie 过期 302），回退到缓存 token。
  /// 这样只要成功登录过一次，订阅与流量信息就永远可用，不受 cookie 1 小时过期影响。
  Future<String?> _resolveSubToken() async {
    final html = await _getUserHtml();
    if (html != null) {
      final fresh = _extractSubToken(html);
      if (fresh != null && fresh.isNotEmpty) {
        if (fresh != _subToken) await _saveSubToken(fresh);
        return fresh;
      }
    }
    return _subToken;
  }

  /// 从响应的 Set-Cookie 头收集所有 name=value，拼成可回传的 Cookie 串。
  String _collectCookies(Response response) {
    final list = response.headers.map['set-cookie'] ?? const [];
    final pairs = <String>[];
    for (final raw in list) {
      final pair = raw.split(';').first.trim();
      if (pair.contains('=') && !pair.toLowerCase().startsWith('deleted')) {
        pairs.add(pair);
      }
    }
    return pairs.join('; ');
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = json.decode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  // ------------------------------------------------------------------ 登录
  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'passwd': password, 'remember_me': 'week'},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final body = _asMap(response.data);
      if (body['ret'] == 1) {
        final cookie = _collectCookies(response);
        if (cookie.isNotEmpty) {
          await saveToken(cookie);
        }
        await _saveEmail(email);
        // 趁 cookie 新鲜，立即抓取并缓存订阅 token，保证后续始终可取订阅
        await _resolveSubToken();
        return {'success': true, 'message': body['msg']?.toString() ?? '登录成功'};
      }
      return {
        'success': false,
        'message': body['msg']?.toString() ?? '邮箱或密码错误',
      };
    } on DioException catch (e) {
      return {'success': false, 'message': '网络错误: ${e.message}'};
    } catch (e) {
      return {'success': false, 'message': '登录失败: $e'};
    }
  }

  // ------------------------------------------------------------------ /user 抓取
  /// 获取登录态下的 /user 页面 HTML；会话失效（302/非 200）返回 null。
  Future<String?> _getUserHtml() async {
    try {
      final response = await _dio.get('/user');
      if (response.statusCode == 200 && response.data is String) {
        return response.data as String;
      }
    } catch (_) {}
    return null;
  }

  /// 从 /user 页面提取订阅 token（兼容 /sub/{token}/... 与 /link/{token} 两种写法）。
  String? _extractSubToken(String html) {
    final m = RegExp(r'/(?:sub|link)/([A-Za-z0-9]{8,})').firstMatch(html);
    return m?.group(1);
  }

  /// 解析订阅响应头 `Subscription-Userinfo: upload=..; download=..; total=..; expire=..`
  void _applyUserInfoHeader(Map<String, dynamic> info, String? header) {
    if (header == null || header.isEmpty) return;
    for (final part in header.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length != 2) continue;
      final value = int.tryParse(kv[1].trim());
      if (value == null) continue;
      switch (kv[0].trim()) {
        case 'upload':
          info['u'] = value;
          break;
        case 'download':
          info['d'] = value;
          break;
        case 'total':
          info['transfer_enable'] = value;
          break;
        case 'expire':
          info['expired_at'] = value;
          break;
      }
    }
  }

  /// 读取订阅链接的响应头以获取流量/到期信息（HEAD 请求，无需下载正文）。
  Future<String?> _fetchSubUserInfoHeader(String subUrl) async {
    try {
      final response = await Dio().head(
        subUrl,
        options: Options(
          headers: {'User-Agent': _ssUa},
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      return response.headers.value('subscription-userinfo');
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------ 用户信息
  @override
  Future<Map<String, dynamic>> getUserInfo() async {
    final token = await _resolveSubToken();
    if (token == null) {
      // 从未成功登录过，无可用信息
      return {'data': null};
    }
    final info = <String, dynamic>{
      'email': _email,
      // SSPanel 由网页端管理套餐；置非空使客户端跳过"无套餐"拦截逻辑
      'plan_id': 1,
      'balance': 0,
    };
    // 流量/到期来自公开订阅响应头，cookie 过期也能读取
    final header =
        await _fetchSubUserInfoHeader('$_ssBaseUrl/sub/$token/clash');
    _applyUserInfoHeader(info, header);
    return {'data': info};
  }

  @override
  Future<Map<String, dynamic>> getSubscribe() async {
    final token = await _resolveSubToken();
    return {
      'data': token != null
          ? {'token': token, 'subscribe_url': '$_ssBaseUrl/sub/$token/clash'}
          : null,
    };
  }

  @override
  String getSubscribeUrl(String subToken) => '$_ssBaseUrl/sub/$subToken/clash';

  @override
  Future<String?> fetchSubscribeUrl() async {
    final token = await _resolveSubToken();
    if (token == null) return null;
    return '$_ssBaseUrl/sub/$token/clash';
  }

  // ------------------------------------------------------------------ 不适用接口
  // SSPanel 已关闭注册 / 未启用邮箱验证 / 商城走网页端，以下接口返回安全的空结果。
  static const Map<String, dynamic> _unsupported = {
    'success': false,
    'message': '当前面板不支持该功能，请前往网页端操作',
  };

  @override
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String emailCode,
    String? inviteCode,
  }) async {
    return {'success': false, 'message': '当前站点未开放注册'};
  }

  @override
  Future<Map<String, dynamic>> sendEmailVerify(String email) async {
    return {'status': 'fail', 'message': '当前站点未启用邮箱验证'};
  }

  @override
  Future<Map<String, dynamic>> getPlans() async => {'data': <dynamic>[]};

  @override
  Future<Map<String, dynamic>> getOrders() async => {'data': <dynamic>[]};

  @override
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> data) async =>
      Map<String, dynamic>.from(_unsupported);

  @override
  Future<Map<String, dynamic>> getNotices() async => {'data': <dynamic>[]};

  @override
  Future<Map<String, dynamic>> checkCoupon(String code, int planId) async =>
      Map<String, dynamic>.from(_unsupported);

  @override
  Future<Map<String, dynamic>> getOrderDetail(String tradeNo) async =>
      {'data': null};

  @override
  Future<Map<String, dynamic>> getPaymentMethods() async => {'data': <dynamic>[]};

  @override
  Future<Map<String, dynamic>> checkout(String tradeNo, int paymentMethod) async =>
      Map<String, dynamic>.from(_unsupported);

  @override
  Future<Map<String, dynamic>> checkOrder(String tradeNo) async =>
      {'data': null};

  @override
  Future<Map<String, dynamic>> cancelOrder(String tradeNo) async =>
      Map<String, dynamic>.from(_unsupported);

  @override
  Future<Map<String, dynamic>> getLoginLog() async => {'data': <dynamic>[]};

  @override
  Future<Map<String, dynamic>> getSiteConfig() async => {'data': <String, dynamic>{}};
}
