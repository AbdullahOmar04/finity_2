// lib/add_card_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddCardPage extends StatefulWidget {
  const AddCardPage({Key? key}) : super(key: key);

  @override
  _AddCardPageState createState() => _AddCardPageState();
}

class _AddCardPageState extends State<AddCardPage> {
  final _formKey = GlobalKey<FormState>();
  final _numberCtl = TextEditingController();
  final _expiryCtl = TextEditingController();
  final _cvvCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  String? _selectedBank;
  bool _loading = false;

  // 1) Define your supported banks here:
  final List<String> _banks = [
    'Arab Bank',
    'Cairo Amman Bank',
    'Orange Money',
    'Etihad Bank',
    'Zain Cash',
    'UWallet',
    'Visa',
    'MasterCard',
    'Other',
  ];

  @override
  void dispose() {
    _numberCtl.dispose();
    _expiryCtl.dispose();
    _cvvCtl.dispose();
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!mounted) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);

    final number = _numberCtl.text.trim().replaceAll(' ', '');
    final expiry = _expiryCtl.text.trim();
    final cvv = _cvvCtl.text.trim();
    final name = _nameCtl.text.trim();
    final last4 =
        number.length >= 4 ? number.substring(number.length - 4) : number;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final card = {
      'cardId': DateTime.now().millisecondsSinceEpoch.toString(),
      'cardholderName': name,
      'last4': last4,
      'expiry': expiry,
      'issuer': _selectedBank ?? 'Unknown',
      'cvv': cvv,
    };

    try {
      await FirebaseFirestore.instance.doc('users/$uid').update({
        'cards': FieldValue.arrayUnion([card]),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add card: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _deco(String label, {Widget? suffix}) => InputDecoration(
    labelText: label,
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.grey.shade100,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Payment Card',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadiusDirectional.vertical(
              bottom: Radius.circular(15),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // 2) Bank dropdown
                DropdownButtonFormField<String>(
                  value: _selectedBank,
                  decoration: _deco('Issuing Bank'),
                  items:
                      _banks
                          .map(
                            (b) => DropdownMenuItem(value: b, child: Text(b)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _selectedBank = v),
                  validator:
                      (v) => v == null || v.isEmpty ? 'Select a bank' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _nameCtl,
                  decoration: _deco('Cardholder Name'),
                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? 'Enter the name on card'
                              : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _numberCtl,
                  decoration: _deco('Card Number'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter card number';
                    final digits = v.replaceAll(' ', '');
                    if (digits.length < 12) return 'Too short';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _expiryCtl,
                        decoration: _deco('Expiry (MM/YY)'),
                        keyboardType: TextInputType.datetime,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter expiry';
                          final parts = v.split('/');
                          if (parts.length != 2) return 'Use MM/YY';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cvvCtl,
                        decoration: _deco('CVV'),
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.length < 3) return 'Invalid CVV';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _loading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _submit(),
                        icon: const Icon(Icons.add_circle),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
