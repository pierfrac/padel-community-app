/// Compile-time identities used only by the four-session local test launcher.
///
/// The admin preview must authenticate with Google. The other three users are
/// synthetic test identities. None of these compile-time settings is a
/// production authorization mechanism.
abstract final class TestIdentity {
  static const role = String.fromEnvironment('PADEL_TEST_ROLE');
  static const userId = String.fromEnvironment('PADEL_TEST_USER_ID');
  static const googleClientId =
      String.fromEnvironment('PADEL_GOOGLE_CLIENT_ID');

  static bool get isGoogleAdminPreview => role == 'google-admin';

  static bool get isSimulatedPlayer =>
      role == 'player' && userId.isNotEmpty;
}
