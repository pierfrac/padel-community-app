import 'package:flutter/widgets.dart';

import 'google_sign_in_button_stub.dart'
    if (dart.library.js_interop) 'google_sign_in_button_web.dart' as platform;

/// True when Google Identity Services must render its own sign-in button.
bool get usesGoogleIdentityButton => platform.usesGoogleIdentityButton;

/// Builds the platform-specific sign-in control.
Widget buildGoogleIdentityButton() => platform.buildGoogleIdentityButton();
