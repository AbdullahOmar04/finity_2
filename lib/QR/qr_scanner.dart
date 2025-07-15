// lib/qr_scanner.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_functions/cloud_functions.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  _QrScannerPageState createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _scanned = false;

  Future<void> _claimOffer(String offerId) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('claimOffer');
      await callable.call({'offerId': offerId});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully claimed!')),
      );
    } on FirebaseFunctionsException catch (e) {
      final msg = switch (e.code) {
        'not-found' => 'Offer not found',
        'failed-precondition' => e.message!,
        'unauthenticated' => 'Please log in first',
        _ => 'Claim failed: ${e.message}',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan to Claim')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_scanned) return;
          final code = capture.barcodes.first.rawValue;
          if (code == null) return;

          _scanned = true;
          try {
            final payload = jsonDecode(code) as Map<String, dynamic>;
            final offerId = payload['offerId'] as String;
            _claimOffer(offerId).whenComplete(() {
              Future.delayed(const Duration(seconds: 2), () {
                _scanned = false;
              });
            });
          } catch (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid QR')),
            );
            Future.delayed(const Duration(seconds: 2), () {
              _scanned = false;
            });
          }
        },
      ),
    );
  }
}
