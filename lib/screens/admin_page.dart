// admin_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _urlController = TextEditingController();
  List<Map<String, dynamic>> _subscriptions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('subscription_links')
          .select()
          .order('created_at', ascending: false);
      setState(
        () => _subscriptions = List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading subscriptions: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addSubscription() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    if (!url.startsWith('vmess://') &&
        !url.startsWith('vless://') &&
        !url.startsWith('ss://') &&
        !url.startsWith('trojan://')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid URL format')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // غیرفعال کردن تمام لینک‌های قبلی
      await supabase
          .from('subscription_links')
          .update({'is_active': false})
          .neq('is_active', false);

      // اضافه کردن لینک جدید
      await supabase.from('subscription_links').insert({
        'url': url,
        'is_active': true,
      });

      _urlController.clear();
      await _loadSubscriptions();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding subscription: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final response = await supabase
        .from('users')
        .select('''*,
        connection_logs:connection_logs(count)''')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getExpiringUsers(int daysThreshold) async {
    final response = await supabase
        .from('users')
        .select()
        .lt(
          'expiry_date',
          DateTime.now().add(Duration(days: daysThreshold)).toIso8601String(),
        )
        .order('expiry_date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getHighUsageUsers(
    double thresholdPercent,
  ) async {
    final response = await supabase
        .from('users')
        .select()
        .filter(
          'data_usage',
          'gt',
          supabase.rpc(
            'multiply',
            params: {'a': 'data_limit', 'b': thresholdPercent},
          ),
        )
        .order('data_usage', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Subscriptions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Subscription URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _addSubscription,
                    child: const Text('Add Subscription'),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Current Subscriptions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _subscriptions.length,
                      itemBuilder: (context, index) {
                        final sub = _subscriptions[index];
                        return ListTile(
                          title: Text(sub['url']),
                          trailing: sub['is_active'] == true
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          onTap: () async {
                            await supabase
                                .from('subscription_links')
                                .update({'is_active': false})
                                .neq('is_active', false);

                            await supabase
                                .from('subscription_links')
                                .update({'is_active': true})
                                .eq('id', sub['id']);

                            await _loadSubscriptions();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
