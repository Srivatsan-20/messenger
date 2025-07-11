import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/message.dart';
import '../theme/app_theme.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String, {MessageType type}) onSendMessage;
  final Function(MessageType) onSendMedia;
  final bool enabled;
  
  const ChatInput({
    super.key,
    required this.controller,
    required this.onSendMessage,
    required this.onSendMedia,
    this.enabled = true,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  bool _isComposing = false;
  bool _showAttachmentMenu = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final isComposing = widget.controller.text.trim().isNotEmpty;
    if (isComposing != _isComposing) {
      setState(() {
        _isComposing = isComposing;
      });
    }
  }

  void _sendMessage() {
    if (!widget.enabled || !_isComposing) return;
    
    final text = widget.controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      // Controller will be cleared by parent
    }
  }

  void _toggleAttachmentMenu() {
    setState(() {
      _showAttachmentMenu = !_showAttachmentMenu;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Attachment menu
          if (_showAttachmentMenu)
            _buildAttachmentMenu(),
          
          // Input row
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Attachment button
                IconButton(
                  onPressed: widget.enabled ? _toggleAttachmentMenu : null,
                  icon: Icon(
                    _showAttachmentMenu ? Icons.close : Icons.attach_file,
                    color: widget.enabled 
                        ? (isDark ? Colors.white70 : Colors.black54)
                        : Colors.grey,
                  ),
                ),
                
                // Text input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: widget.controller,
                      enabled: widget.enabled,
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: widget.enabled ? 'Type a message...' : 'Chat disabled',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Send button or voice button
                _isComposing
                    ? IconButton(
                        onPressed: widget.enabled ? _sendMessage : null,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.enabled 
                                ? AppTheme.primaryColor 
                                : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      )
                    : IconButton(
                        onPressed: widget.enabled ? _recordVoiceMessage : null,
                        icon: Icon(
                          Icons.mic,
                          color: widget.enabled 
                              ? (isDark ? Colors.white70 : Colors.black54)
                              : Colors.grey,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentMenu() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAttachmentOption(
            icon: Icons.photo_camera,
            label: 'Camera',
            color: Colors.blue,
            onTap: () => _selectMedia(MessageType.image, fromCamera: true),
          ),
          
          _buildAttachmentOption(
            icon: Icons.photo_library,
            label: 'Gallery',
            color: Colors.green,
            onTap: () => _selectMedia(MessageType.image),
          ),
          
          _buildAttachmentOption(
            icon: Icons.videocam,
            label: 'Video',
            color: Colors.red,
            onTap: () => _selectMedia(MessageType.video),
          ),
          
          _buildAttachmentOption(
            icon: Icons.insert_drive_file,
            label: 'File',
            color: Colors.orange,
            onTap: () => _selectMedia(MessageType.file),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            label,
            style: AppTheme.captionStyle.copyWith(
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _selectMedia(MessageType type, {bool fromCamera = false}) {
    setState(() {
      _showAttachmentMenu = false;
    });
    
    // Add haptic feedback
    HapticFeedback.lightImpact();
    
    widget.onSendMedia(type);
  }

  void _recordVoiceMessage() {
    // TODO: Implement voice message recording
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice messages coming soon!'),
      ),
    );
  }
}
