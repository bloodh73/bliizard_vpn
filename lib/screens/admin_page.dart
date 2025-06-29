// lib/screens/admin_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/date_utils.dart' as date_utils;
import 'package:blizzard_vpn/components/custom_snackbar.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;
  // ignore: unused_field
  int _currentTabIndex = 0;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _subscriptions = [];
  bool _isLoading = false;
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }
    _verifyAdminStatus(user.id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _verifyAdminStatus(String userId) async {
    try {
      final response = await supabase
          .from('users')
          .select('is_admin')
          .eq('id', userId)
          .single();

      if (response['is_admin'] != true) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Access denied. You are not an admin.',
            backgroundColor: Colors.redAccent,
            icon: Icons.security_update,
          );
          Navigator.pop(context);
        }
        return;
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error verifying admin status: ${e.toString()}',
          backgroundColor: Colors.redAccent,
          icon: Icons.error,
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      debugPrint('Fetching users data...');
      // Ensure this query fetches ALL users, regardless of admin status.
      // RLS policies in Supabase are crucial here.
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
        CustomSnackbar.show(
          context: context,
          message: 'Error loading data: ${e.toString()}',
          backgroundColor: Colors.redAccent,
          icon: Icons.error,
        );
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
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'User updated successfully!',
          backgroundColor: Colors.green,
          icon: Icons.check_circle,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error updating user: ${e.toString()}',
          backgroundColor: Colors.redAccent,
          icon: Icons.error,
        );
      }
    }
  }

  Future<void> _addSubscription() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Subscription URL cannot be empty.',
          backgroundColor: Colors.orange,
          icon: Icons.info,
        );
      }
      return;
    }

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
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Subscription added and activated successfully!',
          backgroundColor: Colors.green,
          icon: Icons.check_circle,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error adding subscription: ${e.toString()}',
          backgroundColor: Colors.redAccent,
          icon: Icons.error,
        );
      }
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
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Subscription activated successfully!',
          backgroundColor: Colors.green,
          icon: Icons.check_circle,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error activating subscription: ${e.toString()}',
          backgroundColor: Colors.redAccent,
          icon: Icons.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Panel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorAnimation: TabIndicatorAnimation.elastic,
          dividerColor: Colors.transparent,
          indicatorPadding: const EdgeInsets.symmetric(horizontal: 16),
          controller: _tabController,
          onTap: (index) => setState(() => _currentTabIndex = index),
          indicatorColor: Theme.of(context).colorScheme.secondary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'Subscriptions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildUsersTab(), _buildSubscriptionsTab()],
      ),
    );
  }

  Widget _buildUsersTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _loadData, child: _buildUsersList());
  }

  Widget _buildUsersList() {
    return _users.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No users found.',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              final isExpired =
                  user['expiry_date'] != null &&
                  DateTime.tryParse(
                    user['expiry_date'],
                  )!.isBefore(DateTime.now());
              final isDataExhausted =
                  user['data_limit'] != null &&
                  user['data_usage'] != null &&
                  user['data_usage'] >= user['data_limit'];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              user['full_name'] ?? 'Unknown User',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user['is_admin'] == true)
                            Chip(
                              label: const Text('Admin'),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondary.withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        user['email'] ?? 'No Email',
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                      const Divider(height: 20, thickness: 0.5),
                      _buildUserInfoRow(
                        icon: Icons.calendar_today,
                        label: 'Expiry Date:',
                        value: user['expiry_date'] != null
                            ? date_utils.formatToJalali(user['expiry_date'])
                            : 'Not Set',
                        valueColor: isExpired ? Colors.red : Colors.green,
                      ),
                      const SizedBox(height: 8),
                      _buildUserInfoRow(
                        icon: Icons.data_usage,
                        label: 'Data Usage:',
                        value:
                            '${user['data_usage'] ?? 0} / ${user['data_limit'] ?? 0} MB',
                        valueColor: isDataExhausted ? Colors.red : Colors.green,
                      ),
                      const SizedBox(height: 8),
                      _buildUserInfoRow(
                        icon: Icons.vpn_lock,
                        label: 'Subscription Type:',
                        value:
                            (user['subscription_type'] as String?)
                                ?.toUpperCase() ??
                            'N/A',
                        valueColor: Colors.blueAccent,
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: TextButton.icon(
                          onPressed: () => _showEditUserDialog(user),
                          icon: Icon(
                            Icons.edit,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          label: Text(
                            'Edit',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget _buildUserInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 15, color: Colors.white70),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final TextEditingController emailController = TextEditingController(
      text: user['email'],
    );
    final TextEditingController fullNameController = TextEditingController(
      text: user['full_name'],
    );
    final TextEditingController dataLimitController = TextEditingController(
      text: user['data_limit']?.toString() ?? '',
    );
    // Initialize daysTillExpiry from expiry_date
    final TextEditingController daysTillExpiryController =
        TextEditingController();
    if (user['expiry_date'] != null) {
      final expiryDateTime = DateTime.parse(user['expiry_date']);
      final now = DateTime.now();
      final difference = expiryDateTime.difference(now);
      daysTillExpiryController.text = difference.inDays.toString();
    }

    final List<String> validSubscriptionTypes = [
      'free',
      'premium',
      'multi_user',
    ];
    String? initialSubscriptionType = (user['subscription_type'] as String?)
        ?.trim()
        .toLowerCase();
    String? selectedSubscriptionType =
        validSubscriptionTypes.contains(initialSubscriptionType)
        ? initialSubscriptionType
        : null;

    bool isAdmin = user['is_admin'] ?? false;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            'Edit User: ${user['full_name'] ?? user['email']}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setInnerState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(
                          Icons.email,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: dataLimitController,
                      decoration: InputDecoration(
                        labelText: 'Data Limit (MB)',
                        prefixIcon: Icon(
                          Icons.data_usage,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: daysTillExpiryController,
                      decoration: InputDecoration(
                        labelText: 'Subscription Expiry in Days (from now)',
                        hintText: 'e.g., 30 for 30 days',
                        prefixIcon: Icon(
                          Icons.calendar_today,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: selectedSubscriptionType,
                      decoration: InputDecoration(
                        labelText: 'Subscription Type',
                        prefixIcon: Icon(
                          Icons.vpn_lock,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      style: TextStyle(color: Colors.white),
                      items: validSubscriptionTypes
                          .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value.toUpperCase(),
                                style: TextStyle(color: Colors.white),
                              ),
                            );
                          })
                          .toList(),
                      onChanged: (String? newValue) {
                        setInnerState(() {
                          selectedSubscriptionType = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    CheckboxListTile(
                      title: Text(
                        'Is Admin',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: isAdmin,
                      onChanged: (bool? value) {
                        setInnerState(() {
                          isAdmin = value ?? false;
                        });
                      },
                      activeColor: Theme.of(context).colorScheme.secondary,
                      checkColor: Colors.white,
                      tileColor: Theme.of(context).colorScheme.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Save'),
              onPressed: () async {
                Navigator.of(context).pop();

                // Calculate new expiry date based on days entered
                DateTime? newExpiryDate;
                if (daysTillExpiryController.text.isNotEmpty) {
                  final days = int.tryParse(daysTillExpiryController.text);
                  if (days != null) {
                    newExpiryDate = DateTime.now().add(Duration(days: days));
                  }
                }

                await _updateUser(user['id'], {
                  'email': emailController.text.trim(),
                  'full_name': fullNameController.text.trim(),
                  'data_limit': int.tryParse(dataLimitController.text),
                  'subscription_type': selectedSubscriptionType,
                  'is_admin': isAdmin,
                  'expiry_date': newExpiryDate
                      ?.toIso8601String(), // Save as ISO 8601 string
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubscriptionsTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            labelText: 'New Subscription URL',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            suffixIcon: _isLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : null,
                          ),
                          enabled: !_isLoading,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _addSubscription,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                        ),
                        child: const Text('Add & Activate'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _subscriptions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'No subscriptions found.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: _loadData,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Refresh'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _subscriptions.length,
                          itemBuilder: (context, index) {
                            final sub = _subscriptions[index];
                            final isActive = sub['is_active'] == true;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: Theme.of(context).colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isActive
                                      ? Theme.of(context).colorScheme.secondary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(
                                  'Subscription ID: ${sub['id']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Added: ${date_utils.formatToJalali(sub['created_at'])}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      sub['url'] ?? 'N/A',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isActive
                                            ? Colors.white
                                            : Colors.white70,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                trailing: isActive
                                    ? const Text(
                                        'Active',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: () => _activateSubscription(
                                          sub['id'].toString(),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text('Activate'),
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
  }
}
