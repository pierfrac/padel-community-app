/// Compile-time identity used only by the four-session local test launcher.
///
/// These values are not authentication or authorization. Production roles must
/// be verified from trusted credentials, not from client-controlled defines.
abstract final class TestIdentity {
  static const role = String.fromEnvironment('PADEL_TEST_ROLE');
  static const userId = String.fromEnvironment('PADEL_TEST_USER_ID');

  static bool get isEnabled =>
      userId.isNotEmpty && (role == 'admin' || role == 'player');

  static bool get isAdmin => role == 'admin';
}
