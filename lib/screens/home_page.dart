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
  double _buttonScale = 1.0;
  bool _isAnimating = false;
  final supabase = Supabase.instance.client;
  var v2rayStatus = ValueNotifier<V2RayStatus>(V2RayStatus());
  late final flutterV2ray = FlutterV2ray(
    onStatusChanged: (status) {
      v2rayStatus.value = status;
    },
  );
  Widget _buildUserDrawer() {
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
                : [Colors.blue[900]!, Colors.blue[700]!],
          ),
        ),
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                userProfile?['full_name'] ?? 'Guest',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                supabase.auth.currentUser?.email ?? 'No email',
                style: TextStyle(fontSize: 14),
              ),
              currentAccountPicture: Image.asset('assets/images/logo.png'),
              decoration: BoxDecoration(color: Colors.transparent),
            ),
            if (isSubscriptionExpired)
              Container(
                padding: EdgeInsets.all(8),
                color: Colors.red[800],
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Subscription Expired',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
                    title: 'Expry Date',
                    value: userProfile?['expiry_date'] != null
                        ? date_utils.formatToJalali(userProfile!['expiry_date'])
                        : 'No Set',
                  ),
                  _buildDrawerDivider(),
                  _buildDrawerItem(
                    icon: Icons.data_usage,
                    title: 'Data Usage',
                    value: userProfile?['data_usage'] != null
                        ? '${_formatBytes(userProfile!['data_usage'])} / ${_formatBytes(userProfile!['data_limit'])}'
                        : '0 / 0',
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
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () {
                      // Navigate to settings page
                    },
                  ),
                  _buildDrawerDivider(),
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.white),
                    title: Text(
                      'Logout',
                      style: TextStyle(color: Colors.white),
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

      // بررسی انقضای اشتراک
      if (expiryDate != null && expiryDate.isBefore(DateTime.now())) {
        if (mounted) {
          _showSubscriptionExpiredSnackbar(); // نمایش پیام انقضا
        }
        await flutterV2ray.stopV2Ray(); // قطع اتصال VPN
        return;
      }

      // بررسی حجم مصرفی
      if (dataLimit > 0 && dataUsage >= dataLimit) {
        if (mounted) {
          _showErrorSnackbar('اشتراک شما به پایان رسیده است');
        }
        await flutterV2ray.stopV2Ray();
      }
    } catch (e) {
      debugPrint('Error checking user status: $e');
    }
  }

  void _showSubscriptionExpiredSnackbar() {
    CustomSnackbar.show(
      context: context,
      message: 'اشتراک شما منقضی شده است. برای ادامه، لطفاً تمدید کنید..',
      backgroundColor: Colors.orange,
      icon: Icons.warning,
      duration: const Duration(seconds: 5),
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
      leading: Icon(icon, color: Colors.white),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.white70)),
          if (value != null)
            Text(
              value,
              style: TextStyle(
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
                backgroundColor: Colors.blue[800],
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
      color: Colors.blue[800],
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
    );
  }

  String _formatDate(String dateString) {
    return date_utils.formatToJalali(dateString);
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  String? coreVersion;
  bool isConnecting = false;
  bool isRefreshing = false;
  Map<String, dynamic>? userProfile;
  bool isProfileLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _checkUserStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshServers();
    });
    _startPeriodicChecks();
  }

  @override
  void dispose() {
    _periodicCheckTimer?.cancel(); // توقف تایمر هنگام از بین رفتن ویجت
    super.dispose();
  }

  void _startPeriodicChecks() {
    // تایمر قبلی را لغو کنید اگر وجود دارد
    _periodicCheckTimer?.cancel();

    // تنظیم تایمر جدید برای بررسی هر 30 ثانیه
    _periodicCheckTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      await _checkUserStatus();
      await _updateUserProfileFromSupabase();
    });
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

  Future<void> updateUserDataUsage(String userId, int bytesUsed) async {
    await supabase
        .from('users')
        .update({
          'data_usage': supabase.rpc(
            'increment',
            params: {'column': 'data_usage', 'amount': bytesUsed},
          ),
        })
        .eq('id', userId);

    await supabase
        .from('users')
        .update({
          'data_usage': supabase.rpc('increment', params: {'value': bytesUsed}),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  Future<void> renewUserSubscription(String userId, int daysToAdd) async {
    await supabase
        .from('users')
        .update({
          'expiry_date': supabase.rpc(
            'add_days',
            params: {'date': 'expiry_date', 'num_days': daysToAdd},
          ),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  Future<void> increaseDataLimit(String userId, int additionalBytes) async {
    await supabase
        .from('users')
        .update({
          'data_limit': supabase.rpc(
            'increment',
            params: {'value': additionalBytes},
          ),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .single();

    return response;
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
    return 'Try Again';
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
    if (appState.selectedServer == null) {
      _showErrorSnackbar('No server selected');
      return;
    }

    // بررسی وضعیت اشتراک قبل از اتصال
    await _checkUserStatus();

    final isSubscriptionExpired =
        userProfile?['expiry_date'] != null &&
        DateTime.tryParse(
          userProfile!['expiry_date'],
        )!.isBefore(DateTime.now());

    final isDataExhausted =
        userProfile?['data_limit'] != null &&
        userProfile?['data_usage'] != null &&
        userProfile!['data_usage'] >= userProfile!['data_limit'];

    if (isSubscriptionExpired || isDataExhausted) {
      if (isSubscriptionExpired) {
        _showSubscriptionExpiredSnackbar();
      } else if (isDataExhausted) {
        _showErrorSnackbar('حجم مصرفی شما به پایان رسیده است');
      }
      return;
    }

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
      await flutterV2ray.stopV2Ray();
    } finally {
      if (mounted) {
        setState(() => isConnecting = false);
      }
    }
  }
  // Future<void> connect() async {
  //   final appState = AppState.instance;
  //   if (appState.selectedServer == null) return;

  //   setState(() => isConnecting = true);

  //   try {
  //     final user = supabase.auth.currentUser;
  //     if (user == null) throw Exception('User not authenticated');

  //     await _checkUserStatus(); // بررسی وضعیت قبل از اتصال

  //     if (await flutterV2ray.requestPermission()) {
  //       await flutterV2ray.startV2Ray(
  //         remark: appState.selectedServer!.remark,
  //         config: appState.selectedServer!.getFullConfiguration(),
  //         proxyOnly: false,
  //         bypassSubnets: [],
  //         notificationDisconnectButtonName: "DISCONNECT",
  //       );

  //       await _logConnection(user.id, appState.selectedServer!.remark);
  //       setState(() {}); // Force UI update
  //     } else {
  //       _showErrorSnackbar('Permission denied');
  //     }
  //   } catch (e) {
  //     if (e.toString().contains('BadParcelableException')) {
  //       await flutterV2ray.stopV2Ray();
  //       await Future.delayed(Duration(seconds: 1));
  //       await connect(); // تلاش مجدد
  //     } else {
  //       _showErrorSnackbar('Connection error: $e');
  //     }
  //   }
  // }

  Future<void> _logConnection(String userId, String server) async {
    await supabase.from('connection_logs').insert({
      'user_id': userId,
      'server': server,
      'connected_at': DateTime.now().toIso8601String(),
    });
  }

  void _showErrorSnackbar(String message) {
    CustomSnackbar.info(context: context, message: message);
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
            icon: isRefreshing
                ? const CircularProgressIndicator()
                : const Icon(Icons.refresh),
            onPressed: isRefreshing ? null : refreshServers,
            tooltip: 'Refresh Servers',
          ),
        ],
      ),
      drawer: _buildUserDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildUserProfileCard(user),
            const SizedBox(height: 20),
            _buildServerCard(appState),

            const SizedBox(height: 20),
            _buildConnectionStatus(),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: _buildConnectButton(),
            ),
            // const Spacer(),
            // if (coreVersion != null)
            //   Text(
            //     'V2Ray Core v$coreVersion',
            //     style: TextStyle(color: Colors.grey[600]),
            //   ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileCard(User? user) {
    final isSubscriptionExpired = false; // همان شرط قبلی
    final dataExhausted = isDataExhausted; // استفاده از متغیر جدید

    return CustomCard(
      isErrorState: isSubscriptionExpired || isDataExhausted,
      child: Column(
        children: [
          ListTile(
            leading: Image.asset('assets/images/logo.png'),
            title: Text(
              userProfile?['full_name'] ?? 'Guest User',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (userProfile?['expiry_date'] != null)
                  Text(
                    _formatDate(userProfile!['expiry_date']),
                    style: TextStyle(
                      fontSize: 12,
                      color: isSubscriptionExpired || isDataExhausted
                          ? Colors.red[100]
                          : Colors.white,
                    ),
                  ),
                if (isSubscriptionExpired || isDataExhausted)
                  Text(
                    isSubscriptionExpired
                        ? 'اشتراک شما به پایان رسیده'
                        : 'اشتراک شما به پایان رسیده',
                    style: TextStyle(
                      color: Colors.red[100],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          if (isProfileLoading) const LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildServerCard(AppState appState) {
    return CustomCard(
      child: ListTile(
        title: const Text(
          'Select Server',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        subtitle: Text(
          appState.selectedServer?.remark ?? 'No server selected',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final result = await Navigator.pushNamed(context, '/servers');
          if (result == true) {
            setState(() {});
          }
        },
      ),
    );
  }

  Future<void> _updateDataUsage(int bytesUsed) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // دریافت مقدار فعلی
      final response = await supabase
          .from('users')
          .select('data_usage')
          .eq('id', user.id)
          .single();

      final currentUsage = response['data_usage'] ?? 0;

      // آپدیت مقدار جدید
      await supabase
          .from('users')
          .update({
            'data_usage': currentUsage + bytesUsed,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      debugPrint('Updated data usage to ${currentUsage + bytesUsed}');
    } catch (e, stackTrace) {
      debugPrint('Error updating data usage: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Widget _buildConnectionStatus() {
    return ValueListenableBuilder<V2RayStatus>(
      valueListenable: v2rayStatus,
      builder: (context, status, _) {
        if (status.state == 'CONNECTED') {
          final bytesUsed = (status.uploadSpeed + status.downloadSpeed) * 30;
          _updateDataUsage(bytesUsed);
        }
        return CustomCard(
          child: Column(
            children: [
              const SizedBox(height: 10),
              if (status.state == 'CONNECTED') ...[
                Text(' ${status.duration}', style: TextStyle(fontSize: 24)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSpeedIndicator(
                      Icons.upload,
                      _formatSpeed(status.uploadSpeed),
                      Colors.blue,
                    ),
                    _buildSpeedIndicator(
                      Icons.download,
                      _formatSpeed(status.downloadSpeed),
                      Colors.green,
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatSpeed(int speed) {
    if (speed < 1024) {
      return '$speed B/s';
    } else if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  Widget _buildSpeedIndicator(IconData icon, String speed, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          speed,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildConnectButton() {
    return ValueListenableBuilder<V2RayStatus>(
      valueListenable: v2rayStatus,
      builder: (context, status, _) {
        final isConnected = status.state == 'CONNECTED';
        final buttonText = isConnected ? 'DISCONNECT' : 'CONNECT';
        final buttonColor = isConnected ? Colors.red : Colors.green;

        // بررسی انقضای اشتراک
        final expiryDate = userProfile?['expiry_date'] != null
            ? DateTime.tryParse(userProfile!['expiry_date'])
            : null;
        final isSubscriptionExpired =
            expiryDate != null && expiryDate.isBefore(DateTime.now());

        return Center(
          child: GestureDetector(
            onTap: isSubscriptionExpired || isDataExhausted
                ? null // غیرفعال کردن دکمه اگر اشتراک تمام شده یا حجم مصرفی تمام شده باشد
                : () async {
                    if (isConnected) {
                      await flutterV2ray.stopV2Ray();
                    } else {
                      await connect();
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: isSubscriptionExpired ? Colors.grey : buttonColor,
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isConnected ? Icons.power_settings_new : Icons.power,
                    size: 32,
                    color: Colors.white,
                  ),
                  SizedBox(height: 8),
                  Text(
                    isSubscriptionExpired
                        ? 'EXPIRED'
                        : isDataExhausted
                        ? 'NO DATA'
                        : buttonText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
}
