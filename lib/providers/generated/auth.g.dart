// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../auth.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AuthToken)
const authTokenProvider = AuthTokenProvider._();

final class AuthTokenProvider extends $NotifierProvider<AuthToken, String?> {
  const AuthTokenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authTokenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authTokenHash();

  @$internal
  @override
  AuthToken create() => AuthToken();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$authTokenHash() => r'a8d893d58718b51b9a7301bece75f4b77f53c65a';

abstract class _$AuthToken extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(UserInfo)
const userInfoProvider = UserInfoProvider._();

final class UserInfoProvider
    extends $NotifierProvider<UserInfo, Map<String, dynamic>?> {
  const UserInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userInfoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userInfoHash();

  @$internal
  @override
  UserInfo create() => UserInfo();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, dynamic>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, dynamic>?>(value),
    );
  }
}

String _$userInfoHash() => r'0f70326b0bcacc215d43a6e69fd263f9ca4204b9';

abstract class _$UserInfo extends $Notifier<Map<String, dynamic>?> {
  Map<String, dynamic>? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Map<String, dynamic>?, Map<String, dynamic>?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, dynamic>?, Map<String, dynamic>?>,
              Map<String, dynamic>?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(isLoggedIn)
const isLoggedInProvider = IsLoggedInProvider._();

final class IsLoggedInProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  const IsLoggedInProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isLoggedInProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isLoggedInHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isLoggedIn(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isLoggedInHash() => r'2e2cfa797a7115235cdf0ad176e0c8de3a28b33e';
