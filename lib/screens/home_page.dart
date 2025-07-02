import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:blizzard_vpn/components/custom_card.dart';
import 'package:blizzard_vpn/components/custom_color.dart'; // Assuming custom_color.dart defines primery
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
    if (userProfile == null ||
        userProfile!['data_limit'] == null ||
        userProfile!['data_usage_down'] == null ||
        userProfile!['data_usage_up'] == null) {
      return false; // اگر اطلاعات کافی نیست، فرض می‌کنیم داده تمام نشده.
    }
    final totalUsage =
        (userProfile!['data_usage_down'] as int) +
        (userProfile!['data_usage_up'] as int);
    final dataLimit = userProfile!['data_limit'] as int;
    return totalUsage >= dataLimit;
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
      _showErrorSnackbar('لطفا ابتدا سرور را انتخاب کنید.');
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
            _showErrorSnackbar('اجازه رد شد. نمی‌توان به VPN متصل شد..'); //
          }
        }
      }
    } catch (e) {
      _showErrorSnackbar('خطای اتصال: $e');
    } finally {
      setState(() => isConnecting = false);
    }
  }

  void connect() async {
    if (await flutterV2ray.requestPermission()) {
      // Permission request happens here
      flutterV2ray.startV2Ray(
        remark: remark,

        notificationDisconnectButtonName: "اتصال برقرار نیست",
        config: '',
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('دسترسی رد شد')));
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
      _showErrorSnackbar('مقداردهی اولیه V2Ray انجام نشد: $e');
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
      _showErrorSnackbar('بارگیری پروفایل ناموفق بود: $e');
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
          _showErrorSnackbar('اطلاعات اشتراک تمام شد!');
        }
        await flutterV2ray.stopV2Ray();
      }
    } catch (e) {
      debugPrint('خطا در بررسی وضعیت کاربر: $e');
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
      debugPrint('خطا در به‌روزرسانی پروفایل کاربر: $e');
    }
  }

  void _showSubscriptionExpiredSnackbar() {
    CustomSnackbar.show(
      context: context,
      message: 'اشتراک شما منقضی شده است. برای ادامه، لطفاً تمدید کنید.',
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
        throw Exception('آدرس اینترنتی نامعتبر است: $subscriptionLink');
      }

      final servers = await _downloadAndParseSubscription(subscriptionLink);
      setState(() {
        appState.subscriptionLink = subscriptionLink;
        appState.servers = servers;
        appState.selectedServer = servers.isNotEmpty ? servers.first : null;
      });
    } catch (e) {
      _showErrorSnackbar('خطا در بارگیری اشتراک: ${e.toString()}');
      await _tryFallbackConnection(appState);
    } finally {
      setState(() => isRefreshing = false);
    }
  }

  String _getFallbackUrl() {
    return "vmess://eyJhZGQiOiIxMjcuMC4wLjEiLCJhaWQiOiIwIiwiYWxwbiI6IiIsImhvc3QiOiIiLCJpZCI6IjAwMDAwMDAwLTAwMDAtMDAwMC0wMDAwLTAwMDAwMDAwMDAwMCIsIm5ldCI6InRjcCIsInBhdGgiOiIiLCJwb3J0IjoiNDQzIiwicHMyIjoiZnJlZSBzZXJ2ZXIiLCJzY3kiOiJhdXRvIiwicmVtYXJrIjoiZnJlZSBzZXJ2ZXIiLCJzbmkiOiIiLCJ0bHMiOiIiLCJ0eXBlIjoiaHR0cCJ9";
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
          throw Exception('دانلود اشتراک ناموفق بود');
        }
        final content = String.fromCharCodes(base64Decode(response.body));
        final servers = content.split('\n');
        final validServers = <V2RayURL>[];
        for (var server in servers) {
          if (server.trim().isNotEmpty) {
            try {
              validServers.add(FlutterV2ray.parseFromURL(server));
            } catch (e) {
              debugPrint('سرور تجزیه نشد: $server, Error: $e');
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
          'بارگیری اشتراک، با استفاده از سرور جایگزین، ناموفق بود.',
        );
      }
    } catch (e) {
      _showErrorSnackbar('بارگیری سرور پشتیبان ناموفق بود: $e');
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
                child: const Text('ارسال کنید'),
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
      _showErrorSnackbar('خروج ناموفق بود: $e');
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CustomColor.primery.withOpacity(0.9), // Using CustomColor
              CustomColor.primery,
            ],
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
                  color:
                      Colors.white, // Ensure text is visible on dark background
                ),
              ),
              accountEmail: Text(
                supabase.auth.currentUser?.email ?? 'ایمیل موجود نیست',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ), // Softer color for email
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(
                  0.2,
                ), // Lighter circle avatar
                child: Text(
                  userProfile?['full_name']?.toUpperCase() ?? 'شما',
                  style: const TextStyle(fontSize: 32, color: Colors.white),
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
                        'اشتراک منقضی شده است! لطفا تمدید کنید.',
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
                        : 'تنظیم نشده',
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
                        color: CustomColor.secondary, // Using CustomColor
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
                    leading: const Icon(
                      Icons.settings,
                      color: Colors.white70,
                    ), // Softer icon color
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
                    leading: const Icon(
                      Icons.logout,
                      color: Colors.white70,
                    ), // Softer icon color
                    title: const Text(
                      'خروج از حساب',
                      style: TextStyle(color: Colors.white, fontFamily: 'SM'),
                    ),
                    onTap: _handleLogout,
                  ),
                ],
              ),
            ),
            Text(
              'Hamed Karimi Zadeh',
              style: TextStyle(
                color: Colors.grey.shade200,
                fontFamily: 'GB',
                fontSize: 10,
              ),
            ),
            SizedBox(height: 10),
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
      leading: Icon(icon, color: Colors.white), // Stronger white for icons
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white),
          ), // Stronger white for title
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
                backgroundColor:
                    Colors.white30, // Slightly more opaque background
                valueColor: AlwaysStoppedAnimation<Color>(
                  progressValue > 0.8
                      ? Colors
                            .redAccent // Red for high usage
                      : (progressValue > 0.5
                            ? Colors.orangeAccent
                            : Colors
                                  .greenAccent), // Orange for medium, green for low
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
      color: Colors.blue[900]?.withOpacity(
        0.6,
      ), // Darker, more prominent divider
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
      // Apply a subtle background to the entire scaffold body
      backgroundColor: Colors.grey[50], // Very light grey background
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: CustomColor.primery, // Using CustomColor
        backgroundColor: CustomColor.primery, // Using CustomColor
        title: Text(
          userProfile?['full_name'] ?? 'مهمان',
          style: const TextStyle(
            color: Colors.white, // Changed to white for better contrast
            fontFamily: 'SM',
            fontSize: 20, // Slightly larger title
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white), // White icon
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isRefreshing
                  ? Colors.grey
                  : Colors.white, // White icon for refresh
            ),
            onPressed: isRefreshing ? null : refreshServers,
            tooltip: 'Refresh Servers',
          ),
          IconButton(
            icon: const Icon(
              Icons.info_outline,
              color: Colors.white70,
            ), // White icon
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'Blizzard VPN',
                applicationVersion: '1.0.1',
                applicationLegalese: '© 2025 Blizzard VPN',
                children: [
                  Text('Core Version: ${coreVersion ?? 'N/A'}'),
                  Text(
                    'Selected Server: ${appState.selectedServer?.remark ?? 'None'}',
                    style: const TextStyle(color: Colors.black),
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
              title: 'وضعیت اتصال',
              child: ValueListenableBuilder<V2RayStatus>(
                valueListenable: v2rayStatus,
                builder: (context, status, child) {
                  final isConnected = status.state == "CONNECTED";

                  Color buttonColor = isConnected
                      ? Colors
                            .green
                            .shade600 // Deeper green when connected
                      : Colors.redAccent.shade400; // More vibrant redAccent

                  String buttonText = isConnected ? 'CONNECTED' : 'CONNECT';

                  if (isConnecting) {
                    buttonText = 'Connecting...';
                  } else if (isSubscriptionExpired) {
                    buttonColor =
                        Colors.grey.shade600; // Darker grey for disabled
                  } else if (isDataExhausted) {
                    buttonColor =
                        Colors.grey.shade600; // Darker grey for disabled
                  }

                  return Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 160, // Slightly larger button
                        height: 160,
                        decoration: BoxDecoration(
                          color: isSubscriptionExpired || isDataExhausted
                              ? Colors.grey[700]
                              : buttonColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: buttonColor.withOpacity(
                                0.6,
                              ), // More prominent glow
                              blurRadius: 20, // Increased blur
                              spreadRadius: 7, // Increased spread
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
                          borderRadius: BorderRadius.circular(
                            80,
                          ), // Match new size
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isConnected
                                    ? Icons.power_settings_new
                                    : Icons.power,
                                size: 55, // Larger icon
                                color: Colors.white,
                              ),
                              const SizedBox(height: 12), // More space
                              Text(
                                isSubscriptionExpired
                                    ? 'اتمام تاریخ'
                                    : isDataExhausted
                                    ? 'تمام حجم'
                                    : buttonText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20, // Larger text
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'GM',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 25), // More space
                      // نمایش وضعیت متنی
                      Text(
                        status.state,
                        style: TextStyle(
                          fontSize: 18, // Larger status text
                          fontWeight: FontWeight.w700, // Bolder
                          color: isConnected
                              ? Colors.green.shade700
                              : Colors.redAccent.shade700, // Deeper colors
                        ),
                      ),
                      const SizedBox(height: 15), // More space
                      Container(
                        height:
                            MediaQuery.of(context).size.height *
                            0.16, // Slightly larger container
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors
                              .blueGrey[50], // Subtle background for traffic stats
                          border: Border.all(
                            color: Colors.grey.shade300,
                          ), // Lighter border
                          borderRadius: BorderRadius.circular(
                            15,
                          ), // Consistent rounded corners
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              textAlign: TextAlign.center,
                              status.duration,
                              style: const TextStyle(
                                color: Colors
                                    .indigo, // Distinct color for duration
                                fontSize: 24, // Larger duration text
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_upward,
                                        color: Colors
                                            .green
                                            .shade700, // Deeper green
                                        size: 28,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'آپلود',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontFamily: 'SM',
                                              fontSize: 18,
                                            ),
                                          ),
                                          Text(
                                            status.uploadSpeed.toString(),
                                            style: const TextStyle(
                                              color: CustomColor.darkBackground,
                                              fontFamily: 'SM',
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 60,
                                  width: 1,
                                  color: Colors
                                      .grey
                                      .shade300, // Divider between stats
                                ),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_downward,
                                        color:
                                            Colors.red.shade700, // Deeper red
                                        size: 28,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'دانلود',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontFamily: 'SM',
                                              fontSize: 18,
                                            ),
                                          ),
                                          Text(
                                            status.downloadSpeed.toString(),
                                            style: const TextStyle(
                                              color: CustomColor.darkBackground,
                                              fontFamily: 'SM',
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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
            // const SizedBox(height: 10), // More space between cards
            CustomCard(
              title: 'اطلاعات سرور',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.cloud_queue,
                      color: CustomColor.secondary, // Using CustomColor
                      size: 20, // Larger icon
                    ),
                    title: const Text(
                      'انتخاب سرور',
                      style: TextStyle(
                        color: Colors.black87, // Slightly darker
                        fontFamily: 'SM',
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      AppState.instance.selectedServer?.remark.toString() ??
                          'سرور موجود نیست',
                      style: const TextStyle(
                        color: Colors.black54, // Softer subtitle
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 25, // Slightly smaller arrow
                      color: CustomColor.secondary, // Using CustomColor
                    ),
                    // trailing: RotatedBox(
                    //   quarterTurns: 5,
                    //   child: Text('کلیک کنید'),
                    // ),
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
                    // Divider(
                    //   color: Colors.grey.shade300,
                    //   height: 1,
                    // ), // Lighter divider
                    // // ListTile(
                    // //   leading: const Icon(
                    // //     Icons.info_outline,
                    // //     color: CustomColor.secondary, // Using CustomColor
                    // //     size: 28,
                    // //   ),
                    // //   title: const Text(
                    // //     'آدرس',
                    // //     style: TextStyle(
                    // //       color: Colors.black87,
                    // //       fontFamily: 'SM',
                    // //       fontSize: 17,
                    // //     ),
                    // //   ),
                    // //   subtitle: Text(
                    // //     appState.selectedServer!.address,
                    // //     style: const TextStyle(
                    // //       color: Colors.black54,
                    // //       fontSize: 16,
                    // //       fontWeight: FontWeight.w500,
                    // //     ),
                    // //   ),
                    // // ),
                    // // Divider(color: Colors.grey.shade300, height: 1),
                    // // ListTile(
                    // //   leading: const Icon(
                    // //     Icons.router,
                    // //     color: CustomColor.secondary,
                    // //     size: 28,
                    // //   ), // Using CustomColor
                    // //   title: const Text(
                    // //     'پورت',
                    // //     style: TextStyle(
                    // //       color: Colors.black87,
                    // //       fontFamily: 'SM',
                    // //       fontSize: 17,
                    // //     ),
                    // //   ),
                    //   subtitle: Text(
                    //     appState.selectedServer!.port.toString(),
                    //     style: const TextStyle(
                    //       color: Colors.black54,
                    //       fontSize: 16,
                    //       fontWeight: FontWeight.w500,
                    //     ),
                    //   ),
                    // ),
                  ],
                ],
              ),
            ),
            // const SizedBox(height: 10),
            CustomCard(
              title: 'وضعیت اشتراک',
              child: Column(
                children: [
                  _buildStatusRow(
                    'لینک سابسکریپشن:',
                    appState.subscriptionLink != null &&
                            appState.subscriptionLink!.isNotEmpty
                        ? '✅'
                        : '❌',
                    appState.subscriptionLink != null &&
                            appState.subscriptionLink!.isNotEmpty
                        ? Colors.green.shade600
                        : Colors.red.shade600,
                    Icons.link,
                  ),
                  const SizedBox(height: 12), // More space between rows
                  _buildStatusRow(
                    'وضعیت پروفایل:',

                    userProfile != null ? '✅' : '❌',
                    userProfile != null
                        ? Colors.green.shade600
                        : Colors.red.shade600,
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
        Icon(icon, color: color, size: 22), // Slightly larger icon
        const SizedBox(width: 15), // More space
        Text(
          label,
          style: const TextStyle(
            fontSize: 16, // Slightly larger label
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        Text(
          status,
          style: TextStyle(
            fontSize: 16, // Slightly larger status text
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
