// lib/QR/qr_scanner.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CustomerPaymentScreen extends StatefulWidget {
  final String qrData;

  const CustomerPaymentScreen({Key? key, required this.qrData})
      : super(key: key);

  @override
  _CustomerPaymentScreenState createState() => _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState extends State<CustomerPaymentScreen> {
  Map<String, dynamic>? _billData;
  DocumentSnapshot? _billSnapshot;
  bool _loading = true;
  String? _error;
  bool _processing = false;
  bool _alreadyPaid = false;

  List<Map<String, dynamic>> _cards = [];
  String? _selectedCardId;

  @override
  void initState() {
    super.initState();
    _loadBillData();
  }

  Future<void> _loadBillData() async {
    if (!mounted) return;
    try {
      final qrJson = jsonDecode(widget.qrData);
      if (qrJson['type'] != 'bill_split') {
        setState(() {
          _error = 'Invalid QR code type';
          _loading = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('bill_splits')
          .doc(qrJson['billId'])
          .get();

      if (!doc.exists) {
        setState(() {
          _error = 'Bill not found';
          _loading = false;
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        setState(() {
          _error = 'This bill has expired';
          _loading = false;
        });
        return;
      }

      if (data['status'] == 'completed') {
        setState(() {
          _error = 'This bill is already fully paid';
          _loading = false;
        });
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      bool alreadyPaid = false;
      List<Map<String, dynamic>> cardsList = [];
      String? defaultCardId;

      if (user != null) {
        final paidBy = List<String>.from(data['paidBy'] ?? []);
        alreadyPaid = paidBy.contains(user.uid);

        if (!alreadyPaid) {
          // load user's cards
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final userData = userDoc.data() ?? {};
          final raw = List<dynamic>.from(userData['cards'] ?? []);
          cardsList = raw
              .whereType<Map<String, dynamic>>()
              .toList();
          if (cardsList.isNotEmpty) {
            defaultCardId = cardsList.first['cardId'] as String?;
          }
        }
      }

      setState(() {
        _billData = data;
        _billSnapshot = doc;
        _alreadyPaid = alreadyPaid;
        _cards = cardsList;
        _selectedCardId = defaultCardId;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading bill: $e';
        _loading = false;
      });
    }
  }

  Future<void> _processPayment() async {
    if (!mounted) return;
    if (_billData == null ||
        _billSnapshot == null ||
        _selectedCardId == null) return;
    setState(() => _processing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Please sign in to continue');

      // simulate delay
      await Future.delayed(const Duration(seconds: 2));

      await FirebaseFirestore.instance.runTransaction((tx) async {
        if (!mounted) return;
        final fresh = await tx.get(_billSnapshot!.reference);
        final data = fresh.data() as Map<String, dynamic>;
        final paidBy = List<String>.from(data['paidBy'] ?? []);
        if (paidBy.contains(user.uid)) {
          throw Exception('You have already paid for this bill');
        }

        final newCount = (data['paidCount'] ?? 0) + 1;
        final totalPeople = data['peopleCount'] ?? 1;
        final newStatus = newCount >= totalPeople ? 'completed' : 'active';

        tx.update(_billSnapshot!.reference, {
          'paidCount': newCount,
          'paidBy': [...paidBy, user.uid],
          'status': newStatus,
          'lastPaymentAt': FieldValue.serverTimestamp(),
        });

        tx.set(
          FirebaseFirestore.instance.collection('payments').doc(),
          {
            'billId': _billSnapshot!.id,
            'customerUid': user.uid,
            'customerEmail': user.email,
            'amountCents': data['amountPerPersonCents'],
            'status': 'completed',
            'paymentMethod': 'card',
            'cardId': _selectedCardId,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      });

      _showSuccessDialog();
    } catch (e) {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              'Payment Successful!',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your payment of ${((_billData!['amountPerPersonCents'] ?? 0) / 100.0).toStringAsFixed(2)} JD has been processed.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pop(); // go back to scanning
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return _buildErrorView();
    }
    if (_alreadyPaid) {
      return _buildAlreadyPaidView();
    }
    return _buildPaymentView();
  }

  Widget _buildErrorView() {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Oops!',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlreadyPaidView() {
    return Scaffold(
      appBar: AppBar(title: const Text('Already Paid')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                'Already Paid!',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'You have already paid your share for this bill.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentView() {
    final amountPer = (_billData!['amountPerPersonCents'] ?? 0) / 100.0;
    final total = (_billData!['totalAmountCents'] ?? 0) / 100.0;
    final people = _billData!['peopleCount'] ?? 1;
    final paid = _billData!['paidCount'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Pay Your Share')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bill Summary
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill Summary',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _summaryRow('Total Bill:', '${total.toStringAsFixed(2)} JD'),
                      _summaryRow('Split Between:', '$people people'),
                      _summaryRow('Already Paid:', '$paid/$people'),
                      const Divider(height: 20),
                      _summaryRow(
                        'Your Share:',
                        '${amountPer.toStringAsFixed(2)} JD',
                        isHighlighted: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Card selector
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pay with:',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedCardId,
                        items: _cards.map((c) {
                          final issuer = c['issuer'] as String? ?? '';
                          final last4 = c['last4'] as String? ?? '';
                          return DropdownMenuItem(
                            value: c['cardId'] as String,
                            child: Text('$issuer •••• $last4'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedCardId = val),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        validator: (v) => v == null ? 'Select a card' : null,
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Progress
              LinearProgressIndicator(value: paid / people),
              const SizedBox(height: 8),
              Text('$paid of $people people have paid',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),

              // Pay button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      (_processing || _selectedCardId == null) ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _processing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white)),
                            ),
                            SizedBox(width: 12),
                            Text('Processing...',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        )
                      : Text('Pay ${amountPer.toStringAsFixed(2)} JD',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isHighlighted ? FontWeight.bold : null)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isHighlighted
                      ? Theme.of(context).colorScheme.primary
                      : null)),
        ],
      ),
    );
  }
}

class EnhancedQrScanner extends StatefulWidget {
  const EnhancedQrScanner({Key? key}) : super(key: key);

  @override
  _EnhancedQrScannerState createState() => _EnhancedQrScannerState();
}

class _EnhancedQrScannerState extends State<EnhancedQrScanner> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (_scanned) return;
          final barcode = capture.barcodes.first;
          final String? code = barcode.rawValue;
          if (code != null) {
            _scanned = true;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => CustomerPaymentScreen(qrData: code)),
            );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
