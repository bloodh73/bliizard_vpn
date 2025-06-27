import 'package:flutter_v2ray/url/url.dart';

class V2RayServer {
  final V2RayURL v2rayURL;
  int latency;
  bool isSelected;

  V2RayServer({
    required this.v2rayURL,
    this.latency = -1,
    this.isSelected = false,
  });

  String get remark => v2rayURL.remark;
  String get address => v2rayURL.address;
  int get port => v2rayURL.port;
}
