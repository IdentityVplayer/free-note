import 'package:flutter/material.dart';

/// Shared [RouteObserver] so screens can react to navigation events (e.g.
/// reload their data when the user pops back from a sub-screen).
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
