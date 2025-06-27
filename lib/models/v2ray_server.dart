// models/v2ray_server.dart
import 'package:flutter_v2ray/url/url.dart';

class V2RayServer {
  final V2RayURL url;
  final String customRemark;

  V2RayServer({required this.url, required this.customRemark});

  String get config {
    final config = url.getFullConfiguration();
    // config = customRemark; // Update remark in config
    return config;
  }
}
