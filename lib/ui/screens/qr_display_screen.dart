import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../auth/identity_manager.dart';
import '../../contacts/contact_manager.dart';
import '../theme/app_theme.dart';

class QRDisplayScreen extends StatefulWidget {
  final String? contactUserId; // If null, shows own QR code
  
  const QRDisplayScreen({super.key, this.contactUserId});

  @override
  State<QRDisplayScreen> createState() => _QRDisplayScreenState();
}

class _QRDisplayScreenState extends State<QRDisplayScreen> {
  String? _qrData;
  String? _displayName;
  String? _userId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQRData();
  }

  Future<void> _loadQRData() async {
    try {
      print('🔧 DEBUG: Loading QR data');
      if (widget.contactUserId == null) {
        // Show own QR code
        print('🔧 DEBUG: Showing own QR code');
        final identityManager = context.read<IdentityManager>();
        final identity = identityManager.currentIdentity;

        print('🔧 DEBUG: Current identity: ${identity?.userId}');
        if (identity != null) {
          print('🔧 DEBUG: Generating QR data');
          _qrData = identity.toQRData();
          _displayName = identity.alias;
          _userId = identity.userId;
          print('🔧 DEBUG: QR data generated: $_qrData');
        } else {
          print('🔧 DEBUG: No current identity found');
        }
      } else {
        // Show contact's QR code
        final contactManager = context.read<ContactManager>();
        _qrData = contactManager.generateContactQR(widget.contactUserId!);
        
        final contact = contactManager.getContact(widget.contactUserId!);
        if (contact != null) {
          _displayName = contact.displayName;
          _userId = contact.userId;
        }
      }
    } catch (e) {
      print('🔧 DEBUG: Error loading QR data: $e');
      debugPrint('Error loading QR data: $e');
    } finally {
      print('🔧 DEBUG: Setting loading to false');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _copyToClipboard() async {
    if (_qrData != null) {
      await Clipboard.setData(ClipboardData(text: _qrData!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR code data copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _shareQRCode() async {
    if (_qrData != null && _displayName != null) {
      await Share.share(
        'Connect with me on Oodaa Messenger: $_qrData',
        subject: 'Oodaa Messenger - Connect with $_displayName',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contactUserId == null ? 'My QR Code' : 'Contact QR Code'),
        actions: [
          if (_qrData != null) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copyToClipboard,
              tooltip: 'Copy to clipboard',
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareQRCode,
              tooltip: 'Share',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _qrData == null
              ? _buildError()
              : _buildQRDisplay(isDark),
    );
  }

  Widget _buildError() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            SizedBox(height: 24),
            Text(
              'Unable to generate QR code',
              style: AppTheme.subheadingStyle,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Please try again or check your connection.',
              style: AppTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRDisplay(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Profile section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceColor : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    _displayName?.substring(0, 2).toUpperCase() ?? '??',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Name
                Text(
                  _displayName ?? 'Unknown',
                  style: AppTheme.subheadingStyle.copyWith(
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                // User ID
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor)
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _userId ?? 'unknown',
                    style: AppTheme.captionStyle.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // QR Code
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: _qrData!,
              version: QrVersions.auto,
              size: 250.0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              embeddedImage: null, // TODO: Add app logo
              embeddedImageStyle: const QrEmbeddedImageStyle(
                size: Size(40, 40),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.encryptedColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.encryptedColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.encryptedColor,
                  size: 20,
                ),
                
                const SizedBox(width: 12),
                
                Expanded(
                  child: Text(
                    widget.contactUserId == null
                        ? 'Share this QR code with others to let them add you as a contact'
                        : 'This is the QR code for this contact',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.encryptedColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareQRCode,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Security note
          Text(
            'QR codes contain your public identity only. Your private keys remain secure on your device.',
            style: AppTheme.captionStyle.copyWith(
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
