// lib/add_subscription_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddSubscriptionPage extends StatefulWidget {
  /// If non-null, we’re editing an existing subscription.
  final Map<String, dynamic>? existing;

  const AddSubscriptionPage({Key? key, this.existing}) : super(key: key);

  @override
  _AddSubscriptionPageState createState() => _AddSubscriptionPageState();
}

class _AddSubscriptionPageState extends State<AddSubscriptionPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _merchantCtl;
  late TextEditingController _logoCtl;
  late TextEditingController _amountCtl;

  String? _selectedCycle;
  String? _selectedCardId;
  DateTime? _nextDate;
  bool _loading = false;

  final List<String> _cycles = ['Monthly', 'Yearly', 'Weekly', 'Custom'];

  @override
  void initState() {
    super.initState();
    // initialize controllers—prefill if editing
    final e = widget.existing;
    _merchantCtl = TextEditingController(text: e?['merchant'] as String?);
    _logoCtl = TextEditingController(text: e?['logoUrl'] as String?);
    _amountCtl = TextEditingController(
      text: e != null ? (e['amount']?.toString() ?? '') : '',
    );
    _selectedCycle = e != null ? (e['cycle'] as String?)?.capitalize() : null;
    _selectedCardId = e?['cardId'] as String?;
    final ts = e?['nextBillingDate'] as Timestamp?;
    _nextDate = ts?.toDate() ?? DateTime.now();
  }

  @override
  void dispose() {
    _merchantCtl.dispose();
    _logoCtl.dispose();
    _amountCtl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadCards() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    return (data['cards'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        [];
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _nextDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nextDate == null || _selectedCardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick date and card')),
      );
      return;
    }

    setState(() => _loading = true);

    final merchant = _merchantCtl.text.trim();
    final logoUrl = _logoCtl.text.trim().isEmpty ? null : _logoCtl.text.trim();
    final amount = double.parse(_amountCtl.text.trim());
    final cycle = _selectedCycle!.toLowerCase();
    final nextTs = Timestamp.fromDate(_nextDate!);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final subId =
        widget.existing != null
            ? widget.existing!['subId'] as String
            : DateTime.now().millisecondsSinceEpoch.toString();

    final newSub = <String, dynamic>{
      'subId': subId,
      'merchant': merchant,
      if (logoUrl != null) 'logoUrl': logoUrl,
      'amount': amount,
      'cycle': cycle,
      'nextBillingDate': nextTs,
      'status': widget.existing != null ? widget.existing!['status'] : 'active',
      'cardId': _selectedCardId,
    };

    final userDoc = FirebaseFirestore.instance.doc('users/$uid');

    try {
      if (widget.existing == null) {
        // adding new
        await userDoc.update({
          'subscriptions': FieldValue.arrayUnion([newSub]),
        });
      } else {
        // editing: remove old then add updated
        await userDoc.update({
          'subscriptions': FieldValue.arrayRemove([widget.existing]),
        });
        await userDoc.update({
          'subscriptions': FieldValue.arrayUnion([newSub]),
        });
      }
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
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
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Subscription' : 'Add Subscription'),
        centerTitle: true,
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
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadCards(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final cards = snap.data!;
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Merchant
                    TextFormField(
                      controller: _merchantCtl,
                      decoration: _deco('Merchant Name'),
                      validator:
                          (v) =>
                              (v == null || v.isEmpty)
                                  ? 'Enter merchant'
                                  : null,
                    ),
                    const SizedBox(height: 12),

                    // Amount
                    TextFormField(
                      controller: _amountCtl,
                      decoration: _deco('Amount'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter amount';
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) return 'Invalid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Cycle
                    DropdownButtonFormField<String>(
                      value: _selectedCycle,
                      decoration: _deco('Billing Cycle'),
                      items:
                          _cycles
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _selectedCycle = v),
                      validator:
                          (v) => v == null ? 'Select billing cycle' : null,
                    ),
                    const SizedBox(height: 12),

                    // Card picker
                    DropdownButtonFormField<String>(
                      value: _selectedCardId,
                      decoration: _deco('Paying Card'),
                      items:
                          cards
                              .map(
                                (card) => DropdownMenuItem(
                                  value: card['cardId'] as String,
                                  child: Text(
                                    '${card['issuer']} •••• ${card['last4']}',
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _selectedCardId = v),
                      validator:
                          (v) => v == null ? 'Select a payment card' : null,
                    ),
                    const SizedBox(height: 12),

                    // Next date
                    TextFormField(
                      readOnly: true,
                      controller: TextEditingController(
                        text:
                            _nextDate != null
                                ? DateFormat.yMMMd().format(_nextDate!)
                                : '',
                      ),
                      decoration: _deco(
                        'Next Billing Date',
                        suffix: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _pickDate,
                        ),
                      ),
                      validator:
                          (_) => _nextDate == null ? 'Pick a date' : null,
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    _loading
                        ? const CircularProgressIndicator()
                        : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _submit(),
                            icon: const Icon(Icons.add_circle),
                            label:
                                isEditing
                                    ? Text('Save Edits')
                                    : Text('Save Subscriptions'),
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
            );
          },
        ),
      ),
    );
  }
}

/// Helper to capitalize dropdown values back to display form.
extension on String {
  String capitalize() =>
      substring(0, 1).toUpperCase() + substring(1).toLowerCase();
}
