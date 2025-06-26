import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  String errorMessage = '';
  bool isSignUp = false;

  final supabase = Supabase.instance.client;

  Future<void> _handleLogin() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw Exception('Please enter both email and password');
      }

      if (isSignUp) {
        // ثبت نام کاربر جدید
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
        );

        if (response.user == null) {
          throw Exception('Sign up failed');
        }
      } else {
        // ورود کاربر موجود
        final response = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (response.user == null) {
          throw Exception('Login failed');
        }
      }

      // پس از ورود موفق، به صفحه اصلی هدایت می‌شویم
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildLoginForm(),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passwordController,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 20),
        if (errorMessage.isNotEmpty)
          Text(errorMessage, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: isLoading ? null : _handleLogin,
          child: isLoading
              ? const CircularProgressIndicator()
              : Text(isSignUp ? 'Sign Up' : 'Login'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            setState(() {
              isSignUp = !isSignUp;
            });
          },
          child: Text(
            isSignUp
                ? 'Already have an account? Login'
                : 'Don\'t have an account? Sign Up',
          ),
        ),
      ],
    );
  }
}
