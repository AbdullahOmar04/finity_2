import 'dart:convert';
import 'package:finity_2/QR/qr_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrSending extends StatefulWidget {
  const QrSending({Key? key}) : super(key: key);

  @override
  _QrSendingState createState() => _QrSendingState();
}

class _QrSendingState extends State<QrSending> {
  final _formKey = GlobalKey<FormState>();
  final _totalAmountCtl = TextEditingController();
  final _peopleCountCtl = TextEditingController();
  bool _loading = false;
  String? _billId;

  @override
  void dispose() {
    _totalAmountCtl.dispose();
    _peopleCountCtl.dispose();
    super.dispose();
  }

  Future<void> _createBillSplit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final totalAmount = double.parse(_totalAmountCtl.text.trim());
    final peopleCount = int.parse(_peopleCountCtl.text.trim());
    final amountPerPerson = totalAmount / peopleCount;
    final totalCents = (totalAmount * 100).toInt();
    final perPersonCents = (amountPerPerson * 100).toInt();
    final businessUid = FirebaseAuth.instance.currentUser!.uid;

    try {
      // Create bill split document
      final doc = await FirebaseFirestore.instance.collection('bill_splits').add({
        'businessUid': businessUid,
        'totalAmountCents': totalCents,
        'peopleCount': peopleCount,
        'amountPerPersonCents': perPersonCents,
        'paidCount': 0,
        'paidBy': [], // Array of UIDs who have paid
        'status': 'active', // active, completed, expired
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': FieldValue.serverTimestamp(), // TODO: Set expiration time
      });

      setState(() {
        _billId = doc.id;
        _loading = false;
      });

      _showQrOverlay();
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating bill split: $e')),
      );
    }
  }

  void _showQrOverlay() {
    final qrData = jsonEncode({
      'type': 'bill_split',
      'billId': _billId,
      'totalAmount': _totalAmountCtl.text,
      'peopleCount': _peopleCountCtl.text,
    });
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: _QrOverlayContent(
          qrData: qrData,
          totalAmount: _totalAmountCtl.text,
          peopleCount: _peopleCountCtl.text,
          amountPerPerson: (double.parse(_totalAmountCtl.text) / int.parse(_peopleCountCtl.text)).toStringAsFixed(2),
          onDone: () {
            Navigator.pop(context);
            _totalAmountCtl.clear();
            _peopleCountCtl.clear();
            setState(() => _billId = null);
          },
          onViewStatus: () {
            Navigator.pop(context);
            _showBillStatus();
          },
        ),
      ),
    );
  }

  void _showBillStatus() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: _BillStatusDialog(billId: _billId!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Split Bill - POS',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QrScannerPage()),
        ),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan QR'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.point_of_sale,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bill Splitting',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Split customer bills instantly',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Form Card
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaction Details',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Total Amount Field
                          TextFormField(
                            controller: _totalAmountCtl,
                            decoration: InputDecoration(
                              labelText: 'Total Bill Amount (JD)',
                              hintText: 'e.g., 25.00',
                              prefixIcon: Icon(
                                Icons.receipt_long,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter total amount';
                              final n = double.tryParse(v);
                              if (n == null || n <= 0) return 'Must be greater than 0';
                              return null;
                            },
                            onChanged: (v) => setState(() {}), // Trigger rebuild for calculation
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // People Count Field
                          TextFormField(
                            controller: _peopleCountCtl,
                            decoration: InputDecoration(
                              labelText: 'Number of Customers',
                              hintText: 'e.g., 3',
                              prefixIcon: Icon(
                                Icons.group,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter number of customers';
                              final n = int.tryParse(v);
                              if (n == null || n < 2) return 'Must be at least 2 people';
                              return null;
                            },
                            onChanged: (v) => setState(() {}), // Trigger rebuild for calculation
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Split calculation display
                          if (_totalAmountCtl.text.isNotEmpty && _peopleCountCtl.text.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Each customer pays:',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      Text(
                                        '${((double.tryParse(_totalAmountCtl.text) ?? 0) / (int.tryParse(_peopleCountCtl.text) ?? 1)).toStringAsFixed(2)} JD',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Divider(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Business receives:',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                      Text(
                                        '${_totalAmountCtl.text} JD',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          
                          const SizedBox(height: 32),
                          
                          // Generate QR Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _loading ? null : _createBillSplit,
                              icon: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(
                                      Icons.qr_code_2,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                              label: Text(
                                _loading ? 'Creating...' : 'Generate Split QR',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// QR Overlay for bill splitting
class _QrOverlayContent extends StatelessWidget {
  final String qrData;
  final String totalAmount;
  final String peopleCount;
  final String amountPerPerson;
  final VoidCallback onDone;
  final VoidCallback onViewStatus;

  const _QrOverlayContent({
    required this.qrData,
    required this.totalAmount,
    required this.peopleCount,
    required this.amountPerPerson,
    required this.onDone,
    required this.onViewStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.point_of_sale,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bill Split QR Ready',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Bill details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Bill:',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$totalAmount JD',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Split $peopleCount ways:',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$amountPerPerson JD each',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Show this QR code to your customers. Each person scans to pay their share ($amountPerPerson JD)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewStatus,
                  icon: const Icon(Icons.analytics),
                  label: const Text('View Status'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDone,
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bill status tracking dialog
class _BillStatusDialog extends StatelessWidget {
  final String billId;

  const _BillStatusDialog({required this.billId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bill_splits')
          .doc(billId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final paidCount = data['paidCount'] ?? 0;
        final totalPeople = data['peopleCount'] ?? 1;
        final amountPerPerson = (data['amountPerPersonCents'] ?? 0) / 100.0;
        final totalCollected = paidCount * amountPerPerson;

        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Payment Status',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              // Progress indicator
              LinearProgressIndicator(
                value: paidCount / totalPeople,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Status info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Paid:'),
                        Text('$paidCount / $totalPeople customers'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Collected:'),
                        Text('${totalCollected.toStringAsFixed(2)} JD'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Remaining:'),
                        Text('${((totalPeople - paidCount) * amountPerPerson).toStringAsFixed(2)} JD'),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}