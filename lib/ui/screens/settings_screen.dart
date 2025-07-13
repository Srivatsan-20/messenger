import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/identity_manager.dart';
import '../../security/security_manager.dart';
import '../../storage/simple_storage.dart';
import 'qr_display_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: Consumer2<SecurityManager, IdentityManager>(
        builder: (context, securityManager, identityManager, child) {
          return ListView(
            children: [
              // Identity Section
              _buildSectionHeader('Identity'),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('My Identity'),
                subtitle: Text(identityManager.currentIdentity?.userId ?? 'Not set'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QRDisplayScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('Backup Identity'),
                subtitle: const Text('Export your identity for backup'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showBackupDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restore Identity'),
                subtitle: const Text('Import identity from backup'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showRestoreDialog(context),
              ),
              
              const Divider(),
              
              // Security Section
              _buildSectionHeader('Security'),
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: const Text('Biometric Authentication'),
                subtitle: const Text('Use fingerprint or face unlock'),
                value: securityManager.biometricEnabled,
                onChanged: (value) {
                  securityManager.setBiometricEnabled(value);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('Auto-lock Timeout'),
                subtitle: Text(_getTimeoutText(securityManager.autoLockTimeout)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showTimeoutDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('Lock App Now'),
                subtitle: const Text('Manually lock the application'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  securityManager.lockApp();
                },
              ),
              
              const Divider(),
              
              // Privacy Section
              _buildSectionHeader('Privacy'),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Delete all messages and contacts'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showClearDataDialog(context),
              ),
              
              const Divider(),
              
              // About Section
              _buildSectionHeader('About'),
              const ListTile(
                leading: Icon(Icons.info),
                title: Text('Version'),
                subtitle: Text('1.0.0'),
              ),
              const ListTile(
                leading: Icon(Icons.security),
                title: Text('Privacy Policy'),
                subtitle: Text('100% private, no data collection'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
  
  String _getTimeoutText(int seconds) {
    if (seconds < 60) {
      return '$seconds seconds';
    } else if (seconds < 3600) {
      return '${seconds ~/ 60} minutes';
    } else {
      return '${seconds ~/ 3600} hours';
    }
  }
  
  void _showTimeoutDialog(BuildContext context) {
    final timeouts = [30, 60, 300, 600, 1800, 3600]; // seconds
    final labels = ['30 seconds', '1 minute', '5 minutes', '10 minutes', '30 minutes', '1 hour'];
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Auto-lock Timeout'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: timeouts.asMap().entries.map((entry) {
              final index = entry.key;
              final timeout = entry.value;
              final label = labels[index];
              
              return RadioListTile<int>(
                title: Text(label),
                value: timeout,
                groupValue: context.read<SecurityManager>().autoLockTimeout,
                onChanged: (value) {
                  if (value != null) {
                    context.read<SecurityManager>().setAutoLockTimeout(value);
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
  
  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Backup Identity'),
          content: const Text(
            'This will create a backup of your identity that can be used to restore your account on another device. Keep this backup secure!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await context.read<IdentityManager>().exportIdentity();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Identity backup created successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create backup: $e')),
                    );
                  }
                }
              },
              child: const Text('Backup'),
            ),
          ],
        );
      },
    );
  }
  
  void _showRestoreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restore Identity'),
          content: const Text(
            'This will replace your current identity with the one from the backup file. This action cannot be undone!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await context.read<IdentityManager>().importIdentity();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Identity restored successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to restore identity: $e')),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
  }
  
  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear All Data'),
          content: const Text(
            'This will permanently delete all your messages, contacts, and settings. This action cannot be undone!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await SimpleStorage.clearAllData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All data cleared successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to clear data: $e')),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
  }
}
