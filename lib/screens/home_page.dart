import 'dart:convert';

import 'package:blizzard_vpn/models/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  var v2rayStatus = ValueNotifier<V2RayStatus>(V2RayStatus());
  late final FlutterV2ray flutterV2ray = FlutterV2ray(
    onStatusChanged: (status) {
      v2rayStatus.value = status;
    },
  );

  String? coreVersion;
  bool isConnecting = false;
  bool isRefreshing = false;
  Map<String, dynamic>? userProfile;
  bool isProfileLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshServers();
    });
  }

  Future<void> _initializeApp() async {
    await _initializeV2Ray();
    await _loadUserProfile();
  }

  Future<void> _initializeV2Ray() async {
    try {
      await flutterV2ray.initializeV2Ray(
        notificationIconResourceType: "mipmap",
        notificationIconResourceName: "ic_launcher",
      );
      coreVersion = await flutterV2ray.getCoreVersion();
      setState(() {});
    } catch (e) {
      _showErrorSnackbar('Failed to initialize V2Ray: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    setState(() => isProfileLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        // Create default profile if doesn't exist
        await supabase.from('users').insert({
          'id': user.id,
          'email': user.email,
          'full_name': user.email?.split('@').first ?? 'User',
          'subscription_type': 'free',
          'created_at': DateTime.now().toIso8601String(),
        });

        // Reload after creation
        final newResponse = await supabase
            .from('users')
            .select()
            .eq('id', user.id)
            .single();

        setState(() => userProfile = newResponse);
      } else {
        setState(() => userProfile = response);
      }
    } catch (e) {
      _showErrorSnackbar('Failed to load profile: $e');
    } finally {
      setState(() => isProfileLoading = false);
    }
  }

  Future<void> refreshServers() async {
    final appState = AppState.instance;
    setState(() => isRefreshing = true);

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

      final servers = await _downloadAndParseSubscription(subscriptionLink);

      setState(() {
        appState.subscriptionLink = subscriptionLink;
        appState.servers = servers;
        appState.selectedServer = servers.isNotEmpty ? servers.first : null;
      });
    } catch (e) {
      _showErrorSnackbar('Error loading subscription: ${e.toString()}');
      await _tryFallbackConnection(appState);
    } finally {
      setState(() => isRefreshing = false);
    }
  }

  bool _isValidV2RayUrl(String url) {
    // قبول کردن هم URLهای مستقیم و هم لینک‌های سابسکریپشن
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
        // دانلود محتوای سابسکریپشن
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) {
          throw Exception('Failed to download subscription');
        }

        // پردازش محتوا (فرض بر این است که محتوا base64 encoded است)
        final content = String.fromCharCodes(base64Decode(response.body));
        final servers = content.split('\n');

        // پردازش تمام سرورهای معتبر
        final validServers = <V2RayURL>[];
        for (final server in servers) {
          if (server.trim().isEmpty) continue;

          try {
            if (server.startsWith('vmess://') ||
                server.startsWith('vless://') ||
                server.startsWith('ss://') ||
                server.startsWith('trojan://')) {
              final v2rayURL = FlutterV2ray.parseFromURL(server);
              if (v2rayURL.remark.isNotEmpty) {
                validServers.add(v2rayURL);
              }
            }
          } catch (e) {
            debugPrint('Error parsing server config: $e');
          }
        }

        if (validServers.isEmpty) {
          throw Exception('No valid servers found in subscription');
        }

        return validServers;
      } else {
        // اگر URL مستقیم بود
        return [FlutterV2ray.parseFromURL(url)];
      }
    } catch (e) {
      throw Exception('Failed to process subscription: ${e.toString()}');
    }
  }

  String _getFallbackUrl() {
    // Return a known-good fallback URL
    return 'ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTo0MTZiMmU5YTFlZTQ0MTMxNDU5YTdiMjUyZDEwN2Y1MA%3D%3D@vssweb.ir:8443#%F0%9F%87%AC%F0%9F%87%A7%20%F0%9D%90%94%F0%9D%90%8A';
  }

  Future<void> _tryFallbackConnection(AppState appState) async {
    try {
      final fallbackUrl = _getFallbackUrl();
      final v2rayURL = FlutterV2ray.parseFromURL(fallbackUrl);

      setState(() {
        appState.subscriptionLink = fallbackUrl;
        appState.servers = [];
        appState.selectedServer = v2rayURL;
      });

      _showErrorSnackbar('Using fallback server');
    } catch (e) {
      _showErrorSnackbar('Fallback also failed: ${e.toString()}');
    }
  }

  Future<void> fetchSubscriptionFromSupabase() async {
    bool isLoading = false;
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final response = await supabase
          .from('subscription_links')
          .select()
          .eq('is_active', true)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      String subscriptionLink;

      if (response == null || (response['url'] as String).isEmpty) {
        throw Exception('No active subscription found');
      } else {
        subscriptionLink = response['url'] as String;
      }

      final appState = AppState.instance;
      final servers = await _downloadAndParseSubscription(subscriptionLink);

      if (servers.isEmpty) {
        throw Exception('No valid servers found');
      }

      setState(() {
        appState.subscriptionLink = subscriptionLink;
        appState.servers = servers;
        appState.selectedServer = servers.first;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> connect() async {
    final appState = AppState.instance;
    if (appState.selectedServer == null) return;

    setState(() => isConnecting = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      if (await flutterV2ray.requestPermission()) {
        await flutterV2ray.startV2Ray(
          remark: appState.selectedServer!.remark,
          config: appState.selectedServer!.getFullConfiguration(),
          proxyOnly: false,
          bypassSubnets: [],
          notificationDisconnectButtonName: "DISCONNECT",
        );

        await _logConnection(user.id, appState.selectedServer!.remark);
      } else {
        _showErrorSnackbar('Permission denied');
      }
    } catch (e) {
      _showErrorSnackbar('Connection error: $e');
    } finally {
      setState(() => isConnecting = false);
    }
  }

  Future<void> _logConnection(String userId, String server) async {
    await supabase.from('connection_logs').insert({
      'user_id': userId,
      'server': server,
      'connected_at': DateTime.now().toIso8601String(),
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppState.instance;
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blizzard VPN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
          IconButton(
            icon: isRefreshing
                ? const CircularProgressIndicator()
                : const Icon(Icons.refresh),
            onPressed: isRefreshing ? null : refreshServers,
            tooltip: 'Refresh Servers',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // User Profile Card
            _buildUserProfileCard(user),
            const SizedBox(height: 20),

            // Server Selection Card
            _buildServerCard(appState),
            const SizedBox(height: 20),

            // Connection Status
            _buildConnectionStatus(),
            const SizedBox(height: 30),

            // Connect Button
            _buildConnectButton(),
            const Spacer(),

            // App Version
            if (coreVersion != null)
              Text(
                'V2Ray Core v$coreVersion',
                style: TextStyle(color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileCard(User? user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.account_circle, size: 40),
              title: Text(
                userProfile?['full_name'] ?? 'Guest User',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(user?.email ?? 'No email'),
              trailing: Chip(
                label: Text(
                  userProfile?['subscription_type']?.toUpperCase() ?? 'FREE',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.blue[100],
              ),
            ),
            if (isProfileLoading) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildServerCard(AppState appState) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: const Text('SERVER', style: TextStyle(fontSize: 12)),
        subtitle: Text(
          appState.selectedServer?.remark ?? 'No server selected',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pushNamed(context, '/servers');
        },
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return ValueListenableBuilder<V2RayStatus>(
      valueListenable: v2rayStatus,
      builder: (context, status, _) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: _getStatusColor(status.state),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getStatusText(status.state),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (status.state == 'CONNECTED') ...[
              Text('Duration: ${status.duration}'),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSpeedIndicator(
                    Icons.upload,
                    status.uploadSpeed.bitLength == 0
                        ? '0'
                        : status.uploadSpeed.bitLength.toString(),
                    Colors.blue,
                  ),
                  const SizedBox(width: 30),
                  _buildSpeedIndicator(
                    Icons.download,
                    status.downloadSpeed.bitLength == 0
                        ? '0'
                        : status.downloadSpeed.bitLength.toString(),
                    Colors.green,
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSpeedIndicator(IconData icon, String speed, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(speed, style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildConnectButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isConnecting
            ? null
            : v2rayStatus.value.state == 'CONNECTED'
            ? () => flutterV2ray.stopV2Ray()
            : connect,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: _getButtonColor(v2rayStatus.value.state),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isConnecting
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                _getButtonText(v2rayStatus.value.state),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await flutterV2ray.stopV2Ray();
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      _showErrorSnackbar('Logout failed: $e');
    }
  }

  Color _getStatusColor(String state) {
    switch (state) {
      case 'CONNECTED':
        return Colors.green;
      case 'CONNECTING':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  String _getStatusText(String state) {
    switch (state) {
      case 'CONNECTED':
        return 'CONNECTED';
      case 'CONNECTING':
        return 'CONNECTING...';
      default:
        return 'DISCONNECTED';
    }
  }

  Color _getButtonColor(String state) {
    return state == 'CONNECTED' ? Colors.red : Colors.green;
  }

  String _getButtonText(String state) {
    return state == 'CONNECTED' ? 'DISCONNECT' : 'CONNECT';
  }
}
