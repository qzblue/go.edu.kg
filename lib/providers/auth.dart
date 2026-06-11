import 'package:fl_clash/common/xboard_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/auth.g.dart';

@Riverpod(keepAlive: true)
class AuthToken extends _$AuthToken {
  @override
  String? build() {
    return xboardApi.token;
  }

  void set(String? token) {
    state = token;
  }
}

@Riverpod(keepAlive: true)
class UserInfo extends _$UserInfo {
  @override
  Map<String, dynamic>? build() {
    return null;
  }

  void set(Map<String, dynamic>? info) {
    state = info;
  }
}

@riverpod
bool isLoggedIn(ref) {
  final token = ref.watch(authTokenProvider);
  return token != null && token.isNotEmpty;
}
