import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../controllers/budget_controller.dart';
import '../models/chat_message.dart';
import '../models/member.dart';
import '../theme/app_theme.dart';
import '../widgets/antigravity_background.dart';
import '../widgets/glassmorphic_card.dart';

class GroupChatScreen extends StatefulWidget {
  final BudgetController controller;
  final String groupId;

  const GroupChatScreen({
    super.key,
    required this.controller,
    required this.groupId,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<Member> _groupMembers;
  
  // Curated list of reaction GIFs for fast, zero-dependency offline rendering
  final List<Map<String, String>> _curatedGifs = [
    {
      'title': 'Make it Rain',
      'url': 'https://media.giphy.com/media/LdOyjZ7SS5oWD1RA8c/giphy.gif'
    },
    {
      'title': 'Shut Up & Take Money',
      'url': 'https://media.giphy.com/media/3o751wpRqtoQTQHmOE/giphy.gif'
    },
    {
      'title': 'Rich Dance',
      'url': 'https://media.giphy.com/media/l0HlHFRbmaZtBRhXG/giphy.gif'
    },
    {
      'title': 'Throwing Bills',
      'url': 'https://media.giphy.com/media/26gsiCIKW7ANMb2jC/giphy.gif'
    },
    {
      'title': 'Empty Wallet',
      'url': 'https://media.giphy.com/media/3o7TKSx0g7sx515Nkw/giphy.gif'
    },
    {
      'title': 'Pay Me!',
      'url': 'https://media.giphy.com/media/xUPGGw7jxnwjkRL7Mg/giphy.gif'
    },
  ];

  // Mock receipt images for simulated uploads
  final List<String> _mockReceipts = [
    'https://images.unsplash.com/photo-1554415707-6e8cfc93fe23?w=500&auto=format&fit=crop&q=60', // Cafe table bill
    'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=500&auto=format&fit=crop&q=60', // Card transaction receipt
    'https://images.unsplash.com/photo-1540910419892-4a36d2c3266c?w=500&auto=format&fit=crop&q=60', // Shopping invoice
  ];

  final List<String> _botPhrases = [
    "Wait, did someone say lunch split? I only ordered a water!",
    "Sent my share via UPI. Settle up now!",
    "Who added that extra cheese split? I'm lactose intolerant 😭",
    "Sending a roast to the next person who delays their payment.",
    "Can someone settle up with me? I'm completely broke.",
    "Budget Splitter is the only app keeping our friendship together right now lol.",
  ];

  @override
  void initState() {
    super.initState();
    _groupMembers = widget.controller.getMembersForGroup(widget.groupId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage({required String content, required String type}) async {
    if (content.trim().isEmpty) return;

    final myName = widget.controller.currentUserName.isEmpty ? "You" : widget.controller.currentUserName;

    // Send user message
    await widget.controller.sendChatMessage(
      groupId: widget.groupId,
      senderId: 'me',
      senderName: myName,
      content: content,
      messageType: type,
    );

    _messageController.clear();
    _scrollToBottom();

    // Trigger mock group response to make chat interactive
    if (_groupMembers.isNotEmpty) {
      Timer(const Duration(seconds: 1), () async {
        if (!mounted) return;
        final botMember = _groupMembers.firstWhere(
          (m) => m.name.toLowerCase() != myName.toLowerCase(),
          orElse: () => _groupMembers.first,
        );

        final randomPhrase = _botPhrases[(DateTime.now().millisecond) % _botPhrases.length];

        await widget.controller.sendChatMessage(
          groupId: widget.groupId,
          senderId: botMember.id,
          senderName: botMember.name,
          content: randomPhrase,
          messageType: 'text',
        );
        _scrollToBottom();
      });
    }
  }

  void _showGifPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select a Reaction GIF",
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _curatedGifs.length,
                  itemBuilder: (context, index) {
                    final gif = _curatedGifs[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _sendMessage(content: gif['url']!, type: 'gif');
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              gif['url']!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                );
                              },
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                child: Text(
                                  gif['title']!,
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _showImageSimulator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Upload Bill/Receipt (Simulated)",
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_mockReceipts.length, (index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _sendMessage(content: _mockReceipts[index], type: 'image');
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryLight, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _mockReceipts[index],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                }),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.controller.getGroupById(widget.groupId);
    final groupName = group?.name ?? "Group Chat";

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary,
              radius: 18,
              backgroundImage: (group?.imageUrl != null && int.tryParse(group!.imageUrl!) == null)
                  ? (kIsWeb
                      ? NetworkImage(group.imageUrl!)
                      : FileImage(File(group.imageUrl!))) as ImageProvider
                  : null,
              child: (group?.imageUrl != null && int.tryParse(group!.imageUrl!) == null)
                  ? null
                  : Text(
                      groupName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(groupName, style: const TextStyle(fontSize: 16)),
                  Text(
                    "${_groupMembers.length} cosmic members",
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AntigravityBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Chat Messages List
              Expanded(
                child: ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) {
                    final chats = widget.controller.getMessagesForGroup(widget.groupId);

                    if (chats.isEmpty) {
                      return Center(
                        child: GlassmorphicCard(
                          borderRadius: 16,
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 40, color: AppTheme.primaryLight),
                              SizedBox(height: 12),
                              Text(
                                "Cosmic Chat Initialized",
                                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Send a text, GIF, or receipt image to start split negotiations!",
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final msg = chats[index];
                        final isMe = msg.senderId == 'me';

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                // Sender name (hide if it's me)
                                if (!isMe)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                                    child: Text(
                                      msg.senderName,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                // Chat message bubble
                                GlassmorphicCard(
                                  borderRadius: 16,
                                  bgOpacityStart: isMe ? 0.16 : 0.06,
                                  borderOpacity: isMe ? 0.25 : 0.1,
                                  gradient: isMe
                                      ? const LinearGradient(
                                          colors: [Color(0x338B5CF6), Color(0x33EC4899)],
                                        )
                                      : null,
                                  padding: msg.messageType == 'text'
                                      ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                                      : const EdgeInsets.all(4),
                                  child: _buildMessageContent(msg),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Chat Input Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppTheme.bgSurface,
                  border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
                ),
                child: Row(
                  children: [
                    // GIF Button
                    IconButton(
                      icon: const Icon(Icons.gif_box, color: AppTheme.primaryLight),
                      onPressed: _showGifPicker,
                    ),
                    // Image Button
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate_outlined, color: AppTheme.secondary),
                      onPressed: _showImageSimulator,
                    ),
                    // Input TextField
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: "Speak your mind...",
                          hintStyle: const TextStyle(color: AppTheme.textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppTheme.bgSurfaceLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onSubmitted: (val) => _sendMessage(content: val, type: 'text'),
                      ),
                    ),
                    // Send Button
                    IconButton(
                      icon: const Icon(Icons.send, color: AppTheme.primary),
                      onPressed: () => _sendMessage(content: _messageController.text, type: 'text'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage msg) {
    if (msg.messageType == 'gif') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          msg.content,
          width: 200,
          height: 150,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              width: 200,
              height: 150,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        ),
      );
    } else if (msg.messageType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          msg.content,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
        ),
      );
    }
    return Text(
      msg.content,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
    );
  }
}
