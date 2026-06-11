import 'package:fl_clash/common/sspanel_api.dart';

// ===========================================================================
// 机场面板对接 —— SSPanel 版
// ---------------------------------------------------------------------------
// 本版本对接 SSPanel-UIM 面板（go.edu.kg）。
// App 统一通过全局实例 [xboardApi]（类型为 [PanelApi]）调用面板接口，
// 具体实现见 sspanel_api.dart。
//
// 注：另有独立的 Xboard / V2board 版本（xboard 分支），请勿在本版本混入。
// ===========================================================================

/// UI 层据此做差异化门控（SSPanel 隐藏商城/注册）。本版本恒为 true。
const isSSPanel = true;

/// 所有面板后端共同遵守的接口，App 只依赖此抽象。
abstract class PanelApi {
  String? get token;
  bool get isLoggedIn;

  /// 面板网页端地址（用于"官网 / 流量明细"等外链跳转）。
  String get webBaseUrl;

  Future<void> loadToken();
  Future<void> saveToken(String token);
  Future<void> clearToken();

  /// 登录。成功时内部完成凭证持久化，统一返回 `{'success': bool, 'message': String}`。
  Future<Map<String, dynamic>> login(String email, String password);

  /// 注册。成功时内部完成凭证持久化，统一返回 `{'success': bool, 'message': String}`。
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String emailCode,
    String? inviteCode,
  });

  Future<Map<String, dynamic>> sendEmailVerify(String email);
  Future<Map<String, dynamic>> getUserInfo();
  Future<Map<String, dynamic>> getSubscribe();
  Future<Map<String, dynamic>> getPlans();
  Future<Map<String, dynamic>> getOrders();
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> data);
  Future<Map<String, dynamic>> getNotices();
  Future<Map<String, dynamic>> checkCoupon(String code, int planId);
  Future<Map<String, dynamic>> getOrderDetail(String tradeNo);
  Future<Map<String, dynamic>> getPaymentMethods();
  Future<Map<String, dynamic>> checkout(String tradeNo, int paymentMethod);
  Future<Map<String, dynamic>> checkOrder(String tradeNo);
  Future<Map<String, dynamic>> cancelOrder(String tradeNo);
  Future<Map<String, dynamic>> getLoginLog();
  Future<Map<String, dynamic>> getSiteConfig();

  String getSubscribeUrl(String subToken);
  Future<String?> fetchSubscribeUrl();
}

/// 全局面板实例（SSPanel 实现）。
final PanelApi xboardApi = SSPanelApi();
