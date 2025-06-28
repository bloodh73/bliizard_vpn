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
  int _currentTabIndex = 0;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _subscriptions = [];
  bool _isLoading = false;
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    if (user == null) {
      Navigator.pop(context);
      return;
    }
    _verifyAdminStatus(user.id);
  }

  Future<void> _verifyAdminStatus(String userId) async {
    final response = await supabase
        .from('users')
        .select('is_admin')
        .eq('id', userId)
        .single();

    if (response['is_admin'] != true) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Access denied')));
        Navigator.pop(context);
      }
      return;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      debugPrint('Fetching users data...');
      final usersResponse = await supabase
          .from('users')
          .select()
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      debugPrint('Users data fetched: ${usersResponse.length} items');

      debugPrint('Fetching subscriptions data...');
      final subsResponse = await supabase
          .from('subscription_links')
          .select()
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      debugPrint('Subscriptions data fetched: ${subsResponse.length} items');

      if (!mounted) return;

      setState(() {
        _users = List<Map<String, dynamic>>.from(usersResponse);
        _subscriptions = List<Map<String, dynamic>>.from(subsResponse);
      });
    } catch (e, stackTrace) {
      debugPrint('Error in _loadData: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      await supabase.from('users').update(updates).eq('id', userId);
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating user: $e')));
    }
  }

  Future<void> _addSubscription() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // Deactivate all other subscriptions
      await supabase
          .from('subscription_links')
          .update({'is_active': false})
          .neq('is_active', false);

      // Add new subscription
      await supabase.from('subscription_links').insert({
        'url': url,
        'is_active': true,
      });

      _urlController.clear();
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding subscription: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _activateSubscription(String id) async {
    try {
      // Deactivate all other subscriptions
      await supabase
          .from('subscription_links')
          .update({'is_active': false})
          .neq('is_active', false);

      // Activate selected one
      await supabase
          .from('subscription_links')
          .update({'is_active': true})
          .eq('id', id);

      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error activating subscription: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          onTap: (index) => setState(() => _currentTabIndex = index),
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.link), text: 'Subscriptions'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentTabIndex == 0
          ? _buildUsersList()
          : _buildSubscriptionsList(),
    );
  }

  Widget _buildUsersList() {
    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text(user['email']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin: ${user['is_admin'] ?? false}'),
                if (user['expiry_date'] != null)
                  Text('Expires: ${user['expiry_date']}'),
                Text(
                  'Data: ${user['data_usage'] ?? 0}/${user['data_limit'] ?? 0} MB',
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditUserDialog(user),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionsList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'New Subscription URL',
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
                  onTap: () => _activateSubscription(sub['id']),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final expiryController = TextEditingController(
      text: user['expiry_date'] ?? '',
    );
    final dataLimitController = TextEditingController(
      text: (user['data_limit'] ?? 0).toString(),
    );
    bool isAdmin = user['is_admin'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Edit ${user['email']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: expiryController,
                  decoration: const InputDecoration(
                    labelText: 'Expiry Date (YYYY-MM-DD)',
                  ),
                ),
                TextField(
                  controller: dataLimitController,
                  decoration: const InputDecoration(
                    labelText: 'Data Limit (MB)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                CheckboxListTile(
                  title: const Text('Is Admin'),
                  value: isAdmin,
                  onChanged: (value) {
                    setState(() => isAdmin = value ?? false);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final updates = {
                    'expiry_date': expiryController.text,
                    'data_limit': int.tryParse(dataLimitController.text) ?? 0,
                    'is_admin': isAdmin,
                  };
                  await _updateUser(user['id'], updates);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
