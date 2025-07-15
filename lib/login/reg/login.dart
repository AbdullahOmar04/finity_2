import 'package:finity_2/login/reg/mainpage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'register.dart';        // your RegisterPage

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _pwdCtl = TextEditingController();
  bool _obscure = true, _loading = false;

  @override
  void dispose() {
    _emailCtl.dispose();
    _pwdCtl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtl.text.trim(),
        password: _pwdCtl.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'user-not-found' => 'Email not registered',
        'wrong-password' => 'Incorrect password',
        'invalid-email' => 'Invalid email address',
        'too-many-requests' => 'Try again later',
        _ => 'Login failed (${e.code})',
      };
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Login')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Welcome Back!', style: TextStyle(fontSize: 35)),
              const SizedBox(height: 50),

              // Email
              TextFormField(
                controller: _emailCtl,
                decoration: _fieldDeco('Email', icon: Icons.email),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter your email';
                  final r = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,4}$');
                  return r.hasMatch(v) ? null : 'Enter a valid email';
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
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                obscureText: _obscure,
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 24),

              _loading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 100, vertical: 15),
                          backgroundColor: Colors.grey.shade700,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                        ),
                        child: const Text('Login', style: TextStyle(color: Colors.white)),
                      ),
                    ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  if (_emailCtl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter email first')));
                    return;
                  }
                  FirebaseAuth.instance
                      .sendPasswordResetEmail(email: _emailCtl.text.trim());
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reset link sent')));
                },
                child: const Text('Forgot password?'),
              ),

              const Spacer(),

              // Register link
              RichText(
                text: TextSpan(style: const TextStyle(color: Colors.black), children: [
                  const TextSpan(text: "Don't have an account? "),
                  TextSpan(
                    text: 'Register',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterPage()),
                          ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      );

  InputDecoration _fieldDeco(String label,
          {IconData? icon, Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.grey.shade200,
        enabledBorder:
            OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
      );
}
