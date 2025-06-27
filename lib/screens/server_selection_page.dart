import 'package:blizzard_vpn/models/app_state.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServerSelectionPage extends StatefulWidget {
  const ServerSelectionPage({super.key});

  @override
  State<ServerSelectionPage> createState() => _ServerSelectionPageState();
}

class _ServerSelectionPageState extends State<ServerSelectionPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = false;

  Future<void> fetchSubscriptionFromSupabase() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      // دریافت لینک ساب‌اسکریپشن فعال از Supabase
      final response = await supabase
          .from('subscription_links')
          .select()
          .eq('is_active', true)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        final subscriptionLink = response['url'] as String;
        final appState = AppState.instance;
        appState.subscriptionLink = subscriptionLink;
        appState.servers = [FlutterV2ray.parseFromURL(subscriptionLink)];
        appState.selectedServer = appState.servers.first;
        if (mounted) setState(() {});
      } else {
        throw Exception('No active subscription found');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppState.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Server'),
        actions: [
          IconButton(
            icon: isLoading
                ? const CircularProgressIndicator()
                : const Icon(Icons.refresh),
            onPressed: isLoading ? null : fetchSubscriptionFromSupabase,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: appState.servers.length,
        itemBuilder: (context, index) {
          final server = appState.servers[index];
          return Card(
            child: ListTile(
              title: Text(server.remark),
              trailing: appState.selectedServer == server
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                appState.selectedServer = server;
                Navigator.pop(context);
              },
            ),
          );
        },
      ),
    );
  }
}
