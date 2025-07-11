import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth/identity_manager.dart';
import 'storage/storage_manager.dart';
import 'contacts/contact_manager.dart';
import 'chat/message_manager.dart';
import 'webrtc/webrtc_manager.dart';
import 'bluetooth/offline_manager.dart';
import 'security/security_manager.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/setup_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

// TODO: Update with your signaling server URL
const String signalingServerUrl = 'ws://localhost:3001';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Initialize storage
  await StorageManager.initialize();
  
  runApp(const OodaaMessengerApp());
}

class OodaaMessengerApp extends StatelessWidget {
  const OodaaMessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IdentityManager()),
        ChangeNotifierProvider(create: (_) => SecurityManager()),
        ChangeNotifierProvider(create: (_) => WebRTCManager()),
        ChangeNotifierProxyProvider<IdentityManager, ContactManager>(
          create: (context) => ContactManager(context.read<IdentityManager>()),
          update: (context, identityManager, previous) =>
              previous ?? ContactManager(identityManager),
        ),
        ChangeNotifierProxyProvider2<IdentityManager, WebRTCManager, MessageManager>(
          create: (context) => MessageManager(
            context.read<IdentityManager>(),
            context.read<WebRTCManager>(),
          ),
          update: (context, identityManager, webrtcManager, previous) =>
              previous ?? MessageManager(identityManager, webrtcManager),
        ),
        ChangeNotifierProxyProvider2<IdentityManager, MessageManager, OfflineManager>(
          create: (context) => OfflineManager(
            context.read<IdentityManager>(),
            context.read<MessageManager>(),
          ),
          update: (context, identityManager, messageManager, previous) =>
              previous ?? OfflineManager(identityManager, messageManager),
        ),
      ],
      child: MaterialApp(
        title: 'Oodaa Messenger',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AppInitializer(),
        debugShowCheckedModeBanner: false,
        // TODO: Add deep link handling for invite links
        // onGenerateRoute: (settings) {
        //   if (settings.name?.startsWith('/connect') == true) {
        //     // Handle invite links: yourapp://connect?uid=bluefox42&pub=<base64>
        //   }
        // },
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _hasIdentity = false;

  @override
  void initState() {
    super.initState();
    _checkIdentity();
  }

  Future<void> _checkIdentity() async {
    try {
      final identityManager = context.read<IdentityManager>();
      final securityManager = context.read<SecurityManager>();

      // Initialize security manager
      await securityManager.initialize();

      // Check if app is locked
      if (securityManager.isLocked) {
        // TODO: Show unlock screen
        debugPrint('App is locked');
      }

      final hasIdentity = await identityManager.hasExistingIdentity();

      if (hasIdentity) {
        await identityManager.loadIdentity();

        // Initialize WebRTC if identity exists
        final webrtcManager = context.read<WebRTCManager>();
        await webrtcManager.initialize(
          identityManager.currentIdentity!.userId,
          signalingServerUrl,
        );
      }

      setState(() {
        _hasIdentity = hasIdentity;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error during initialization: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SplashScreen();
    }
    
    if (!_hasIdentity) {
      return const SetupScreen();
    }
    
    return const HomeScreen();
  }
}
