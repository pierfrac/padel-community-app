import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

const bool usesGoogleIdentityButton = true;

Widget buildGoogleIdentityButton() => google_web.renderButton();
