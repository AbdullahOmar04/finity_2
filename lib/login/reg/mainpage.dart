import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finity_2/analytics.dart';
import 'package:finity_2/login/reg/login.dart';
import 'package:finity_2/QR/qr_sending.dart';
import 'package:finity_2/Subscriptions/subscribtions.dart';
import 'package:finity_2/Cards/view_cards.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selected = 0;
  String? _username;

  final _screens = [
    AnalyticsPage(),
    const QrSending(),
    const ViewSubscriptionsPage(),
  ];

  @override
  void initState() {
    super.initState();
    fetchUsername().then((name) {
      if (mounted) setState(() => _username = name);
    });
  }

  Future<void> _logout() async {
    if (!mounted) return;
    await FirebaseAuth.instance.signOut();
    // send them back to LoginPage
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<String?> fetchUsername() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    final data = doc.data();
    if (data == null) return null;
    return data['username'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Finity',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
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
      drawer: Drawer(
        backgroundColor: Theme.of(context).colorScheme.onPrimary,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
                child: Text(
                  'Welcome, $_username',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.credit_card),
                title: Text('View Cards'),
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ViewCardsPage()),
                    ),
              ),
              Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
      body: _screens[_selected],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: (i) => setState(() => _selected = i),
        destinations: [
          NavigationDestination(icon: Icon(Icons.analytics), label: ''),
          NavigationDestination(icon: Icon(Icons.send), label: ''),
          NavigationDestination(icon: Icon(Icons.subscriptions), label: ''),
        ],
      ),
    );
  }
}
