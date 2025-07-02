// lib/screens/login_page.dart
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:blizzard_vpn/components/custom_snackbar.dart'; // Import CustomSnackbar

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController =
      TextEditingController(); // New controller for full name
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  final _supabase = Supabase.instance.client;
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _checkRememberedUser();
  }

  String formatToJalali(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'نامشخص';

    try {
      final gregorian = DateTime.parse(isoDate);
      final jalali = gregorian.toJalali();
      final monthNames = [
        '',
        'فروردین',
        'اردیبهشت',
        'خرداد',
        'تیر',
        'مرداد',
        'شهریور',
        'مهر',
        'آبان',
        'آذر',
        'دی',
        'بهمن',
        'اسفند',
      ];
      return '${jalali.day} ${monthNames[jalali.month]} ${jalali.year}';
    } catch (e) {
      return isoDate;
    }
  }

  Future<void> _checkRememberedUser() async {
    try {
      final rememberedEmail = await _storage.read(key: 'remembered_email');
      if (rememberedEmail != null) {
        setState(() {
          _emailController.text = rememberedEmail;
          _rememberMe = true;
        });
      }
    } catch (e) {
      debugPrint('خطا در بارگیری کاربر به خاطر سپرده شده: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose(); // Dispose the new controller
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();
      final fullName = _fullNameController.text.trim(); // Get full name

      if (_rememberMe) {
        await _storage.write(key: 'remembered_email', value: email);
      } else {
        await _storage.delete(key: 'remembered_email');
      }

      if (_isSignUp) {
        final response = await _supabase.auth.signUp(
          email: email,
          password: password,
        );

        if (response.user == null) {
          throw AuthException('ثبت نام ناموفق بود. لطفا دوباره امتحان کنید.');
        }

        await _createUserProfile(
          response.user!,
          email,
          fullName,
        ); // Pass full name

        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message:
                'ثبت نام با موفقیت انجام شد! لطفا ایمیل خود را تایید کنید.',
            backgroundColor: Colors.green,
            icon: Icons.check_circle,
            duration: const Duration(seconds: 3),
          );
        }

        setState(() => _isSignUp = false);
      } else {
        final response = await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (response.user == null) {
          throw const AuthException('ایمیل یا رمز عبور نامعتبر است');
        }

        if (response.user?.emailConfirmedAt == null) {
          await _supabase.auth.signOut();
          throw const AuthException('طفا ابتدا ایمیل خود را تایید کنید');
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } on AuthException catch (e) {
      setState(
        () => _errorMessage = _parseAuthError('کاربری با این ایمیل وجود ندارد'),
      );
      CustomSnackbar.show(
        context: context,
        message: 'کاربری با این ایمیل وجود ندارد',
        backgroundColor: Colors.redAccent,
        icon: Icons.error,
      );
    } catch (e) {
      setState(() => _errorMessage = 'یک خطای غیرمنتظره رخ داد');
      debugPrint('خطای احراز هویت: $e');
      CustomSnackbar.show(
        context: context,
        message: _errorMessage,
        backgroundColor: Colors.redAccent,
        icon: Icons.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createUserProfile(
    User user,
    String email,
    String fullName,
  ) async {
    try {
      await _supabase.from('users').upsert({
        'id': user.id,
        'email': email,
        'full_name': fullName.isNotEmpty
            ? fullName
            : email.split('@').first, // Use full name if provided, else derive
        'subscription_type': 'free',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('خطای ایجاد نمایه: $e');
      CustomSnackbar.show(
        context: context,
        message: 'ایجاد پروفایل کاربری ناموفق بود: ${e.toString()}',
        backgroundColor: Colors.redAccent,
        icon: Icons.error,
      );
    }
  }

  String _parseAuthError(String message) {
    if (message.contains('invalid login credentials')) {
      return 'Invalid email or password';
    }
    if (message.contains('email not confirmed')) {
      return 'Please verify your email first';
    }
    if (message.contains('User already registered')) {
      return 'Email already registered. Please login instead.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.background,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 150,
                    width: 150,
                    decoration: BoxDecoration(color: Colors.transparent),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(height: 15),
                  Text(
                    _isSignUp ? 'ایجاد حساب کاربری' : 'خوش آمدید',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSignUp
                        ? 'برای شروع ثبت نام کنید'
                        : 'وارد حساب کاربری خود شوید',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                      fontFamily: 'SM',
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_isSignUp) ...[
                    // TextFormField(
                    //   controller: _fullNameController,
                    //   decoration: InputDecoration(
                    //     labelText: 'Full Name',
                    //     hintText: 'Enter your full name',
                    //     prefixIcon: const Icon(Icons.person_outline),
                    //     border: OutlineInputBorder(
                    //       borderRadius: BorderRadius.circular(12),
                    //       borderSide: BorderSide(
                    //         color: Theme.of(context).colorScheme.primary,
                    //         width: 2,
                    //       ),
                    //     ),
                    //     enabledBorder: OutlineInputBorder(
                    //       borderRadius: BorderRadius.circular(12),
                    //       borderSide: BorderSide(
                    //         color: Colors.grey.shade700,
                    //         width: 1,
                    //       ),
                    //     ),
                    //     focusedBorder: OutlineInputBorder(
                    //       borderRadius: BorderRadius.circular(12),
                    //       borderSide: BorderSide(
                    //         color: Theme.of(context).colorScheme.secondary,
                    //         width: 2,
                    //       ),
                    //     ),
                    //   ),
                    //   validator: (value) {
                    //     if (value == null || value.isEmpty) {
                    //       return 'Please enter your full name';
                    //     }
                    //     return null;
                    //   },
                    //   keyboardType: TextInputType.name,
                    //   textInputAction: TextInputAction.next,
                    // ),
                    // const SizedBox(height: 20),
                  ],
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'ایمیل',
                      hintText: 'ایمیل خود را وارد کنید',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey.shade700,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.secondary,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'لطفا ایمیل خود را وارد کنید';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'لطفا یک ایمیل معتبر وارد کنید';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'رمز عبور',
                      hintText: 'رمز عبور خود را وارد کنید',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey.shade700,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.secondary,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'لطفا رمز عبور خود را وارد کنید';
                      }
                      if (value.length < 6) {
                        return 'رمز عبور باید حداقل 6 کاراکتر داشته باشد';
                      }
                      return null;
                    },
                    textInputAction: _isSignUp
                        ? TextInputAction.done
                        : TextInputAction.go,
                    onFieldSubmitted: (_) => _handleAuth(),
                  ),
                  const SizedBox(height: 10),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!_isSignUp) // Only show "Remember Me" on login
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (bool? value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                              activeColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                            ),
                            Text(
                              'مرا به خاطر بسپار',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                if (_emailController.text.isEmpty) {
                                  CustomSnackbar.show(
                                    context: context,
                                    message:
                                        'لطفا ایمیل خود را برای تنظیم مجدد رمز عبور وارد کنید.',
                                    backgroundColor: Colors.orange,
                                    icon: Icons.info,
                                  );
                                  return;
                                }
                                setState(() => _isLoading = true);
                                try {
                                  await _supabase.auth.resetPasswordForEmail(
                                    _emailController.text.trim().toLowerCase(),
                                    redirectTo:
                                        'io.supabase.flutter://login-callback/',
                                  );
                                  if (mounted) {
                                    CustomSnackbar.show(
                                      context: context,
                                      message:
                                          'لینک بازنشانی رمز عبور به ایمیل شما ارسال شد.',
                                      backgroundColor: Colors.green,
                                      icon: Icons.email,
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    CustomSnackbar.show(
                                      context: context,
                                      message:
                                          'ارسال لینک بازنشانی ناموفق بود: ${e.toString()}',
                                      backgroundColor: Colors.redAccent,
                                      icon: Icons.error,
                                    );
                                  }
                                } finally {
                                  setState(() => _isLoading = false);
                                }
                              },
                        child: const Text('رمز عبور را فراموش کرده اید'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleAuth,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 5,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isSignUp ? 'ثبت نام' : 'ورود',
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _errorMessage = ''; // Clear error message on toggle
                        _fullNameController
                            .clear(); // Clear full name field on toggle
                      });
                    },
                    child: Text(
                      _isSignUp
                          ? 'قبلاً حساب کاربری دارید؟ ورود'
                          : 'حساب کاربری ندارید؟ ثبت نام کنید',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
