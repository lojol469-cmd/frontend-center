// lib/pages/chat_gpt_page.dart
// Interface ChatGPT-Style Ultra-Moderne avec Auto-Apprentissage

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class ChatGPTPage extends StatefulWidget {
  const ChatGPTPage({super.key});

  @override
  State<ChatGPTPage> createState() => _ChatGPTPageState();
}

class _ChatGPTPageState extends State<ChatGPTPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  
  bool _isTyping = false;
  bool _isLoading = false;
  
  // IP détectée automatiquement par le backend
  static const String baseUrl = 'https://center-backend-v9rf.onrender.com';
  
  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
    _messageController.addListener(() {
      setState(() {}); // Force rebuild when text changes
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(ChatMessage(
        text: "Bonjour ! Je suis un assistant IA ultra-puissant. Je peux :\n\n"
            "🔍 Rechercher sur internet\n"
            "👁️ Analyser des images\n"
            "📝 Résumer des textes\n"
            "😊 Analyser des sentiments\n"
            "🧠 Me souvenir de nos conversations\n"
            "✍️ Générer du contenu\n\n"
            "Comment puis-je vous aider aujourd'hui ?",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  Future<void> _sendMessage({String? text, File? imageFile, File? pdfFile}) async {
    final messageText = text ?? _messageController.text.trim();
    if (messageText.isEmpty && imageFile == null && pdfFile == null) return;

    // Ajouter le message utilisateur
    setState(() {
      _messages.add(ChatMessage(
        text: messageText,
        isUser: true,
        timestamp: DateTime.now(),
        imageFile: imageFile,
        pdfFile: pdfFile,
      ));
      _isTyping = true;
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      String response;
      List<ToolUsage> tools = [];

      if (imageFile != null || pdfFile != null) {
        // Upload fichier
        final result = await _uploadFile(imageFile ?? pdfFile!);
        response = result['message'] ?? 'Fichier analysé avec succès';
        tools = result['tools'] ?? [];
      } else {
        // Message texte simple
        final result = await _chat(messageText);
        response = result['response'] ?? '';
        tools = result['tools'] ?? [];
      }

      // Animation de typing
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
          tools: tools,
        ));
        _isTyping = false;
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Désolé, une erreur s'est produite : ${e.toString()}",
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
        _isTyping = false;
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _chat(String message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'message': message,
        'conversation_id': 'flutter_user',
        'use_memory': true,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // Extraire les outils utilisés
      final tools = <ToolUsage>[];
      if (data['sources'] != null) {
        for (var source in data['sources']) {
          tools.add(ToolUsage(
            name: source['tool'] ?? 'unknown',
            result: source['content'] ?? '',
          ));
        }
      }

      return {
        'response': data['response'] ?? '',
        'tools': tools,
      };
    } else {
      throw Exception('Erreur serveur: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> _uploadFile(File file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    final responseData = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = json.decode(responseData);
      
      // Lire les données de l'API
      final description = data['description'] ?? '';
      final synthesis = data['synthesis'] ?? '';
      final toolsUsed = data['tools_used'] ?? [];
      final totalChunks = data['total_chunks'];
      final totalPages = data['total_pages'];
      
      // Déterminer le type de fichier
      final isPDF = file.path.toLowerCase().endsWith('.pdf');
      
      // Créer le message avec les données réelles
      String message = '';
      
      if (isPDF && totalChunks != null) {
        // Message spécifique pour PDF avec RAG
        message = '📄 PDF analysé : ${data["filename"] ?? "document"}\n\n';
        message += '📖 Pages: $totalPages\n';
        message += '✂️ Chunks créés: $totalChunks\n\n';
        if (synthesis.isNotEmpty) {
          message += '📝 Résumé:\n$synthesis\n\n';
        }
        message += '✅ Document ajouté à votre base de connaissances RAG\n';
        message += '💡 Vous pouvez maintenant poser des questions sur ce document';
      } else {
        // Message pour images
        message = '🖼️ Fichier analysé : ${data["filename"] ?? "image"}\n\n';
        if (synthesis.isNotEmpty) {
          message += '📝 Synthèse:\n$synthesis\n\n';
        }
      }
      
      if (toolsUsed.isNotEmpty) {
        message += '\n🔧 Outils utilisés: ${toolsUsed.join(", ")}';
      }
      
      return {
        'message': message,
        'tools': [
          ToolUsage(
            name: isPDF ? 'RAG PDF' : 'Analyse d\'image', 
            result: synthesis.isNotEmpty ? synthesis : description
          ),
        ],
      };
    } else {
      throw Exception('Erreur upload: ${response.statusCode}');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showConversationHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2F2F3A),
        title: const Text(
          'Historique des conversations',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _messages.isEmpty
              ? const Center(
                  child: Text(
                    'Aucune conversation',
                    style: TextStyle(color: Color(0xFF6E6E80)),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return ListTile(
                      leading: Icon(
                        message.isUser ? Icons.person : Icons.auto_awesome,
                        color: message.isUser
                            ? const Color(0xFF5436DA)
                            : const Color(0xFF10A37F),
                      ),
                      title: Text(
                        message.isUser ? 'Vous' : 'Kibali Enfant Agent',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        message.text.length > 50
                            ? '${message.text.substring(0, 50)}...'
                            : message.text,
                        style: const TextStyle(color: Color(0xFF9B9BA5)),
                      ),
                      trailing: Text(
                        '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Color(0xFF6E6E80),
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Fermer',
              style: TextStyle(color: Color(0xFF10A37F)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    
    if (pickedFile != null) {
      await _sendMessage(
        text: "Analyse cette image",
        imageFile: File(pickedFile.path),
      );
    }
  }

  Future<void> _pickPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    
    if (result != null && result.files.single.path != null) {
      await _sendMessage(
        text: "Analyse ce PDF",
        pdfFile: File(result.files.single.path!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF343541),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : _buildMessagesList(),
          ),
          if (_isTyping) _buildTypingIndicator(),
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF343541),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10A37F), Color(0xFF1A7F64)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kibali Enfant Agent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Powered by Nyundu Francis Arnaud',
                  style: const TextStyle(
                    color: Color(0xFF6E6E80),
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history, color: Colors.white),
          onPressed: () {
            _showConversationHistory();
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: const Color(0xFF444654),
          onSelected: (value) {
            if (value == 'clear') {
              setState(() => _messages.clear());
              _addWelcomeMessage();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Effacer la conversation', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10A37F), Color(0xFF1A7F64)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 24),
          const Text(
            'Comment puis-je vous aider ?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 40),
          _buildSuggestionChips(),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips() {
    final suggestions = [
      {'icon': Icons.search, 'text': 'Rechercher sur internet'},
      {'icon': Icons.image, 'text': 'Analyser une image'},
      {'icon': Icons.summarize, 'text': 'Résumer un texte'},
      {'icon': Icons.create, 'text': 'Générer du contenu'},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: suggestions.map((s) => _buildSuggestionChip(
        s['icon'] as IconData,
        s['text'] as String,
      )).toList(),
    );
  }

  Widget _buildSuggestionChip(IconData icon, String text) {
    return InkWell(
      onTap: () {
        _messageController.text = text;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF444654),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF565869)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF10A37F), size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(message.isUser),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.isUser ? 'Vous' : 'Kibali Enfant Agent',
                  style: TextStyle(
                    color: message.isUser ? Colors.white : const Color(0xFF10A37F),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (message.imageFile != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      message.imageFile!,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (message.pdfFile != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF444654),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message.pdfFile!.path.split('\\').last.split('/').last,
                            style: const TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SelectableText(
                  message.text,
                  style: TextStyle(
                    color: message.isError ? Colors.red[300] : Colors.white,
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (message.tools.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildToolsUsed(message.tools),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isUser) {
    if (isUser) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF5436DA),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 20),
      );
    } else {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10A37F), Color(0xFF1A7F64)],
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
      );
    }
  }

  Widget _buildToolsUsed(List<ToolUsage> tools) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2B32),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF10A37F).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.build_circle, color: Color(0xFF10A37F), size: 16),
              SizedBox(width: 6),
              Text(
                'Outils utilisés',
                style: TextStyle(
                  color: Color(0xFF10A37F),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...tools.map((tool) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF10A37F), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _getToolLabel(tool.name),
                        style: const TextStyle(color: Color(0xFF9B9BA5), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _getToolLabel(String toolName) {
    const labels = {
      'search_internet': '🔍 Recherche internet',
      'analyze_image': '👁️ Analyse d\'image',
      'detect_objects': '🎯 Détection d\'objets',
      'summarize_text': '📝 Résumé',
      'extract_context': '🔍 Extraction de contexte',
      'analyze_sentiment': '😊 Analyse de sentiment',
      'search_memory': '🧠 Recherche mémoire',
      'create_paragraph': '✍️ Génération',
    };
    return labels[toolName] ?? toolName;
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10A37F), Color(0xFF1A7F64)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          const Text(
            'Kibali réfléchit',
            style: TextStyle(color: Color(0xFF6E6E80), fontSize: 14),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: (value + index * 0.3) % 1.0,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10A37F),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF40414F),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Bouton upload (Image/PDF)
              _buildActionButton(
                Icons.attach_file,
                onPressed: () => _showAttachMenu(),
              ),
              const SizedBox(width: 12),
              // Input field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10A37F),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          cursorColor: const Color(0xFF10A37F),
                          maxLines: null,
                          decoration: const InputDecoration(
                            hintText: 'Message Kibali...',
                            hintStyle: TextStyle(
                              color: Color(0xFF9E9E9E),
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Color(0xFF10A37F),
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _messageController.text.isNotEmpty
                                  ? const Color(0xFF10A37F)
                                  : const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_upward),
                              color: Colors.white,
                              iconSize: 20,
                              onPressed: _messageController.text.isNotEmpty
                                  ? () => _sendMessage()
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, {required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10A37F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF10A37F)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: onPressed,
        tooltip: 'Joindre un fichier (Image/PDF)',
      ),
    );
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2F2F3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF565869),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildAttachOption(
              Icons.photo_library,
              'Galerie',
              'Choisir une image',
              () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            _buildAttachOption(
              Icons.camera_alt,
              'Caméra',
              'Prendre une photo',
              () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            _buildAttachOption(
              Icons.picture_as_pdf,
              'PDF',
              'Importer un document',
              () {
                Navigator.pop(context);
                _pickPDF();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF10A37F).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF10A37F)),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF6E6E80))),
      onTap: onTap,
    );
  }
}

// ============================================================================
// MODELS
// ============================================================================

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<ToolUsage> tools;
  final File? imageFile;
  final File? pdfFile;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.tools = const [],
    this.imageFile,
    this.pdfFile,
    this.isError = false,
  });
}

class ToolUsage {
  final String name;
  final String result;

  ToolUsage({
    required this.name,
    required this.result,
  });
}
