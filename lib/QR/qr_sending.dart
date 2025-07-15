// lib/QR/qr_sending.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'qr_scanner.dart'; // <-- fixed import

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

    final totalAmount     = double.parse(_totalAmountCtl.text.trim());
    final peopleCount     = int.parse(_peopleCountCtl.text.trim());
    final amountPerPerson = totalAmount / peopleCount;
    final totalCents      = (totalAmount * 100).toInt();
    final perPersonCents  = (amountPerPerson * 100).toInt();
    final businessUid     = FirebaseAuth.instance.currentUser!.uid;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('bill_splits')
          .add({
        'businessUid': businessUid,
        'totalAmountCents': totalCents,
        'peopleCount': peopleCount,
        'amountPerPersonCents': perPersonCents,
        'paidCount': 0,
        'paidBy': <String>[],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24)),
        ),
        'lastPaymentAt': null,
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
          amountPerPerson: (double.parse(_totalAmountCtl.text) /
                  int.parse(_peopleCountCtl.text))
              .toStringAsFixed(2),
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
  if (_billId == null) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 280,
          maxWidth: 360,
        ),
        child: _EnhancedBillStatusDialog(billId: _billId!),
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Split Bill – POS',
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EnhancedQrScanner()),
        ),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan QR'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.secondary.withOpacity(0.1),
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
                    Icon(Icons.point_of_sale, size: 32, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bill Splitting',
                              style: theme.textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Split customer bills instantly',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Form Card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Transaction Details',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),

                          // Total Amount
                          TextFormField(
                            controller: _totalAmountCtl,
                            decoration: InputDecoration(
                              labelText: 'Total Bill Amount (JD)',
                              hintText: 'e.g., 25.00',
                              prefixIcon: Icon(Icons.receipt_long,
                                  color: theme.colorScheme.primary),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter total bill';
                              final n = double.tryParse(v);
                              if (n == null || n <= 0) return 'Must be > 0';
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),

                          // Number of People
                          TextFormField(
                            controller: _peopleCountCtl,
                            decoration: InputDecoration(
                              labelText: 'Number of People',
                              hintText: 'e.g., 3',
                              prefixIcon: Icon(Icons.group,
                                  color: theme.colorScheme.primary),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter number of people';
                              final n = int.tryParse(v);
                              if (n == null || n < 2) return 'At least 2 people';
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 24),

                          // Live Split Preview
                          if (_totalAmountCtl.text.isNotEmpty &&
                              _peopleCountCtl.text.isNotEmpty &&
                              double.tryParse(_totalAmountCtl.text) != null &&
                              int.tryParse(_peopleCountCtl.text) != null)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Each customer pays:',
                                          style: theme.textTheme.titleMedium),
                                      Text(
                                          '${(double.parse(_totalAmountCtl.text) / int.parse(_peopleCountCtl.text)).toStringAsFixed(2)} JD',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.primary,
                                                  fontSize: 18)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Divider(color: theme.colorScheme.outline.withOpacity(0.3)),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Business receives:',
                                          style: theme.textTheme.bodyMedium),
                                      Text('${_totalAmountCtl.text} JD',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(fontWeight: FontWeight.bold)),
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
                                      child:
                                          CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(Icons.qr_code_2,
                                      color: theme.colorScheme.onPrimary),
                              label: Text(
                                _loading ? 'Creating...' : 'Generate Split QR',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bill Split QR Ready',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceVariant,
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
                color: theme.colorScheme.outline.withOpacity(0.3),
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
              color: theme.colorScheme.primary,
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
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$totalAmount JD',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
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
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$amountPerPerson JD each',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
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
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Show this QR code to your customers. Each person scans to pay their share ($amountPerPerson JD)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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

/// Enhanced Bill status tracking dialog with real-time updates - COMPLETELY REDESIGNED
class _EnhancedBillStatusDialog extends StatefulWidget {
  final String billId;
  const _EnhancedBillStatusDialog({required this.billId});
  @override
  _EnhancedBillStatusDialogState createState() => _EnhancedBillStatusDialogState();
}

class _EnhancedBillStatusDialogState extends State<_EnhancedBillStatusDialog> {
  late final Stream<DocumentSnapshot> _billStream;
  int _prevPaid = 0;

  @override
  void initState() {
    super.initState();
    _billStream = FirebaseFirestore.instance
        .collection('bill_splits')
        .doc(widget.billId)
        .snapshots();
  }

  void _playHaptic() => HapticFeedback.lightImpact();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<DocumentSnapshot>(
      stream: _billStream,
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(cs.primary)),
                const SizedBox(height: 16),
                Text('Loading payment status…', style: Theme.of(context).textTheme.bodyMedium),
              ]),
            ),
          );
        }

        final data = snap.data!.data()! as Map<String, dynamic>;
        final paid = data['paidCount']   as int?    ?? 0;
        final people = data['peopleCount'] as int?   ?? 1;
        final perCents = data['amountPerPersonCents'] as int? ?? 0;
        final totalCents = data['totalAmountCents'] as int? ?? 0;
        final collected = paid * (perCents / 100);
        final total = totalCents / 100;
        final remaining = total - collected;
        final done = data['status'] == 'completed';
        final lastTs = data['lastPaymentAt'] as Timestamp?;
        final lastDate = lastTs?.toDate();

        // play haptic on new payment
        if (paid > _prevPaid) {
          _playHaptic();
          _prevPaid = paid;
        }

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: done ? cs.primaryContainer : cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(done ? Icons.check_circle : Icons.payment,
                      color: done ? cs.primary : cs.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    done ? 'Payment Complete!' : 'Payment Status',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // progress bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progress', style: Theme.of(context).textTheme.titleMedium),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$paid / $people paid',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: people > 0 ? paid / people : 0,
                minHeight: 6,
                backgroundColor: cs.outline.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation(done ? cs.primary : cs.primary),
              ),
            ),

            const SizedBox(height: 20),

            // details card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.secondaryContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                _detailRow('Total Bill:', '${total.toStringAsFixed(2)} JD', cs.onSurface),
                const SizedBox(height: 8),
                _detailRow('Per Person:', '${(perCents/100).toStringAsFixed(2)} JD', cs.onSurface),
                const SizedBox(height: 8),
                _detailRow('Collected:', '${collected.toStringAsFixed(2)} JD', cs.primary),
                const SizedBox(height: 8),
                _detailRow('Remaining:', '${remaining.toStringAsFixed(2)} JD', cs.error),
              ]),
            ),

            if (lastDate != null) ...[
              const SizedBox(height: 12),
              Text('Last payment: ${_formatTime(lastDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],

            if (done) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.primary.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.celebration, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All $total JD collected! 🎉',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                    ),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 20),

            // actions
            Row(children: [
              if (!done) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(done ? Icons.check : Icons.close),
                  label: Text(done ? 'Done' : 'Close'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: done ? cs.primary : cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
          ]),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, Color valueColor) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
    ]);
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2,'0')}';
  }
}
