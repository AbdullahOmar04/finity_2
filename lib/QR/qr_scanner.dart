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

  @override
  void initState() {
    super.initState();
    _loadBillData();
  }

  Future<void> _loadBillData() async {
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
      final expiresAt = data['expiresAt'] as Timestamp?;
      if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
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
      if (user != null) {
        final paidBy = List<String>.from(data['paidBy'] ?? []);
        if (paidBy.contains(user.uid)) {
          setState(() => _alreadyPaid = true);
        }
      }

      setState(() {
        _billData = data;
        _billSnapshot = doc;
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
    if (_billData == null || _billSnapshot == null) return;
    setState(() => _processing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Please sign in to continue');

      // simulate delay
      await Future.delayed(const Duration(seconds: 2));

      await FirebaseFirestore.instance.runTransaction((tx) async {
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
              Navigator.of(context).pop();
              Navigator.of(context).pop();
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
                      _summaryRow('Your Share:', '${amountPer.toStringAsFixed(2)} JD',
                          isHighlighted: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Method',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _methodTile(
                        icon: Icons.credit_card,
                        title: 'Credit/Debit Card',
                        subtitle: 'Visa, Mastercard, etc.',
                        isSelected: true,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              LinearProgressIndicator(value: paid / people),
              const SizedBox(height: 8),
              Text('$paid of $people people have paid',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _processing ? null : _processPayment,
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
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
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

  Widget _methodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
        color:
            isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
      ),
      child: Row(
        children: [
          Icon(icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (isSelected)
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
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
