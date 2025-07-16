import 'package:finity_2/login/reg/login.dart';
import 'package:finity_2/login/reg/mainpage.dart';
import 'package:finity_2/utlis/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:local_auth/local_auth.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MaterialApp(
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
      theme: blueTheme,
    ),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  _AuthGateState createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _localAuth = LocalAuthentication();
  bool _didCheckBiometric = false;
  // ignore: unused_field
  bool _biometricPassed = false;

  @override
  void initState() {
    super.initState();
    _tryAuthenticate();
  }

  Future<void> _tryAuthenticate() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // not signed in at all, skip biometrics
      setState(() => _didCheckBiometric = true);
      return;
    }

    try {
      // Check if biometrics are available
      final canCheck = await _localAuth.canCheckBiometrics;
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      if (canCheck && availableBiometrics.isNotEmpty) {
        final didAuth = await _localAuth.authenticate(
          localizedReason: 'Please authenticate to unlock your Finity vault',
          options: const AuthenticationOptions(
            biometricOnly: false, // Allow fallback to PIN/password
            stickyAuth: true,
          ),
        );
        
        if (didAuth) {
          setState(() {
            _biometricPassed = true;
            _didCheckBiometric = true;
          });
          return;
        }
      } else {
        // No biometrics available, proceed without biometric check
        setState(() {
          _biometricPassed = true;
          _didCheckBiometric = true;
        });
        return;
      }
    } catch (e) {
      print('Biometric authentication error: $e');
      // If biometric authentication fails due to platform issues,
      // proceed without biometric authentication
      if (e.toString().contains('no_fragment_activity') || 
          e.toString().contains('PlatformException')) {
        setState(() {
          _biometricPassed = true;
          _didCheckBiometric = true;
        });
        return;
      }
    }

    // biometric failed or unavailable → sign out
    await FirebaseAuth.instance.signOut();
    setState(() => _didCheckBiometric = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_didCheckBiometric) {
      // still waiting on fingerprint
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const LoginPage();
    }

    // if we got here, user!=null and biometrics (if any) passed
    return const MainPage();
  }
}