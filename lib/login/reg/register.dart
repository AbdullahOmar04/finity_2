import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finity_2/login/reg/login.dart';
import 'package:finity_2/login/reg/mainpage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}
//Theme.of(context).colorScheme.
class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _pwdCtl = TextEditingController();
  final _confirmCtl = TextEditingController();

  bool _obscurePwd = true, _obscureConfirm = true, _loading = false;

  @override
  void dispose() {
    _usernameCtl.dispose();
    _emailCtl.dispose();
    _pwdCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      // 1️⃣ create user
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtl.text.trim(),
        password: _pwdCtl.text.trim(),
      );

      // 2️⃣ save display name in Auth + Firestore
      final uid = cred.user!.uid;
      final now = DateTime.now();
      await cred.user!.updateDisplayName(_usernameCtl.text.trim());
      await FirebaseFirestore.instance.doc('users/$uid').set({
        'username': _usernameCtl.text.trim(),
        'createdAt': now,
        'balanceCents': 0,
        'offersCreated': 0,
        'offersClaimed': 0,

        // initialize cards & subscriptions
        'cards': <Map<String, dynamic>>[],
        'subscriptions': <Map<String, dynamic>>[],

        // initialize budget arrays
        'incomes': <Map<String, dynamic>>[],
        'fixedExpenses': <Map<String, dynamic>>[],
        'variableExpenses': <Map<String, dynamic>>[],

        // any other settings
        'settings': {'notificationsEnabled': true, 'theme': 'light'},
      });
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainPage()),
        );
      } // back to login
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'email-already-in-use' => 'Email already registered',
        'weak-password' => 'Pick a stronger password',
        'invalid-email' => 'Email address is invalid',
        _ => 'Registration failed (${e.code})',
      };
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Register')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Welcome! Register to get started',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 24),

              // Username
              TextFormField(
                controller: _usernameCtl,
                decoration: _fieldDecoration('Username'),
                validator:
                    (v) => (v == null || v.isEmpty) ? 'Enter a username' : null,
              ),
              const SizedBox(height: 12),

              // Email
              TextFormField(
                controller: _emailCtl,
                decoration: _fieldDecoration('Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter your email';
                  final r = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  return r.hasMatch(v) ? null : 'Enter a valid email';
                },
              ),
              const SizedBox(height: 12),

              // Password
              TextFormField(
                controller: _pwdCtl,
                decoration: _fieldDecoration(
                  'Password',
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePwd ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
                  ),
                ),
                obscureText: _obscurePwd,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a password';
                  if (v.length < 6) return 'At least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Confirm Password
              TextFormField(
                controller: _confirmCtl,
                decoration: _fieldDecoration(
                  'Confirm Password',
                  suffix: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed:
                        () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                obscureText: _obscureConfirm,
                validator:
                    (v) =>
                        (v != _pwdCtl.text) ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 24),

              _loading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 100,
                          vertical: 15,
                        ),
                        backgroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text(
                        'Register',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? "),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: const Text('Login'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  InputDecoration _fieldDecoration(String label, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.grey.shade200,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      );
}
