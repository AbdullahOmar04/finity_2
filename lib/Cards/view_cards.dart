// lib/view_cards_page.dart

// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'package:finity_2/utlis/logo_mapper.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finity_2/Cards/add_card.dart';

class ViewCardsPage extends StatefulWidget {
  const ViewCardsPage({Key? key}) : super(key: key);

  @override
  _ViewCardsPageState createState() => _ViewCardsPageState();
}

class _ViewCardsPageState extends State<ViewCardsPage> {
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<bool?> _confirmRemoval(String last4) {
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Remove card?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text('Are you sure you want to remove •••• $last4?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
  }

  Future<void> _removeCard(Map<String, dynamic> card) async {
    if (!mounted) return;
    final last4 = card['last4'] as String? ?? '';
    final ok = await _confirmRemoval(last4);
    if (ok != true) return;

    final doc = FirebaseFirestore.instance.doc('users/$_uid');
    try {
      await doc.update({
        'cards': FieldValue.arrayRemove([card]),
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Removed card •••• $last4')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Couldn’t remove card: $e')));
    }
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    String? assetPath,
    required IconData fallbackIcon,
    required VoidCallback onDelete,
  }) {
    final Widget leading =
        assetPath != null
            ? CircleAvatar(
              radius: 20,
              backgroundColor: Colors.transparent,
              backgroundImage: AssetImage(assetPath),
            )
            : Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                fallbackIcon,
                color: Theme.of(context).colorScheme.primary,
              ),
            );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
              Theme.of(context).colorScheme.surface.withOpacity(0.05),
            ],
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: leading,
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ),
          subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: onDelete,
          ),
        ),
      ),
    );
  }

  Widget _buildList({
    required List<Map<String, dynamic>> items,
    required String emptyMessage,
    required IconData addIcon,
    required String addLabel,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surface.withOpacity(0.1),
            Theme.of(context).colorScheme.onPrimary.withOpacity(0.05),
          ],
        ),
      ),
      child: Column(
        children: [
          if (items.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      addIcon,
                      size: 64,
                      color: Theme.of(
                        context,
                      ).colorScheme.tertiary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final card = items[i];
                  final issuer = card['issuer'] as String? ?? '';
                  final last4 = card['last4'] as String? ?? '';
                  final expiry = card['expiry'] as String? ?? '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: _buildCard(
                      title: '$issuer •••• $last4',
                      subtitle: 'Expires $expiry',
                      assetPath: logoForIssuer(issuer),
                      fallbackIcon: Icons.credit_card,
                      onDelete: () => _removeCard(card),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddCardPage()),
                );
              },
              icon: Icon(
                addIcon,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              label: Text(
                addLabel,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your Payment Cards',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadiusDirectional.vertical(
              bottom: Radius.circular(10),
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
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(_uid)
                .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          final cards =
              (data['cards'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>()
                  .toList() ??
              [];
          return _buildList(
            items: cards,
            emptyMessage: 'No cards yet.\nAdd one to get started!',
            addIcon: Icons.add_card,
            addLabel: 'Add Card',
          );
        },
      ),
    );
  }
}
