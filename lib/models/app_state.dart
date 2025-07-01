// در فایل app_state.dart
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:flutter_v2ray/url/url.dart'; // اضافه شده برای دسترسی به V2RayURL
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AppState {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  static AppState get instance => _instance;

  // وضعیت‌ها
  String? subscriptionLink;
  List<V2RayURL> servers = [];
  V2RayURL? selectedServer;

  // Supabase client (می‌توانید آن را به AppState منتقل کنید یا از HomePage بگیرید)
  final supabase = Supabase.instance.client;

  Future<void> fetchAndParseServers() async {
    try {
      final response = await supabase
          .from('subscription_links')
          .select()
          .eq('is_active', true)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      String subscriptionLink;
      if (response == null || (response['url'] as String).isEmpty) {
        subscriptionLink = _getFallbackUrl();
      } else {
        subscriptionLink = response['url'] as String;
      }

      if (!_isValidV2RayUrl(subscriptionLink)) {
        throw Exception('Invalid URL format: $subscriptionLink');
      }

      final downloadedServers = await _downloadAndParseSubscription(
        subscriptionLink,
      );

      // به‌روزرسانی وضعیت
      this.subscriptionLink = subscriptionLink;
      this.servers = downloadedServers;
      if (selectedServer == null && servers.isNotEmpty) {
        selectedServer = servers.first;
      }
    } catch (e) {
      // مدیریت خطا
      print('Error fetching and parsing servers: $e');
      // می‌توانید یک Snackbar یا پیام خطا نمایش دهید
    }
  }

  String _getFallbackUrl() {
    return "vmess://eyJhZGQiOiIxMjcuMC4wLjEiLCJhaWQiOiIwIiwiYWxwbiI6IiIsImhvc3QiOiIiLCJpZCI6IjAwMDAwMDAwLTAwMDAtMDAwMC0wMDAwLTAwMDAwMDAwMDAwMCIsIm5ldCI6InRjcCIsInBhdGgiOiIiLCJwb3J0IjoiNDQzIiwicHMyIjoiZnJlZSBzZXJ2ZXIiLCJzY3kiOiJhdXRvIiwicmVtYXJrIjoiZnJlZSBzZXJ2ZXIiLCJzbmkiOiIiLCJ0bHMiOiIiLCJ0eXBlIjoiaHR0cCIsInYiOiIyIiwidiNpZCI6IjAwMDAwMDAwLTAwMDAtMDAwMC0wMDAwLTAwMDAwMDAwMDAwMCIsInBvcnRzIjoieXl5In0=";
  }

  bool _isValidV2RayUrl(String url) {
    return url.startsWith('vmess://') ||
        url.startsWith('vless://') ||
        url.startsWith('ss://') ||
        url.startsWith('trojan://') ||
        url.startsWith('http://') ||
        url.startsWith('https://');
  }

  Future<List<V2RayURL>> _downloadAndParseSubscription(String url) async {
    try {
      if (url.startsWith('http')) {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) {
          throw Exception('Failed to download subscription');
        }
        final content = String.fromCharCodes(base64Decode(response.body));
        final servers = content.split('\n');
        final validServers = <V2RayURL>[];
        for (var server in servers) {
          if (server.trim().isNotEmpty) {
            try {
              validServers.add(FlutterV2ray.parseFromURL(server));
            } catch (e) {
              print('Failed to parse server: $server, Error: $e');
            }
          }
        }
        return validServers;
      } else {
        return [FlutterV2ray.parseFromURL(url)];
      }
    } catch (e) {
      rethrow;
    }
  }
}
