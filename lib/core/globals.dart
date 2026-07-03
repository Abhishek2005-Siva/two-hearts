import 'package:flutter/material.dart';

/// Root-level ScaffoldMessenger key so any widget — including those with
/// their own Scaffold — can show SnackBars visible across all screens.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
