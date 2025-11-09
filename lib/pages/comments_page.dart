import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';
import '../api_service.dart';

class CommentsPage extends StatefulWidget {
  final String publicationId;
  final String publicationContent;

  const CommentsPage({
    super.key,
    required this.publicationId,
    required this.publicationContent,
  });

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  final List<File> _selectedFiles = [];
  String? _replyToId;
  String? _replyToName;
  String? _editingCommentId;
  String? _editingCommentContent;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _listenToWebSocket();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _listenToWebSocket() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    appProvider.webSocketStream.listen((message) {
      if (message['type'] == 'new_comment' && 
          message['publicationId'] == widget.publicationId) {
        setState(() {
          _comments.add(message['comment']);
        });
        _scrollToBottom();
      } else if (message['type'] == 'edit_comment' && 
                 message['publicationId'] == widget.publicationId) {
        _updateComment(message['comment']);
      } else if (message['type'] == 'delete_comment' && 
                 message['publicationId'] == widget.publicationId) {
        _removeComment(message['commentId']);
      } else if (message['type'] == 'like_comment' && 
                 message['publicationId'] == widget.publicationId) {
        _updateCommentLikes(message['commentId'], message['likes']);
      }
    });
  }

  void _updateComment(Map<String, dynamic> updatedComment) {
    setState(() {
      final index = _comments.indexWhere((c) => c['_id'] == updatedComment['_id']);
      if (index != -1) {
        _comments[index] = updatedComment;
      }
    });
  }

  void _removeComment(String commentId) {
    setState(() {
      _comments.removeWhere((c) => c['_id'] == commentId);
    });
  }

  void _updateCommentLikes(String commentId, List<dynamic> likes) {
    setState(() {
      final index = _comments.indexWhere((c) => c['_id'] == commentId);
      if (index != -1) {
        _comments[index]['likes'] = likes;
      }
    });
  }

  Future<void> _loadComments() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) return;

    try {
      final result = await ApiService.getPublicationComments(token, widget.publicationId);
      setState(() {
        _comments = List<Map<String, dynamic>>.from(result['comments'] ?? []);
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Erreur chargement commentaires: $e');
      setState(() => _isLoading = false);
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

  Future<void> _pickVideo() async {
    final XFile? video = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
    );

    if (video != null) {
      setState(() {
        _selectedFiles.add(File(video.path));
      });
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFiles.add(File(result.files.first.path!));
      });
    }
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
    if (_editingCommentId != null) {
      await _saveEditedComment();
      return;
    }

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) return;

    setState(() => _isSending = true);

    try {
      if (_selectedFiles.isNotEmpty) {
        // Envoi avec médias
        await ApiService.addCommentWithMedia(
          token,
          widget.publicationId,
          content: content.isNotEmpty ? content : null,
          mediaFiles: _selectedFiles,
          replyTo: _replyToId,
        );
      } else {
        // Envoi texte seulement
        await ApiService.addComment(
          token,
          widget.publicationId,
          content,
          replyTo: _replyToId,
        );
      }

      // Le commentaire sera ajouté via WebSocket, on réinitialise juste le formulaire
      setState(() {
        _messageController.clear();
        _selectedFiles.clear();
        _replyToId = null;
        _replyToName = null;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('Erreur envoi message: $e');
      _showError('Erreur d\'envoi: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _saveEditedComment() async {
    final content = _messageController.text.trim();
    
    if (content.isEmpty || _editingCommentId == null) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) return;

    setState(() => _isSending = true);

    try {
      // Mise à jour via l'API
      await ApiService.updateComment(
        token,
        widget.publicationId,
        _editingCommentId!,
        content,
      );

      // Mise à jour locale
      setState(() {
        final index = _comments.indexWhere((c) => c['_id'] == _editingCommentId);
        if (index != -1) {
          _comments[index]['content'] = content;
          _comments[index]['isEdited'] = true;
        }
        _messageController.clear();
        _editingCommentId = null;
        _editingCommentContent = null;
      });
    } catch (e) {
      debugPrint('Erreur modification commentaire: $e');
      _showError('Erreur de modification: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _replyTo(String commentId, String userName) {
    setState(() {
      _replyToId = commentId;
      _replyToName = userName;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToName = null;
    });
  }

  void _editComment(Map<String, dynamic> comment) {
    setState(() {
      _editingCommentId = comment['_id'];
      _editingCommentContent = comment['content'] ?? '';
      _messageController.text = _editingCommentContent!;
      // Annuler la réponse si on était en train de répondre
      _replyToId = null;
      _replyToName = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingCommentId = null;
      _editingCommentContent = null;
      _messageController.clear();
    });
  }

  Future<void> _likeComment(String commentId) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) return;

    try {
      await ApiService.likeComment(token, widget.publicationId, commentId);
    } catch (e) {
      debugPrint('Erreur like commentaire: $e');
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Supprimer', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Supprimer ce commentaire ?',
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
      await ApiService.deleteComment(token, widget.publicationId, commentId);
      setState(() {
        _comments.removeWhere((c) => c['_id'] == commentId);
      });
    } catch (e) {
      debugPrint('Erreur suppression commentaire: $e');
      _showError('Erreur de suppression');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00D4FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Commentaires',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_comments.length} messages',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // En-tête de la publication
          _buildPublicationHeader(),
          
          // Liste des commentaires
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          return _buildCommentBubble(_comments[index]);
                        },
                      ),
          ),

          // Barre d'input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildPublicationHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.article, color: Color(0xFF00D4FF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.publicationContent.length > 100
                  ? '${widget.publicationContent.substring(0, 100)}...'
                  : widget.publicationContent,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun commentaire',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Soyez le premier à commenter !',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentBubble(Map<String, dynamic> comment) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final currentUserId = appProvider.currentUser?['_id'] ?? appProvider.currentUser?['id'];
    final commentUser = comment['userId'] as Map<String, dynamic>?;
    final isOwnComment = commentUser?['_id'] == currentUserId;
    
    final profileImage = commentUser?['profileImage'] ?? '';
    final userName = commentUser?['name'] ?? 'Utilisateur';
    final content = comment['content'] ?? '';
    final media = comment['media'] as List<dynamic>? ?? [];
    final likes = comment['likes'] as List<dynamic>? ?? [];
    final isLiked = likes.contains(currentUserId);
    final isEdited = comment['isEdited'] == true;

    return Align(
      alignment: isOwnComment ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isOwnComment
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Photo + Nom
            if (!isOwnComment)
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
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

            // Bulle de message
            GestureDetector(
              onLongPress: () => _showCommentOptions(comment),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOwnComment
                      ? const Color(0xFF00D4FF)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Texte
                    if (content.isNotEmpty)
                      Text(
                        content,
                        style: TextStyle(
                          color: isOwnComment ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                      ),

                    // Médias
                    if (media.isNotEmpty) ...[
                      if (content.isNotEmpty) const SizedBox(height: 8),
                      ...media.map((m) => _buildMediaWidget(m)),
                    ],

                    // Timestamp + Édité
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(comment['createdAt']),
                          style: TextStyle(
                            color: isOwnComment
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.black54,
                            fontSize: 10,
                          ),
                        ),
                        if (isEdited) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(modifié)',
                            style: TextStyle(
                              color: isOwnComment
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : Colors.black54,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Actions (Like, Répondre)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Like
                  InkWell(
                    onTap: () => _likeComment(comment['_id']),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isLiked ? Colors.red : Colors.grey.shade600,
                        ),
                        if (likes.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${likes.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Répondre
                  InkWell(
                    onTap: () => _replyTo(comment['_id'], userName),
                    child: Text(
                      'Répondre',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
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

  Widget _buildMediaWidget(Map<String, dynamic> media) {
    final type = media['type'];
    final url = media['url'];

    if (type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.audiotrack, size: 20),
            SizedBox(width: 8),
            Text('Audio message', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showCommentOptions(Map<String, dynamic> comment) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final currentUserId = appProvider.currentUser?['_id'] ?? appProvider.currentUser?['id'];
    final commentUser = comment['userId'] as Map<String, dynamic>?;
    final isOwnComment = commentUser?['_id'] == currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modifier (seulement si c'est son propre commentaire)
            if (isOwnComment)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.orange),
                title: const Text('Modifier', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _editComment(comment);
                },
              ),
            
            // Supprimer (seulement si c'est son propre commentaire)
            if (isOwnComment)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Supprimer', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteComment(comment['_id']);
                },
              ),
            
            // Répondre (toujours disponible)
            ListTile(
              leading: const Icon(Icons.reply, color: Color(0xFF00D4FF)),
              title: const Text('Répondre', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _replyTo(comment['_id'], commentUser?['name'] ?? 'Utilisateur');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            offset: const Offset(0, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode Édition
          if (_editingCommentId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Modification du message',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _cancelEdit,
                  ),
                ],
              ),
            ),
          
          // Répondre à...
          if (_replyToName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Color(0xFF00D4FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Répondre à $_replyToName',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _cancelReply,
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
                  return Stack(
                    children: [
                      Container(
                        width: 70,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.insert_drive_file),
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

          // Input
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Bouton médias
                PopupMenuButton<String>(
                  icon: const Icon(Icons.add_circle, color: Color(0xFF00D4FF), size: 28),
                  onSelected: (value) {
                    if (value == 'image') {
                      _pickImage();
                    } else if (value == 'video') {
                      _pickVideo();
                    } else if (value == 'audio') {
                      _pickAudio();
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
                      value: 'audio',
                      child: Row(
                        children: [
                          Icon(Icons.mic, color: Color(0xFF00D4FF)),
                          SizedBox(width: 12),
                          Text('Audio'),
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
                    decoration: InputDecoration(
                      hintText: 'Écrivez un message...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),

                const SizedBox(width: 8),

                // Bouton envoyer
                _isSending
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00D4FF),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Color(0xFF00D4FF),
                          size: 28,
                        ),
                        onPressed: _sendMessage,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) {
      return '';
    }
    
    try {
      final date = timestamp is String
          ? DateTime.parse(timestamp)
          : DateTime.fromMillisecondsSinceEpoch(timestamp);
      
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) {
        return 'À l\'instant';
      }
      if (diff.inHours < 1) {
        return '${diff.inMinutes} min';
      }
      if (diff.inDays < 1) {
        return '${diff.inHours}h';
      }
      if (diff.inDays < 7) {
        return '${diff.inDays}j';
      }
      
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }
}
