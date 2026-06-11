import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _baseUrl = 'https://cn3.yudijiasu.vip';
const _tokenKey = 'xboard_auth_token';

class XboardApi {
  static XboardApi? _instance;
  late final Dio _dio;
  String? _token;

  XboardApi._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
    ));
  }

  factory XboardApi() {
    _instance ??= XboardApi._internal();
    return _instance!;
  }

  String? get token => _token;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  String getSubscribeUrl(String subToken) {
    return '$_baseUrl/s/$subToken';
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post(
      '/api/v1/passport/auth/login',
      data: {'email': email, 'password': password},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String emailCode,
    String? inviteCode,
  }) async {
    final data = <String, dynamic>{
      'email': email,
      'password': password,
      'email_code': emailCode,
    };
    if (inviteCode != null && inviteCode.isNotEmpty) {
      data['invite_code'] = inviteCode;
    }
    final response = await _dio.post(
      '/api/v1/passport/auth/register',
      data: data,
    );
    return response.data;
  }

  Future<Map<String, dynamic>> sendEmailVerify(String email) async {
    final response = await _dio.post(
      '/api/v1/passport/comm/sendEmailVerify',
      data: {'email': email},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getUserInfo() async {
    final response = await _dio.get('/api/v1/user/info');
    return response.data;
  }

  Future<Map<String, dynamic>> getSubscribe() async {
    final response = await _dio.get('/api/v1/user/getSubscribe');
    return response.data;
  }

  Future<Map<String, dynamic>> getPlans() async {
    final response = await _dio.get('/api/v1/user/plan/fetch');
    return response.data;
  }

  Future<Map<String, dynamic>> getOrders() async {
    final response = await _dio.get('/api/v1/user/order/fetch');
    return response.data;
  }

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/user/order/save', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> getNotices() async {
    final response = await _dio.get('/api/v1/user/notice/fetch');
    return response.data;
  }

  Future<Map<String, dynamic>> checkCoupon(String code, int planId) async {
    final response = await _dio.post(
      '/api/v1/user/coupon/check',
      data: {'code': code, 'plan_id': planId},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getOrderDetail(String tradeNo) async {
    final response = await _dio.get(
      '/api/v1/user/order/detail',
      queryParameters: {'trade_no': tradeNo},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getPaymentMethods() async {
    final response = await _dio.get('/api/v1/user/order/getPaymentMethod');
    return response.data;
  }

  Future<Map<String, dynamic>> checkout(String tradeNo, int paymentMethod) async {
    final response = await _dio.post(
      '/api/v1/user/order/checkout',
      data: {'trade_no': tradeNo, 'method': paymentMethod},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> checkOrder(String tradeNo) async {
    final response = await _dio.get(
      '/api/v1/user/order/check',
      queryParameters: {'trade_no': tradeNo},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> cancelOrder(String tradeNo) async {
    final response = await _dio.post(
      '/api/v1/user/order/cancel',
      data: {'trade_no': tradeNo},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getLoginLog() async {
    final response = await _dio.get('/api/v1/user/stat/getLoginLog');
    return response.data;
  }

  Future<Map<String, dynamic>> getSiteConfig() async {
    final response = await _dio.get('/api/v1/guest/comm/config');
    return response.data;
  }

  /// 给订阅 URL 追加 flag=meta 参数，确保返回 Clash.Meta YAML 格式（支持 AnyTLS 等新协议）
  String _ensureClashFlag(String url) {
    final uri = Uri.parse(url);
    if (uri.queryParameters.containsKey('flag')) return url;
    final newUri = uri.replace(
      queryParameters: {...uri.queryParameters, 'flag': 'meta'},
    );
    return newUri.toString();
  }

  /// 判断 URL 是否使用域名（非 IP）
  bool _isDomainUrl(String url) {
    try {
      final host = Uri.parse(url).host;
      // 如果是纯 IP 地址则返回 false
      return !RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host);
    } catch (_) {
      return false;
    }
  }

  /// 获取当前用户的订阅 URL，没有则返回 null
  Future<String?> fetchSubscribeUrl() async {
    try {
      final result = await getSubscribe();
      final data = result['data'];
      if (data == null) return null;

      // 提取 token
      String? subToken;
      String? apiSubUrl;
      if (data is Map) {
        subToken = data['token']?.toString();
        apiSubUrl = data['subscribe_url']?.toString();
      } else if (data is List && data.isNotEmpty) {
        subToken = data[0]['token']?.toString();
        apiSubUrl = data[0]['subscribe_url']?.toString();
      }

      // 优先使用 API 返回的 subscribe_url（如果是域名不是 IP）
      if (apiSubUrl != null && apiSubUrl.isNotEmpty && _isDomainUrl(apiSubUrl)) {
        return _ensureClashFlag(apiSubUrl);
      }

      if (subToken == null || subToken.isEmpty) return null;

      // 用面板地址拼接
      return _ensureClashFlag(
        '$_baseUrl/api/v1/client/subscribe?token=$subToken',
      );
    } catch (_) {}
    return null;
  }
}

final xboardApi = XboardApi();
