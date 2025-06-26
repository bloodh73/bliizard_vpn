import 'package:blizzard_vpn/screens/server_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
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
          .single();

      setState(() => userProfile = response);
    } catch (e) {
      _showErrorSnackbar('Failed to load profile: $e');
    } finally {
      setState(() => isProfileLoading = false);
    }
  }

  Future<void> refreshServers() async {
    final appState = AppState.instance;
    if (appState.subscriptionLink == null) return;

    setState(() => isRefreshing = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('user_subscriptions')
          .select('subscription_link')
          .eq('user_id', user.id)
          .single();

      final subscriptionLink = response['subscription_link'] as String?;
      if (subscriptionLink == null) {
        throw Exception('No subscription found');
      }

      appState.subscriptionLink = subscriptionLink;
      final v2rayURL = FlutterV2ray.parseFromURL(subscriptionLink);

      setState(() {
        appState.servers = [v2rayURL];
        appState.selectedServer = v2rayURL;
      });
    } catch (e) {
      _showErrorSnackbar('Error updating servers: $e');
    } finally {
      setState(() => isRefreshing = false);
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
