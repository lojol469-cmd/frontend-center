import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';
import '../api_service.dart';

class GroupChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _onlineUsers = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isRecording = false;
  bool _isTyping = false;
  final List<File> _selectedFiles = [];
  String? _replyToId;
  Map<String, dynamic>? _replyToMessage;
  String? _editingMessageId;
  Timer? _typingTimer;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  
  // Animation controllers
  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadMessages();
    _loadOnlineUsers();
    _listenToWebSocket();
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _setupAutoRefresh() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _loadOnlineUsers();
      } else {
        timer.cancel();
      }
    });
  }

  void _listenToWebSocket() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    appProvider.webSocketStream.listen((message) {
      if (message['groupId'] == widget.groupId) {
        switch (message['type']) {
          case 'new_message':
            setState(() {
              _messages.add(message['message']);
            });
            _scrollToBottom();
            break;
          case 'edit_message':
            _updateMessage(message['message']);
            break;
          case 'delete_message':
            _removeMessage(message['messageId']);
            break;
          case 'user_typing':
            _handleUserTyping(message['userId'], message['userName']);
            break;
          case 'user_online':
            _handleUserOnline(message['user']);
            break;
          case 'user_offline':
            _handleUserOffline(message['userId']);
            break;
        }
      }
    });
  }

  void _handleUserTyping(String userId, String userName) {
    // Afficher indicateur de frappe
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$userName est en train d\'écrire...'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF00D4FF),
      ),
    );
  }

  void _handleUserOnline(Map<String, dynamic> user) {
    setState(() {
      if (!_onlineUsers.any((u) => u['_id'] == user['_id'])) {
        _onlineUsers.add(user);
      }
    });
  }

  void _handleUserOffline(String userId) {
    setState(() {
      _onlineUsers.removeWhere((u) => u['_id'] == userId);
    });
  }

  void _updateMessage(Map<String, dynamic> updatedMessage) {
    setState(() {
      final index = _messages.indexWhere((m) => m['_id'] == updatedMessage['_id']);
      if (index != -1) {
        _messages[index] = updatedMessage;
      }
    });
  }

  void _removeMessage(String messageId) {
    setState(() {
      _messages.removeWhere((m) => m['_id'] == messageId);
    });
  }

  Future<void> _loadMessages() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) return;

    try {
      final result = await ApiService().getGroupMessages(token, widget.groupId);
      setState(() {
        _messages = List<Map<String, dynamic>>.from(result['messages'] ?? []);
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Erreur chargement messages: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement des messages: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadOnlineUsers() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) return;

    try {
      final result = await ApiService().getGroupOnlineUsers(token, widget.groupId);
      setState(() {
        _onlineUsers = List<Map<String, dynamic>>.from(result['users'] ?? []);
      });
    } catch (e) {
      debugPrint('Erreur chargement utilisateurs en ligne: $e');
      // Ignorer l'erreur silencieusement pour ne pas perturber l'UX
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _notifyTyping() {
    if (!_isTyping) {
      setState(() => _isTyping = true);
      // Note: Envoi via WebSocket à implémenter dans le serveur
    }

    // Reset timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      setState(() => _isTyping = false);
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedFiles.add(File(image.path));
      });
    }
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedFiles.add(File(image.path));
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );

    if (video != null) {
      setState(() {
        _selectedFiles.add(File(video.path));
      });
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFiles.add(File(result.files.first.path!));
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      // Pour l'instant, on affiche juste un message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enregistrement audio temporairement désactivé'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      // Timer pour durée d'enregistrement
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });
      });
    } catch (e) {
      debugPrint('Erreur démarrage enregistrement: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      
      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enregistrement arrêté (fonctionnalité en cours de développement)'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur arrêt enregistrement: $e');
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordingDuration = 0;
    });
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    
    if (content.isEmpty && _selectedFiles.isEmpty) return;

    // Si on est en mode édition
    if (_editingMessageId != null) {
      await _saveEditedMessage();
      return;
    }

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) return;

    setState(() => _isSending = true);

    try {
      if (_selectedFiles.isNotEmpty) {
        // Envoi avec médias
        await ApiService().sendGroupMessageWithMedia(
          token,
          widget.groupId,
          content: content.isNotEmpty ? content : null,
          mediaFiles: _selectedFiles,
          replyTo: _replyToId,
        );
      } else {
        // Envoi texte seulement
        await ApiService().sendGroupMessage(
          token,
          widget.groupId,
          content,
          replyTo: _replyToId,
        );
      }

      setState(() {
        _messageController.clear();
        _selectedFiles.clear();
        _replyToId = null;
        _replyToMessage = null;
        _isTyping = false;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('Erreur envoi message: $e');
      _showError('Erreur d\'envoi: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _saveEditedMessage() async {
    final content = _messageController.text.trim();
    
    if (content.isEmpty || _editingMessageId == null) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) return;

    setState(() => _isSending = true);

    try {
      await ApiService().updateGroupMessage(
        token,
        widget.groupId,
        _editingMessageId!,
        content,
      );

      setState(() {
        final index = _messages.indexWhere((m) => m['_id'] == _editingMessageId);
        if (index != -1) {
          _messages[index]['content'] = content;
          _messages[index]['isEdited'] = true;
        }
        _messageController.clear();
        _editingMessageId = null;
      });
    } catch (e) {
      debugPrint('Erreur modification message: $e');
      _showError('Erreur de modification: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _replyTo(Map<String, dynamic> message) {
    setState(() {
      _replyToId = message['_id'];
      _replyToMessage = message;
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToMessage = null;
    });
  }

  void _editMessage(Map<String, dynamic> message) {
    setState(() {
      _editingMessageId = message['_id'];
      _messageController.text = message['content'] ?? '';
      _replyToId = null;
      _replyToMessage = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _messageController.clear();
    });
  }

  Future<void> _deleteMessage(String messageId) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Supprimer', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Supprimer ce message pour tout le monde ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService().deleteGroupMessage(token, widget.groupId, messageId);
      setState(() {
        _messages.removeWhere((m) => m['_id'] == messageId);
      });
    } catch (e) {
      debugPrint('Erreur suppression message: $e');
      _showError('Erreur de suppression');
    }
  }

  Future<void> _reactToMessage(String messageId, String emoji) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) return;

    try {
      await ApiService().reactToGroupMessage(token, widget.groupId, messageId, emoji);
      // Mise à jour locale
      setState(() {
        final index = _messages.indexWhere((m) => m['_id'] == messageId);
        if (index != -1) {
          final reactions = _messages[index]['reactions'] as List<dynamic>? ?? [];
          final userId = appProvider.currentUser?['_id'] ?? appProvider.currentUser?['id'];
          reactions.add({'emoji': emoji, 'userId': userId});
          _messages[index]['reactions'] = reactions;
        }
      });
    } catch (e) {
      debugPrint('Erreur réaction message: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barre de drag
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Nom du groupe
              Text(
                widget.groupName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_onlineUsers.length} membres en ligne',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 20),

              // Membres du groupe
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _onlineUsers.length,
                  itemBuilder: (context, index) {
                    final user = _onlineUsers[index];
                    return _buildMemberTile(user);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> user) {
    final profileImage = user['profileImage'] ?? '';
    final name = user['name'] ?? 'Utilisateur';
    final status = user['status'] ?? 'offline';

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: profileImage.isNotEmpty
                ? NetworkImage(profileImage)
                : null,
            backgroundColor: const Color(0xFF00D4FF),
            child: profileImage.isEmpty
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          if (status == 'online')
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        name,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      subtitle: Text(
        status == 'online' ? 'En ligne' : 'Hors ligne',
        style: TextStyle(
          color: status == 'online' ? Colors.green : Colors.white54,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: _showGroupInfo,
          child: Row(
            children: [
              // Avatar du groupe
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.group, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.groupName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Bulles utilisateurs en ligne
                    SizedBox(
                      height: 20,
                      child: _buildOnlineUsersBubbles(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Appel vidéo
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () {
              _showError('Fonctionnalité en cours de développement');
            },
          ),
          // Plus d'options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'info':
                  _showGroupInfo();
                  break;
                case 'search':
                  _showError('Fonctionnalité en cours de développement');
                  break;
                case 'mute':
                  _showError('Fonctionnalité en cours de développement');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF00D4FF)),
                    SizedBox(width: 12),
                    Text('Info du groupe'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search, color: Color(0xFF00D4FF)),
                    SizedBox(width: 12),
                    Text('Rechercher'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'mute',
                child: Row(
                  children: [
                    Icon(Icons.notifications_off, color: Color(0xFF00D4FF)),
                    SizedBox(width: 12),
                    Text('Couper le son'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Liste des messages
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
                  )
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final previousMessage = index > 0 ? _messages[index - 1] : null;
                          final showDateHeader = _shouldShowDateHeader(message, previousMessage);
                          
                          return Column(
                            children: [
                              if (showDateHeader) _buildDateHeader(message['createdAt']),
                              _buildMessageBubble(message),
                            ],
                          );
                        },
                      ),
          ),

          // Barre d'input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildOnlineUsersBubbles() {
    if (_onlineUsers.isEmpty) {
      return const Text(
        'Aucun membre en ligne',
        style: TextStyle(color: Colors.white54, fontSize: 11),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _onlineUsers.length > 10 ? 10 : _onlineUsers.length,
      itemBuilder: (context, index) {
        if (index == 9 && _onlineUsers.length > 10) {
          return Padding(
            padding: const EdgeInsets.only(left: 4),
            child: CircleAvatar(
              radius: 10,
              backgroundColor: Colors.white24,
              child: Text(
                '+${_onlineUsers.length - 9}',
                style: const TextStyle(color: Colors.white, fontSize: 8),
              ),
            ),
          );
        }

        final user = _onlineUsers[index];
        final profileImage = user['profileImage'] ?? '';
        
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: CircleAvatar(
            radius: 10,
            backgroundImage: profileImage.isNotEmpty
                ? NetworkImage(profileImage)
                : null,
            backgroundColor: const Color(0xFF00D4FF),
            child: profileImage.isEmpty
                ? const Icon(Icons.person, size: 12, color: Colors.white)
                : null,
          ),
        );
      },
    );
  }

  bool _shouldShowDateHeader(Map<String, dynamic> message, Map<String, dynamic>? previousMessage) {
    if (previousMessage == null) return true;
    
    try {
      final messageDate = DateTime.parse(message['createdAt']);
      final prevDate = DateTime.parse(previousMessage['createdAt']);
      
      return messageDate.day != prevDate.day ||
             messageDate.month != prevDate.month ||
             messageDate.year != prevDate.year;
    } catch (e) {
      return false;
    }
  }

  Widget _buildDateHeader(dynamic timestamp) {
    final date = DateTime.parse(timestamp.toString());
    final now = DateTime.now();
    String dateText;

    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      dateText = 'Aujourd\'hui';
    } else if (date.day == now.day - 1 && date.month == now.month && date.year == now.year) {
      dateText = 'Hier';
    } else {
      dateText = '${date.day}/${date.month}/${date.year}';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          dateText,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun message',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Soyez le premier à écrire !',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final currentUserId = appProvider.currentUser?['_id'] ?? appProvider.currentUser?['id'];
    final messageUser = message['userId'] as Map<String, dynamic>?;
    final isOwnMessage = messageUser?['_id'] == currentUserId;
    
    final profileImage = messageUser?['profileImage'] ?? '';
    final userName = messageUser?['name'] ?? 'Utilisateur';
    final content = message['content'] ?? '';
    final media = message['media'] as List<dynamic>? ?? [];
    final reactions = message['reactions'] as List<dynamic>? ?? [];
    final isEdited = message['isEdited'] == true;
    final replyTo = message['replyTo'] as Map<String, dynamic>?;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Align(
        alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: isOwnMessage
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // Photo + Nom (seulement pour les autres)
              if (!isOwnMessage)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: profileImage.isNotEmpty
                            ? NetworkImage(profileImage)
                            : null,
                        backgroundColor: const Color(0xFF00D4FF),
                        child: profileImage.isEmpty
                            ? const Icon(Icons.person, size: 16, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

              // Bulle de message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: isOwnMessage
                      ? const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
                        )
                      : null,
                  color: isOwnMessage ? null : const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message de réponse
                    if (replyTo != null) _buildReplyPreview(replyTo, isOwnMessage),

                    // Texte
                    if (content.isNotEmpty)
                      Text(
                        content,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),

                    // Médias
                    if (media.isNotEmpty) ...[
                      if (content.isNotEmpty) const SizedBox(height: 8),
                      ...media.map((m) => _buildMediaWidget(m)),
                    ],

                    // Timestamp + Édité + Statut
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message['createdAt']),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10,
                          ),
                        ),
                        if (isEdited) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(modifié)',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (isOwnMessage) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message['seen'] == true
                                ? Icons.done_all
                                : Icons.done,
                            size: 14,
                            color: message['seen'] == true
                                ? const Color(0xFF4CAF50)
                                : Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Réactions
              if (reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 4,
                    children: _buildReactionChips(reactions),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview(Map<String, dynamic> replyTo, bool isOwnMessage) {
    final replyContent = replyTo['content'] ?? '';
    final replyUser = replyTo['userId'] as Map<String, dynamic>?;
    final replyUserName = replyUser?['name'] ?? 'Utilisateur';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isOwnMessage ? Colors.white : const Color(0xFF00D4FF),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyUserName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyContent.length > 50
                ? '${replyContent.substring(0, 50)}...'
                : replyContent,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildReactionChips(List<dynamic> reactions) {
    final Map<String, int> reactionCounts = {};
    
    for (var reaction in reactions) {
      final emoji = reaction['emoji'];
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }

    return reactionCounts.entries.map((entry) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(entry.key, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              '${entry.value}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildMediaWidget(Map<String, dynamic> media) {
    final type = media['type'];
    final url = media['url'];

    if (type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
        ),
      );
    } else if (type == 'video') {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
        ),
      );
    } else if (type == 'audio') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.audiotrack, size: 20, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message vocal',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: 0,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (type == 'document') {
      final filename = media['filename'] ?? 'Document';
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file, size: 32, color: Color(0xFF00D4FF)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                filename,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final currentUserId = appProvider.currentUser?['_id'] ?? appProvider.currentUser?['id'];
    final messageUser = message['userId'] as Map<String, dynamic>?;
    final isOwnMessage = messageUser?['_id'] == currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Réactions rapides
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _reactToMessage(message['_id'], emoji);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const Divider(color: Colors.white24),

            // Répondre
            ListTile(
              leading: const Icon(Icons.reply, color: Color(0xFF00D4FF)),
              title: const Text('Répondre', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _replyTo(message);
              },
            ),

            // Copier
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white70),
              title: const Text('Copier', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            // Transférer
            ListTile(
              leading: const Icon(Icons.forward, color: Colors.white70),
              title: const Text('Transférer', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            // Modifier (seulement si c'est son propre message)
            if (isOwnMessage)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.orange),
                title: const Text('Modifier', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),

            // Supprimer (seulement si c'est son propre message)
            if (isOwnMessage)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Supprimer', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message['_id']);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              offset: const Offset(0, -1),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode Édition
            if (_editingMessageId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.orange.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    const Icon(Icons.edit, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Modification du message',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.white),
                      onPressed: _cancelEdit,
                    ),
                  ],
                ),
              ),

            // Répondre à...
            if (_replyToMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF00D4FF).withValues(alpha: 0.2),
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 16, color: Color(0xFF00D4FF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Répondre à ${(_replyToMessage!['userId'] as Map?)?['name'] ?? 'Utilisateur'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _replyToMessage!['content'] ?? '',
                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.white),
                      onPressed: _cancelReply,
                    ),
                  ],
                ),
              ),

            // Mode enregistrement vocal
            if (_isRecording)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.red.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    const Icon(Icons.mic, color: Colors.red, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Enregistrement en cours...',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          Text(
                            _formatDuration(_recordingDuration),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _cancelRecording,
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: _stopRecording,
                    ),
                  ],
                ),
              ),

            // Fichiers sélectionnés
            if (_selectedFiles.isNotEmpty)
              Container(
                height: 80,
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, index) {
                    final file = _selectedFiles[index];
                    final isImage = file.path.toLowerCase().endsWith('.jpg') ||
                        file.path.toLowerCase().endsWith('.jpeg') ||
                        file.path.toLowerCase().endsWith('.png');

                    return Stack(
                      children: [
                        Container(
                          width: 70,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            image: isImage
                                ? DecorationImage(
                                    image: FileImage(file),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: isImage ? null : const Icon(Icons.insert_drive_file, color: Colors.white),
                        ),
                        Positioned(
                          top: -8,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                            onPressed: () => _removeFile(index),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            // Input principal
            if (!_isRecording)
              Container(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    // Bouton médias
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.add_circle,
                        color: const Color(0xFF00D4FF),
                        size: 32,
                        shadows: [
                          Shadow(
                            color: const Color(0xFF00D4FF).withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'image':
                            _pickImage();
                            break;
                          case 'camera':
                            _takePhoto();
                            break;
                          case 'video':
                            _pickVideo();
                            break;
                          case 'document':
                            _pickDocument();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'image',
                          child: Row(
                            children: [
                              Icon(Icons.image, color: Color(0xFF00D4FF)),
                              SizedBox(width: 12),
                              Text('Image'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'camera',
                          child: Row(
                            children: [
                              Icon(Icons.camera_alt, color: Color(0xFF00D4FF)),
                              SizedBox(width: 12),
                              Text('Caméra'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'video',
                          child: Row(
                            children: [
                              Icon(Icons.videocam, color: Color(0xFF00D4FF)),
                              SizedBox(width: 12),
                              Text('Vidéo'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'document',
                          child: Row(
                            children: [
                              Icon(Icons.insert_drive_file, color: Color(0xFF00D4FF)),
                              SizedBox(width: 12),
                              Text('Document'),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 8),

                    // Champ de texte
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onChanged: (value) => _notifyTyping(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Écrivez un message...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white70),
                            onPressed: () {
                              // Sélecteur d'emojis
                            },
                          ),
                        ),
                        maxLines: null,
                        maxLength: 4096,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                          return null; // Cache le compteur
                        },
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Bouton micro / envoyer
                    _isSending
                        ? const SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF00D4FF),
                              ),
                            ),
                          )
                        : _messageController.text.trim().isNotEmpty || _selectedFiles.isNotEmpty
                            ? Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00D4FF).withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  onPressed: _sendMessage,
                                ),
                              )
                            : GestureDetector(
                                onLongPressStart: (_) => _startRecording(),
                                onLongPressEnd: (_) => _stopRecording(),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.mic,
                                    color: Color(0xFF00D4FF),
                                    size: 24,
                                  ),
                                ),
                              ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    
    try {
      final date = DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inHours < 1) return '${diff.inMinutes} min';
      if (diff.inDays < 1) return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
