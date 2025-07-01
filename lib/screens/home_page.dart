import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:blizzard_vpn/components/custom_card.dart';
import 'package:blizzard_vpn/components/custom_snackbar.dart';
import '../utils/date_utils.dart' as date_utils;
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
  bool get isDataExhausted {
    return userProfile?['data_limit'] != null &&
        userProfile?['data_usage'] != null &&
        userProfile!['data_usage'] >= userProfile!['data_limit'];
  }

  Timer? _periodicCheckTimer;

  bool isLoading = false;
  final supabase = Supabase.instance.client;
  var v2rayStatus = ValueNotifier<V2RayStatus>(V2RayStatus());
  late final flutterV2ray = FlutterV2ray(
    onStatusChanged: (status) {
      v2rayStatus.value = status;
    },
  );
  Map<String, dynamic>? userProfile;
  bool isProfileLoading = false;
  bool isConnecting = false;
  bool isRefreshing = false;
  String? coreVersion;
  String remark = "Default Remark";

  final config = TextEditingController();
  bool proxyOnly = false;
  final bypassSubnetController = TextEditingController();
  List<String> bypassSubnets = [];

  @override
  void initState() {
    super.initState();

    _initializeApp();
    _checkUserStatus();
    flutterV2ray
        .initializeV2Ray(
          notificationIconResourceType: "mipmap",
          notificationIconResourceName: "ic_launcher",
        )
        .then((value) async {
          coreVersion = await flutterV2ray.getCoreVersion();
          setState(() {});
        });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshServers();
    });
    _startPeriodicChecks();
  }

  @override
  void dispose() {
    _periodicCheckTimer?.cancel(); // Stop the timer when the widget is disposed
    v2rayStatus.dispose(); // Dispose the ValueNotifier
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _initializeV2Ray();
    await _loadUserProfile();
    await AppState.instance.fetchAndParseServers(); // فراخوانی از AppState
  }

  Future<void> _handleConnectDisconnect() async {
    final appState = AppState.instance;
    if (appState.selectedServer == null) {
      _showErrorSnackbar('Please select a server first.');
      return;
    }

    setState(() => isConnecting = true);
    try {
      if (v2rayStatus.value.state == "CONNECTED") {
        await flutterV2ray.stopV2Ray();
      } else {
        if (v2rayStatus.value.state != "CONNECTING") {
          // Explicitly request permission before starting V2Ray
          if (await flutterV2ray.requestPermission()) {
            //
            await flutterV2ray.startV2Ray(
              config: appState.selectedServer!.getFullConfiguration(),
              remark: appState.selectedServer!.remark,
            );
          } else {
            _showErrorSnackbar('Permission denied. Cannot connect to VPN.'); //
          }
        }
      }
    } catch (e) {
      _showErrorSnackbar('Connection error: $e');
    } finally {
      setState(() => isConnecting = false);
    }
  }

  void connect() async {
    if (await flutterV2ray.requestPermission()) {
      // Permission request happens here
      flutterV2ray.startV2Ray(
        remark: remark,

        notificationDisconnectButtonName: "DISCONNECT",
        config: '',
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Permission Denied')));
      }
    }
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

  void _startPeriodicChecks() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 15), (
      timer,
    ) async {
      await _checkUserStatus();
      await _updateUserProfileFromSupabase();
    });
  }

  Future<void> _checkUserStatus() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('users')
          .select('expiry_date, data_limit, data_usage')
          .eq('id', user.id)
          .single();

      final expiryDate = DateTime.tryParse(response['expiry_date'] ?? '');
      final dataLimit = response['data_limit'] ?? 0;
      final dataUsage = response['data_usage'] ?? 0;

      // Check subscription expiry
      if (expiryDate != null && expiryDate.isBefore(DateTime.now())) {
        if (mounted) {
          _showSubscriptionExpiredSnackbar();
        }
        await flutterV2ray.stopV2Ray();
        return;
      }

      // Check data usage
      if (dataLimit > 0 && dataUsage >= dataLimit) {
        if (mounted) {
          _showErrorSnackbar('Subscription data exhausted!');
        }
        await flutterV2ray.stopV2Ray();
      }
    } catch (e) {
      debugPrint('Error checking user status: $e');
    }
  }

  Future<void> _updateUserProfileFromSupabase() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          userProfile = response;
        });
      }
    } catch (e) {
      debugPrint('Error updating user profile: $e');
    }
  }

  void _showSubscriptionExpiredSnackbar() {
    CustomSnackbar.show(
      context: context,
      message: 'Your subscription has expired. Please renew to continue.',
      backgroundColor: Colors.orange,
      icon: Icons.warning,
      duration: const Duration(seconds: 5),
    );
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
              debugPrint('Failed to parse server: $server, Error: $e');
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

  Future<void> _tryFallbackConnection(AppState appState) async {
    try {
      final fallbackUrl = _getFallbackUrl();
      if (_isValidV2RayUrl(fallbackUrl)) {
        final fallbackServers = [FlutterV2ray.parseFromURL(fallbackUrl)];
        setState(() {
          appState.subscriptionLink = fallbackUrl;
          appState.servers = fallbackServers;
          appState.selectedServer = fallbackServers.first;
        });
        _showErrorSnackbar(
          'Failed to load subscription, using fallback server.',
        );
      }
    } catch (e) {
      _showErrorSnackbar('Failed to load fallback server: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    CustomSnackbar.show(
      context: context,
      message: message,
      backgroundColor: Colors.redAccent,
      icon: Icons.error,
    );
  }

  void bypassSubnet() {
    bypassSubnetController.text = bypassSubnets.join("\n");
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Subnets:', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 5),
              TextFormField(
                controller: bypassSubnetController,
                maxLines: 5,
                minLines: 5,
              ),
              const SizedBox(height: 5),
              ElevatedButton(
                onPressed: () {
                  bypassSubnets = bypassSubnetController.text.trim().split(
                    '\n',
                  );
                  if (bypassSubnets.first.isEmpty) {
                    bypassSubnets = [];
                  }
                  Navigator.of(context).pop();
                },
                child: const Text('Submit'),
              ),
            ],
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

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Widget _buildUserDrawer() {
    final isAdmin = userProfile?['is_admin'] == true;
    final isSubscriptionExpired =
        userProfile?['expiry_date'] != null &&
        DateTime.tryParse(
          userProfile!['expiry_date'],
        )!.isBefore(DateTime.now());

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.8,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSubscriptionExpired
                ? [Colors.red[900]!, Colors.red[700]!]
                : [
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    Theme.of(context).colorScheme.primary,
                  ], // Themed gradient
          ),
        ),
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                userProfile?['full_name'] ?? 'مهمان',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: Text(
                supabase.auth.currentUser?.email ?? 'ایمیل موجود نیست',
                style: const TextStyle(fontSize: 14),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                child: Text(
                  userProfile?['full_name']?.toUpperCase() ?? 'U',
                  style: const TextStyle(fontSize: 32, color: Colors.black),
                ),
              ),
              decoration: const BoxDecoration(color: Colors.transparent),
            ),
            if (isSubscriptionExpired)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red[800],
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Subscription Expired! Please renew.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.calendar_today,
                    title: 'تاریخ انقضا',
                    value: userProfile?['expiry_date'] != null
                        ? date_utils.formatToJalali(userProfile!['expiry_date'])
                        : 'Not Set',
                  ),
                  _buildDrawerDivider(),
                  _buildDrawerItem(
                    icon: Icons.data_usage,
                    title: 'حجم مصرفی',
                    value: userProfile?['data_usage'] != null
                        ? '${_formatBytes(userProfile!['data_usage'])} / ${_formatBytes(userProfile!['data_limit'] ?? 0)}'
                        : '0 / 0 B',
                    isProgress: true,
                    progressValue:
                        userProfile?['data_usage'] != null &&
                            userProfile?['data_limit'] != null &&
                            userProfile!['data_limit'] > 0
                        ? (userProfile!['data_usage'] /
                                  userProfile!['data_limit'])
                              .clamp(0.0, 1.0)
                        : 0.0,
                  ),
                  if (isAdmin) ...[
                    _buildDrawerDivider(),
                    ListTile(
                      leading: Icon(
                        Icons.admin_panel_settings,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      title: const Text(
                        'پنل ادمین',
                        style: TextStyle(color: Colors.white, fontFamily: 'SM'),
                      ),
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        Navigator.pushNamed(context, '/admin');
                      },
                    ),
                  ],
                  _buildDrawerDivider(),
                  _buildDrawerItem(
                    icon: Icons.account_circle,

                    title: 'Account Type',

                    value:
                        userProfile?['subscription_type']
                            ?.toString()
                            .toUpperCase() ??
                        'FREE',
                  ),
                  _buildDrawerDivider(),
                  ListTile(
                    leading: const Icon(Icons.settings, color: Colors.white),
                    title: const Text(
                      'تنظیمات',
                      style: TextStyle(color: Colors.white, fontFamily: 'SM'),
                    ),
                    onTap: () {
                      // Navigate to settings page
                    },
                  ),
                  _buildDrawerDivider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.white),
                    title: const Text(
                      'خروج از حساب',
                      style: TextStyle(color: Colors.white, fontFamily: 'SM'),
                    ),
                    onTap: _handleLogout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    String? value,
    bool isProgress = false,
    double progressValue = 0.0,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          if (value != null)
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          if (isProgress)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progressValue > 0.8 ? Colors.red : Colors.green,
                ),
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildDrawerDivider() {
    return Divider(
      color: Colors.blue[800]?.withOpacity(0.5),
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppState.instance;
    final isSubscriptionExpired =
        userProfile?['expiry_date'] != null &&
        DateTime.tryParse(
          userProfile!['expiry_date'],
        )!.isBefore(DateTime.now());
    final isDataExhausted =
        userProfile?['data_limit'] != null &&
        userProfile?['data_usage'] != null &&
        userProfile!['data_usage'] >= userProfile!['data_limit'];

    return Scaffold(
      appBar: AppBar(
        title: Text(userProfile?['full_name'] ?? 'Guest'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isRefreshing ? Colors.grey : Colors.green,
            ),
            onPressed: isRefreshing ? null : refreshServers,
            tooltip: 'Refresh Servers',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'Blizzard VPN',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2025 Blizzard VPN',
                children: [
                  Text('Core Version: ${coreVersion ?? 'N/A'}'),
                  Text(
                    'Selected Server: ${appState.selectedServer?.remark ?? 'None'}',
                    style: TextStyle(color: Colors.black),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      drawer: _buildUserDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomCard(
              title: 'Connection Status',
              child: ValueListenableBuilder<V2RayStatus>(
                valueListenable: v2rayStatus,
                builder: (context, status, child) {
                  // اصلاح: بررسی کنید که status.state برابر با "CONNECTED" باشد
                  final isConnected = status.state == "CONNECTED";

                  // حالا منطق رنگ و متن دکمه به درستی کار خواهد کرد
                  Color buttonColor = isConnected
                      ? Colors
                            .green // وقتی متصل است
                      : Colors
                            .black38; // وقتی قطع است (یا هر رنگ دیگری برای حالت قطع)

                  String buttonText = isConnected ? 'CONNECTED' : 'CONNECT';

                  if (isConnecting) {
                    buttonText = 'Connecting...';
                  } else if (isSubscriptionExpired) {
                    buttonColor = Colors.grey;
                  } else if (isDataExhausted) {
                    buttonColor = Colors.grey;
                  }

                  return Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: isSubscriptionExpired || isDataExhausted
                              ? Colors.grey[700]
                              : buttonColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: buttonColor.withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap:
                              (isSubscriptionExpired ||
                                  isDataExhausted ||
                                  isConnecting)
                              ? null
                              : _handleConnectDisconnect,
                          borderRadius: BorderRadius.circular(75),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isConnected
                                    ? Icons
                                          .power_settings_new // آیکون برای حالت متصل
                                    : Icons.power, // آیکون برای حالت قطع
                                size: 48,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                isSubscriptionExpired
                                    ? 'اتمام تاریخ'
                                    : isDataExhausted
                                    ? 'تمام حجم'
                                    : buttonText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'GM',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // نمایش وضعیت متنی
                      Text(
                        status
                            .state, // نیازی به .toUpperCase() نیست چون خودش هست
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isConnected ? Colors.green : Colors.redAccent,
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        height: MediaQuery.of(context).size.height * 0.14,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              textAlign: TextAlign.center,
                              status.duration,
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.arrow_upward,
                                      color: Colors.green,
                                    ),
                                    Text(
                                      'آپلود: ${status.uploadSpeed}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontFamily: 'SM',
                                        fontSize: 20,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 40),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.arrow_downward,
                                      color: Colors.red,
                                    ),
                                    Text(
                                      'دانلود: ${status.downloadSpeed}',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontFamily: 'SM',
                                        fontSize: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            CustomCard(
              title: 'Server Information',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.cloud_queue,
                      color: Colors.blueAccent,
                    ),
                    title: const Text(
                      'انتخاب سرور',
                      style: TextStyle(color: Colors.black, fontFamily: 'SM'),
                    ),
                    subtitle: Text(
                      AppState.instance.selectedServer?.remark.toString() ??
                          'سرور موجود نیست',

                      style: const TextStyle(color: Colors.black, fontSize: 15),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 25,
                      color: Colors.blue,
                    ),
                    onTap: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        '/server_selection',
                      );
                      if (result == true) {
                        setState(() {
                          // Server was selected, update UI
                        });
                      }
                    },
                  ),
                  if (appState.selectedServer != null) ...[
                    const Divider(color: Colors.grey),
                    ListTile(
                      leading: const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                      ),
                      title: const Text(
                        'آدرس',
                        style: TextStyle(color: Colors.black, fontFamily: 'SM'),
                      ),
                      subtitle: Text(
                        appState.selectedServer!.address,
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    const Divider(color: Colors.grey),
                    ListTile(
                      leading: const Icon(Icons.router, color: Colors.blue),
                      title: const Text(
                        'پورت',
                        style: TextStyle(color: Colors.black, fontFamily: 'SM'),
                      ),
                      subtitle: Text(
                        appState.selectedServer!.port.toString(),
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            CustomCard(
              title: 'Subscription Status',
              child: Column(
                children: [
                  _buildStatusRow(
                    'لینک سابسکریپشن:',
                    appState.subscriptionLink != null &&
                            appState.subscriptionLink!.isNotEmpty
                        ? 'Loaded'
                        : 'Not Loaded',
                    appState.subscriptionLink != null &&
                            appState.subscriptionLink!.isNotEmpty
                        ? Colors.green
                        : Colors.red,
                    Icons.link,
                  ),
                  const SizedBox(height: 8),
                  _buildStatusRow(
                    'وضعیت پروفایل:',
                    isProfileLoading
                        ? 'Loading...'
                        : userProfile != null
                        ? 'Loaded'
                        : 'Not Loaded',
                    userProfile != null ? Colors.green : Colors.red,
                    Icons.account_circle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(
    String label,
    String status,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const Spacer(),
        Text(
          status,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
