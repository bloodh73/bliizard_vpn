// lib/models/app_state.dart
import 'package:flutter_v2ray/url/url.dart';

class AppState {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  static AppState get instance => _instance;

  String? subscriptionLink;
  List<V2RayURL> servers = [];
  V2RayURL? selectedServer;
}
