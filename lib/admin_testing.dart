import 'package:flutter/foundation.dart';

/// Temporary local testing switch. Release/profile builds can never enable it.
/// Remove the test controls by setting defaultValue to false, or run with
/// --dart-define=PATH_OUT_ADMIN=false. Real player progress uses a separate key.
const adminTestingEnabled =
    kDebugMode && bool.fromEnvironment('PATH_OUT_ADMIN', defaultValue: true);
const adminTestCoins = 10000;
