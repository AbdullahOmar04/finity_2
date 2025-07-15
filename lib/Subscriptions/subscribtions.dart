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
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Cancel subscription?'),
            content: Text('Cancel ${sub['merchant']}?'),
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
    try {
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
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadiusDirectional.vertical(
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
            final cards =
                (data['cards'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];

            return _buildList(
              items: subs,
              itemBuilder: (i, sub) {
                final merchant = sub['merchant'] as String? ?? '';
                final amount = sub['amount']?.toString() ?? '';
                final cycle = sub['cycle'] as String? ?? '';
                final next = (sub['nextBillingDate'] as Timestamp?)?.toDate();
                final status = sub['status'] as String? ?? 'active';
                final cardId = sub['cardId'] as String?;
                final card = cards.firstWhere(
                  (c) => c['cardId'] == cardId,
                  orElse: () => <String, dynamic>{},
                );
                final last4 = card['last4'] as String? ?? '----';

                final title = merchant;
                final trailing = '\$$amount / $cycle';
                final subtitle =
                    status == 'active'
                        ? '•••• $last4 • Next: ${next != null ? DateFormat.yMMMd().format(next) : '—'}'
                        : '•••• $last4 • Status: $status';
                final logo = logoForMerchant(merchant);

                return Slidable(
                  key: ValueKey(sub['merchant'] + i.toString()),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.5,
                    children: [
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
                    ],
                  ),
                  child: _buildCard(
                    title: title,
                    subtitle: subtitle,
                    trailing: trailing,
                    logoAsset: logo,
                  ),
                );
              },
              onAdd:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddSubscriptionPage(),
                    ),
                  ),
              emptyMessage: 'No subscriptions yet.\nAdd one to get started!',
              addIcon: Icons.subscriptions,
              addLabel: 'Add Subscription',
            );
          },
        ),
      ),
    );
  }

  Widget _buildList({
    required List<Map<String, dynamic>> items,
    required Widget Function(int, Map<String, dynamic>) itemBuilder,
    required VoidCallback onAdd,
    required String emptyMessage,
    required IconData addIcon,
    required String addLabel,
  }) {
    return Column(
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
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => itemBuilder(i, items[i]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle),
            label: const Text('Add Subscriptions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required String trailing,
    required String logoAsset,
  }) {
    final theme = Theme.of(context);
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
              theme.colorScheme.onPrimary,
              theme.colorScheme.surface.withOpacity(0.1),
            ],
          ),
        ),
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
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.tertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trailing,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
