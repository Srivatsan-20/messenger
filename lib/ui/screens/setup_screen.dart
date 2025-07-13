import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/identity_manager.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aliasController = TextEditingController();
  bool _isCreating = false;
  bool _showAdvanced = false;

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _createIdentity() async {
    print('🔧 DEBUG: _createIdentity called');

    if (!_formKey.currentState!.validate()) {
      print('🔧 DEBUG: Form validation failed');
      return;
    }

    print('🔧 DEBUG: Setting _isCreating to true');
    setState(() {
      _isCreating = true;
    });

    try {
      print('🔧 DEBUG: Getting IdentityManager');
      final identityManager = context.read<IdentityManager>();

      final alias = _aliasController.text.trim().isEmpty
          ? null
          : _aliasController.text.trim();

      print('🔧 DEBUG: Creating identity with alias: $alias');
      await identityManager.createIdentity(customAlias: alias);

      print('🔧 DEBUG: Identity created successfully, navigating to home');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      print('🔧 DEBUG: Error creating identity: $e');
      print('🔧 DEBUG: Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create identity: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _restoreFromBackup() async {
    // TODO: Implement backup restoration
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Backup restoration coming soon!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                
                // Welcome section
                Column(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      size: 80,
                      color: isDark ? AppTheme.darkPrimaryColor : AppTheme.primaryColor,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Text(
                      'Welcome to Oodaa',
                      style: AppTheme.headingStyle.copyWith(
                        fontSize: 32,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Text(
                      'Create your secure, private identity to start messaging without any servers or data collection.',
                      style: AppTheme.bodyStyle.copyWith(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                
                const SizedBox(height: 48),
                
                // Identity setup form
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Your Display Name (Optional)',
                      style: AppTheme.subheadingStyle.copyWith(
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    TextFormField(
                      controller: _aliasController,
                      decoration: const InputDecoration(
                        hintText: 'e.g., Blue Fox, Crypto Ninja...',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value != null && value.trim().length > 50) {
                          return 'Name must be 50 characters or less';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      'If left empty, a random name will be generated for you.',
                      style: AppTheme.captionStyle,
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Privacy notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (isDark ? AppTheme.darkSurfaceColor : AppTheme.surfaceColor)
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.encryptedColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user,
                        color: AppTheme.encryptedColor,
                        size: 24,
                      ),
                      
                      const SizedBox(width: 12),
                      
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Privacy is Protected',
                              style: AppTheme.bodyStyle.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.encryptedColor,
                              ),
                            ),
                            
                            const SizedBox(height: 4),
                            
                            Text(
                              'No phone number, email, or personal data required. Your identity is stored only on your device.',
                              style: AppTheme.captionStyle.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Create identity button
                ElevatedButton(
                  onPressed: () {
                    print('🔧 DEBUG: Create Identity button pressed!');
                    if (_isCreating) {
                      print('🔧 DEBUG: Already creating, ignoring press');
                      return;
                    }
                    _createIdentity();
                  },
                  child: _isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Create My Identity'),
                ),
                
                const SizedBox(height: 16),
                
                // Advanced options
                TextButton(
                  onPressed: () {
                    print('🔧 DEBUG: Advanced options button pressed');
                    setState(() {
                      _showAdvanced = !_showAdvanced;
                      print('🔧 DEBUG: _showAdvanced is now: $_showAdvanced');
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_showAdvanced ? 'Hide Advanced' : 'Advanced Options'),
                      Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                ),
                
                if (_showAdvanced) ...[
                  const SizedBox(height: 16),
                  
                  OutlinedButton(
                    onPressed: _restoreFromBackup,
                    child: const Text('Restore from Backup'),
                  ),
                ],
                
                const Spacer(),
                
                // Footer
                Text(
                  'By creating an identity, you agree that this app provides end-to-end encryption and stores no data on external servers.',
                  style: AppTheme.captionStyle.copyWith(
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
