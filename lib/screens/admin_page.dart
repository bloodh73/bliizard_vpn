// lib/screens/admin_page.dart
import 'package:blizzard_vpn/components/custom_color.dart';
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

  Future<void> _addUser(Map<String, dynamic> newUser) async {
    try {
      await supabase.from('users').insert(newUser);
      await _loadData();
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'User added successfully!',
          backgroundColor: Colors.green,
          icon: Icons.check_circle,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error adding user: ${e.toString()}',
          backgroundColor: Colors.redAccent,
          icon: Icons.error,
        );
      }
    }
  }

  void _showAddUserDialog() {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController fullNameController = TextEditingController();
    final TextEditingController dataLimitController = TextEditingController();
    final TextEditingController expiryDateController = TextEditingController();
    bool isAdmin = false;
    String subscriptionType = 'free';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('افزودن کاربر جدید'), // New title
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'ایمیل'),
                ),
                SizedBox(height: 15),
                TextField(
                  controller: fullNameController,
                  decoration: const InputDecoration(labelText: 'نام'),
                ),
                SizedBox(height: 15),
                TextField(
                  controller: dataLimitController,
                  decoration: const InputDecoration(labelText: 'حجم (GB)'),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 15),
                TextField(
                  controller: expiryDateController,
                  decoration: const InputDecoration(labelText: 'تاریخ انقضا'),
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      expiryDateController.text = pickedDate.toIso8601String();
                    }
                  },
                ),
                SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: subscriptionType,
                  decoration: const InputDecoration(labelText: 'نوع اشتراک'),
                  items: <String>['free', 'premium', 'vip']
                      .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      })
                      .toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        // Use setState to update the dropdown value
                        subscriptionType = newValue;
                      });
                    }
                  },
                ),
                SizedBox(height: 15),
                Row(
                  children: [
                    const Text('ادمین:'),
                    Checkbox(
                      value: isAdmin,
                      onChanged: (bool? value) {
                        if (value != null) {
                          setState(() {
                            // <--- Add setState here
                            isAdmin = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final int? dataLimitBytes =
                    (double.tryParse(dataLimitController.text) != null
                            ? double.parse(dataLimitController.text) *
                                  (1024 * 1024 * 1024)
                            : null)
                        ?.toInt();
                _addUser({
                  'email': emailController.text,
                  'full_name': fullNameController.text,
                  'data_limit': dataLimitBytes,
                  'expiry_date': expiryDateController.text,
                  'is_admin': isAdmin,
                  'subscription_type': subscriptionType,
                  'data_usage': 0, // Initialize data usage for new users
                });
                Navigator.pop(context);
              },
              child: const Text('افزودن'), // New text for add button
            ),
          ],
        );
      },
    );
  }

  // New function to delete a subscription
  Future<void> _deleteSubscription(String id) async {
    try {
      await supabase.from('subscription_links').delete().eq('id', id);
      await _loadData();
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Subscription deleted successfully!',
          backgroundColor: Colors.green,
          icon: Icons.check_circle,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error deleting subscription: ${e.toString()}',
          backgroundColor: Colors.redAccent,
          icon: Icons.error,
        );
      }
    }
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final TextEditingController emailController = TextEditingController(
      text: user['email'],
    );
    final TextEditingController fullNameController = TextEditingController(
      text: user['full_name'],
    );
    final TextEditingController dataLimitController = TextEditingController(
      text: ((user['data_limit'] ?? 0) / (1024 * 1024 * 1024)).toStringAsFixed(
        2,
      ),
    ); // Convert bytes to GB
    final TextEditingController expiryDateController = TextEditingController(
      text: date_utils.formatToJalali(user['expiry_date']),
    );
    bool isAdmin = user['is_admin'] ?? false;
    String subscriptionType = user['subscription_type'] ?? 'free';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ویرایش کاربر'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'ایمیل'),
                ),
                SizedBox(height: 15),
                TextField(
                  controller: fullNameController,
                  decoration: const InputDecoration(labelText: 'نام'),
                ),
                SizedBox(height: 15),
                TextField(
                  controller: dataLimitController,
                  decoration: const InputDecoration(
                    labelText: 'حجم (GB)',
                  ), // Label in GB
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 15),
                TextField(
                  controller: expiryDateController,
                  decoration: const InputDecoration(labelText: 'تاریخ انقضا'),
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.tryParse(user['expiry_date'] ?? '') ??
                          DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      expiryDateController.text = pickedDate.toIso8601String();
                    }
                  },
                ),
                SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: subscriptionType,
                  decoration: const InputDecoration(
                    labelText: 'Subscription Type',
                  ),
                  items: <String>['free', 'premium', 'vip']
                      .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      })
                      .toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      subscriptionType = newValue;
                    }
                  },
                ),
                SizedBox(height: 15),
                Row(
                  children: [
                    const Text('ادمین:'),
                    Checkbox(
                      value: isAdmin,
                      onChanged: (bool? value) {
                        if (value != null) {
                          isAdmin = value;
                          (context as Element)
                              .markNeedsBuild(); // To update checkbox state
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                // backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final int? dataLimitBytes =
                    (double.tryParse(dataLimitController.text) != null
                            ? double.parse(dataLimitController.text) *
                                  (1024 * 1024 * 1024)
                            : null)
                        ?.toInt(); // Convert GB to bytes
                _updateUser(user['id'], {
                  'email': emailController.text,
                  'full_name': fullNameController.text,
                  'data_limit': dataLimitBytes,
                  'expiry_date': expiryDateController.text,
                  'is_admin': isAdmin,
                  'subscription_type': subscriptionType,
                });
                Navigator.pop(context);
              },
              child: const Text('ذخیره'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: Icon(Icons.arrow_back_ios),
        ),
        centerTitle: true,
        surfaceTintColor: CustomColor.primery, // Using CustomColor
        backgroundColor: CustomColor.primery, // Using CustomColor
        title: const Text(
          'پنل مدیریت',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'SM',
          ),
        ),

        bottom: TabBar(
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorAnimation: TabIndicatorAnimation.elastic,
          dividerColor: Colors.transparent,
          indicatorPadding: const EdgeInsets.symmetric(horizontal: 16),
          controller: _tabController,
          onTap: (index) => setState(() => _currentTabIndex = index),
          indicatorColor: Theme.of(context).colorScheme.secondary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          labelStyle: TextStyle(fontFamily: 'SM'),
          tabs: const [
            Tab(text: 'یورز ها'),
            Tab(text: 'کانفیگ ها'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildUsersTab(), _buildSubscriptionsTab()],
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton(
              onPressed: _showAddUserDialog,
              backgroundColor: CustomColor.primery,
              child: const Icon(Icons.person_add, color: Colors.white),
            )
          : null, // Only show on the users tab
    );
  }

  Widget _buildUsersTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  // child: ElevatedButton.icon(
                  //   onPressed: _showAddUserDialog,
                  //   icon: const Icon(Icons.person_add),
                  //   label: const Text('افزودن کاربر جدید'),
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: CustomColor.primery,
                  //     foregroundColor: Colors.white,
                  //     minimumSize: const Size.fromHeight(
                  //       50,
                  //     ), // Make button wider
                  //   ),
                  // ),
                ),
                Expanded(child: _buildUsersList()),
              ],
            ),
          );
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CustomColor.primery,
                  ),
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text(
                    'Refresh',
                    style: TextStyle(color: Colors.white),
                  ),
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
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['full_name'] ?? 'N/A',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.email, color: CustomColor.primery),
                            SizedBox(width: 3),
                            Text(
                              'Email: ${user['email'] ?? 'N/A'}',
                              style: TextStyle(color: CustomColor.primery),
                            ),
                          ],
                        ),

                        Row(
                          children: [
                            Icon(Icons.alarm, color: Colors.pinkAccent),
                            SizedBox(width: 3),
                            Text(
                              'Expiry Date: ${date_utils.formatToJalali(user['expiry_date'])}',
                              style: TextStyle(color: Colors.pinkAccent),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.backup, color: Colors.purpleAccent),
                            SizedBox(width: 3),
                            Text(
                              'Data Usage: ${((user['data_usage'] ?? 0) / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB / ${((user['data_limit'] ?? 0) / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB',
                              style: TextStyle(color: Colors.purpleAccent),
                            ),
                          ],
                        ), // Display in GB
                        Row(
                          children: [
                            Icon(Icons.link, color: CustomColor.tertiary),
                            SizedBox(width: 3),
                            Text(
                              'Subscription Type: ${user['subscription_type'] ?? 'N/A'}',
                              style: TextStyle(color: Colors.amber),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.person, color: CustomColor.secondary),
                            SizedBox(width: 3),
                            Text(
                              'Admin: ${user['is_admin'] == true ? 'Yes' : 'No'}',
                              style: TextStyle(color: CustomColor.secondary),
                            ),
                          ],
                        ),
                        if (isExpired)
                          const Text(
                            'Subscription Expired',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (isDataExhausted)
                          const Text(
                            'Data Exhausted',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _showEditUserDialog(user),
                            child: const Text(
                              'ویرایش',
                              style: TextStyle(fontFamily: 'SM'),
                            ),
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

  Widget _buildSubscriptionsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else {
      return RefreshIndicator(
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
                      decoration: const InputDecoration(
                        labelText: 'New Subscription URL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _addSubscription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('اضافه کردن'),
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
                  : Directionality(
                      textDirection: TextDirection.ltr,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _subscriptions.length,
                        itemBuilder: (context, index) {
                          final sub = _subscriptions[index];
                          final isActive = sub['is_active'] == true;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(sub['url'] ?? 'N/A'),
                              subtitle: Text(
                                'Created: ${date_utils.formatToJalali(sub['created_at'])}',
                                style: TextStyle(color: Colors.green),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  isActive
                                      ? Icon(
                                          Icons.check_circle_sharp,
                                          color: Colors.green,
                                        )
                                      : ElevatedButton(
                                          onPressed: () =>
                                              _activateSubscription(
                                                sub['id'].toString(),
                                              ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text(
                                            'فعال کردن',
                                            style: TextStyle(fontFamily: 'SM'),
                                          ),
                                        ),
                                  const SizedBox(
                                    width: 8,
                                  ), // Spacing between buttons
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteSubscription(
                                      sub['id'].toString(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      );
    }
  }
}
