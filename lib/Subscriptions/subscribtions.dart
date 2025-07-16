// lib/view_subscriptions_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:finity_2/utlis/logo_mapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:finity_2/Subscriptions/add_subscriptions.dart';

class ViewSubscriptionsPage extends StatefulWidget {
  const ViewSubscriptionsPage({Key? key}) : super(key: key);

  @override
  _ViewSubscriptionsPageState createState() => _ViewSubscriptionsPageState();
}

class _ViewSubscriptionsPageState extends State<ViewSubscriptionsPage> {
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _cancelSubscription(Map<String, dynamic> sub) async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Cancel subscription?'),
            content: Text(
              'Are you sure you want to cancel ${sub['merchant']}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes'),
              ),
            ],
          ),
    );
    if (ok != true) return;

    final userDoc = FirebaseFirestore.instance.doc('users/$_uid');
    await userDoc.update({
      'subscriptions': FieldValue.arrayRemove([sub]),
    });
    final updated = Map<String, dynamic>.from(sub)..['status'] = 'canceled';
    await userDoc.update({
      'subscriptions': FieldValue.arrayUnion([updated]),
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Canceled ${sub['merchant']}')));
  }

  Future<void> _resubscribeSubscription(Map<String, dynamic> sub) async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Resubscribe?'),
            content: Text('Reactivate ${sub['merchant']}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes'),
              ),
            ],
          ),
    );
    if (ok != true) return;

    final userDoc = FirebaseFirestore.instance.doc('users/$_uid');
    await userDoc.update({
      'subscriptions': FieldValue.arrayRemove([sub]),
    });
    final updated = Map<String, dynamic>.from(sub)..['status'] = 'active';
    await userDoc.update({
      'subscriptions': FieldValue.arrayUnion([updated]),
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Resubscribed ${sub['merchant']}')));
  }

  Future<void> _removeSubscription(Map<String, dynamic> sub) async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Remove subscription?'),
            content: Text('Permanently remove ${sub['merchant']}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes'),
              ),
            ],
          ),
    );
    if (ok != true) return;

    final userDoc = FirebaseFirestore.instance.doc('users/$_uid');
    await userDoc.update({
      'subscriptions': FieldValue.arrayRemove([sub]),
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Removed ${sub['merchant']}')));
  }

  void _editSubscription(Map<String, dynamic> sub) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddSubscriptionPage(existing: sub)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    final userDoc = FirebaseFirestore.instance.collection('users').doc(_uid);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your Subscriptions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(15),
            ),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
          ),
        ),
      ),
      body: Container(
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
        child: StreamBuilder<DocumentSnapshot>(
          stream: userDoc.snapshots(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data?.data() as Map<String, dynamic>? ?? {};
            final subs =
                (data['subscriptions'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];

            // Empty state
            if (subs.isEmpty) {
              return Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.subscriptions,
                            size: 64,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No subscriptions yet.\nAdd one to get started!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_circle),
                        label: const Text('Add Subscription'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddSubscriptionPage(),
                              ),
                            ),
                      ),
                    ),
                  ),
                ],
              );
            }

            // Non-empty list
            final cards =
                (data['cards'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: subs.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                if (i == subs.length) {
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle_outlined),
                      label: const Text('Add Subscription'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddSubscriptionPage(),
                            ),
                          ),
                    ),
                  );
                }

                final sub = subs[i];
                final merchant = sub['merchant'] as String? ?? '';
                final amount =
                    (sub['amount'] as num?)?.toStringAsFixed(2) ?? '';
                final cycle = sub['cycle'] as String? ?? '';
                final status = sub['status'] as String? ?? 'active';
                final nextDate =
                    (sub['nextBillingDate'] as Timestamp?)?.toDate();
                final cardId = sub['cardId'] as String?;
                final card = cards.firstWhere(
                  (c) => c['cardId'] == cardId,
                  orElse: () => {},
                );
                final last4 = card['last4'] as String? ?? '----';
                final subtitle =
                    status == 'active'
                        ? '•••• $last4  •  Next: ${nextDate != null ? DateFormat.yMMMd().format(nextDate) : '—'}'
                        : '•••• $last4  •  Status: canceled';

                final actions =
                    status == 'active'
                        ? [
                          SlidableAction(
                            onPressed: (_) => _editSubscription(sub),
                            backgroundColor:
                                Theme.of(context).colorScheme.secondary,
                            foregroundColor: Colors.white,
                            icon: Icons.edit,
                            label: 'Edit',
                          ),
                          SlidableAction(
                            onPressed: (_) => _cancelSubscription(sub),
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: Icons.cancel,
                            label: 'Cancel',
                          ),
                        ]
                        : [
                          SlidableAction(
                            onPressed: (_) => _resubscribeSubscription(sub),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            icon: Icons.refresh,
                            label: 'Resubscribe',
                          ),
                          SlidableAction(
                            onPressed: (_) => _removeSubscription(sub),
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            label: 'Remove',
                          ),
                        ];

                return Slidable(
                  key: ValueKey(sub['subId']),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    children: actions,
                  ),
                  child: _buildCard(
                    merchant: merchant,
                    subtitle: subtitle,
                    amount: '\$$amount / $cycle',
                    logoAsset: logoForMerchant(merchant),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard({
    required String merchant,
    required String subtitle,
    required String amount,
    required String logoAsset,
  }) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Image.asset(logoAsset, width: 24, height: 24),
        ),
        title: Text(
          merchant,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.tertiary,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
