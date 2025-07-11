import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/identity_manager.dart';
import '../theme/app_theme.dart';
import 'conversations_screen.dart';
import 'contacts_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Widget> _screens = [
    const ConversationsScreen(),
    const ContactsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeApp();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final identityManager = context.read<IdentityManager>();
    
    // Load existing identity if available
    if (!identityManager.hasIdentity) {
      await identityManager.loadIdentity();
    }
    
    // TODO: Initialize WebRTC and other services
    // TODO: Connect to signaling server
    // TODO: Load contacts and conversations
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: AppTheme.defaultAnimationDuration,
      curve: AppTheme.defaultAnimationCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts_outlined),
            activeIcon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Placeholder screens - will be implemented next
class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: AppTheme.subheadingStyle,
            ),
            SizedBox(height: 8),
            Text(
              'Add contacts to start messaging',
              style: AppTheme.captionStyle,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to new chat screen
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              // TODO: Navigate to QR scanner
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: () {
              // TODO: Show my QR code
            },
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contacts_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No contacts yet',
              style: AppTheme.subheadingStyle,
            ),
            SizedBox(height: 8),
            Text(
              'Scan QR codes to add contacts',
              style: AppTheme.captionStyle,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to add contact screen
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<IdentityManager>(
        builder: (context, identityManager, child) {
          final identity = identityManager.currentIdentity;
          
          return ListView(
            children: [
              // Profile section
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          identity?.alias.substring(0, 2).toUpperCase() ?? 'ME',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        identity?.alias ?? 'Unknown',
                        style: AppTheme.subheadingStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        identity?.userId ?? 'No ID',
                        style: AppTheme.captionStyle,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Settings options
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Profile'),
                onTap: () {
                  // TODO: Navigate to edit profile
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text('My QR Code'),
                onTap: () {
                  // TODO: Show QR code
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('Backup Identity'),
                onTap: () {
                  // TODO: Show backup options
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.security),
                title: const Text('Privacy & Security'),
                onTap: () {
                  // TODO: Navigate to privacy settings
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                onTap: () {
                  // TODO: Show about dialog
                },
              ),
              
              const Divider(),
              
              ListTile(
                leading: const Icon(Icons.delete_forever, color: AppTheme.errorColor),
                title: const Text('Delete Identity', style: TextStyle(color: AppTheme.errorColor)),
                onTap: () {
                  // TODO: Show delete confirmation
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
