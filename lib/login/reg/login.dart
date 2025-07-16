// lib/login_page.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'register.dart';
import 'mainpage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _pwdCtl = TextEditingController();
  final _localAuth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtl.dispose();
    _pwdCtl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final email = _emailCtl.text.trim();
      final password = _pwdCtl.text.trim();

      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // store for biometric
      await _storage.write(key: 'email', value: email);
      await _storage.write(key: 'password', value: password);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainPage()),
      );
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'user-not-found'  => 'Email not registered',
        'wrong-password'  => 'Incorrect password',
        'invalid-email'   => 'Invalid email address',
        'too-many-requests' => 'Too many attempts, try later',
        _                 => 'Login failed (${e.code})',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _tryBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric not available')),
        );
        return;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Unlock with fingerprint',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (!didAuthenticate) return;

      // read stored credentials
      final email = await _storage.read(key: 'email');
      final password = await _storage.read(key: 'password');
      if (email == null || password == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No saved credentials—please login manually first'),
          ),
        );
        return;
      }

      setState(() => _loading = true);
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainPage()),
      );
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Biometric failed: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Welcome Back!', style: TextStyle(fontSize: 35)),
              const SizedBox(height: 40),

              // Email
              TextFormField(
                controller: _emailCtl,
                decoration: _fieldDeco('Email', icon: Icons.email),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter your email';
                  final regex =
                      RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,4}$');
                  return regex.hasMatch(v) ? null : 'Enter a valid email';
                },
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _pwdCtl,
                decoration: _fieldDeco(
                  'Password',
                  icon: Icons.lock,
                  suffix: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                  ),
                ),
                obscureText: _obscure,
                validator: (v) =>
                    (v == null || v.length < 6)
                        ? 'Min 6 characters'
                        : null,
              ),
              const SizedBox(height: 24),

              if (_loading)
                const CircularProgressIndicator()
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _login,
                    child: const Text('Login'),
                  ),
                ),
              const SizedBox(height: 16),

              // Fingerprint button
              IconButton(
                icon: const Icon(Icons.fingerprint, size: 32),
                color: Theme.of(context).colorScheme.primary,
                onPressed: _tryBiometric,
                tooltip: 'Login with fingerprint',
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  final email = _emailCtl.text.trim();
                  if (email.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Enter email first')),
                    );
                    return;
                  }
                  FirebaseAuth.instance
                      .sendPasswordResetEmail(email: email);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Reset link sent')),
                  );
                },
                child: const Text('Forgot password?'),
              ),

              const Spacer(),

              // Register link
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black),
                  children: [
                    const TextSpan(text: "Don't have an account? "),
                    TextSpan(
                      text: 'Register',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(String label,
          {IconData? icon, Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.grey.shade200,
        enabledBorder: OutlineInputBorder(
          borderSide:
              BorderSide(color: Colors.grey.shade300),
        ),
      );
}
