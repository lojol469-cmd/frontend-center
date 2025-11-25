import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../api_service.dart';
import '../components/gradient_button.dart';
import '../components/custom_text_field.dart';
import '../components/connection_status.dart';
import '../components/image_background.dart';
import '../utils/background_image_manager.dart';
import 'setraf_landing_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _showOtpField = false;
  String _message = '';
  late String _selectedImage;
  final BackgroundImageManager _imageManager = BackgroundImageManager();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Sélectionner une image pour l'authentification
    _selectedImage = _imageManager.getImageForPage('auth');
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ImageBackground(
        imagePath: _selectedImage,
        opacity: 0.35, // Réduit pour éviter le voile blanc
        withGradient: false, // Désactivé pour clarté maximale
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildContent(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Indicateur de statut de connexion
          const ConnectionStatusWidget(),
          const SizedBox(height: 40),
          _buildHeader(),
          const SizedBox(height: 60),
          _buildForm(),
          const SizedBox(height: 30),
          _buildAuthToggle(),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildMessage(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SetrafLandingPage(),
              ),
            );
          },
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFF00FF88),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF88).withValues(alpha: 0.3),
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Image.asset(
                'assets/images/app_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF00FF88), Color(0xFF00CC66)],
          ).createShader(bounds),
          child: Text(
            'CENTER',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 4,
              shadows: [
                Shadow(
                  color: const Color(0xFF00FF88).withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Personnel & Social Network',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        if (!_isLogin) ...[
          CustomTextField(
            controller: _nameController,
            label: 'Nom complet',
            icon: Icons.person_rounded,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),
        ],
        CustomTextField(
          controller: _emailController,
          label: 'Email',
          icon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
        ),
        if (!_showOtpField) ...[
          const SizedBox(height: 16),
          CustomTextField(
            controller: _passwordController,
            label: 'Mot de passe',
            icon: Icons.lock_rounded,
            obscureText: true,
            enabled: !_isLoading,
          ),
        ],
        if (_showOtpField) ...[
          const SizedBox(height: 16),
          CustomTextField(
            controller: _otpController,
            label: 'Code OTP',
            icon: Icons.security_rounded,
            keyboardType: TextInputType.number,
            enabled: !_isLoading,
          ),
        ],
        const SizedBox(height: 32),
        GradientButton(
          onPressed: _isLoading ? null : _handleAuth,
          isLoading: _isLoading,
          child: Text(
            _showOtpField ? 'Vérifier OTP' : (_isLogin ? 'Se connecter' : 'S\'inscrire'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin ? 'Pas de compte ?' : 'Déjà un compte ?',
          style: TextStyle(
            color: Colors.black54,
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : () {
            setState(() {
              _isLogin = !_isLogin;
              _showOtpField = false;
              _message = '';
              _otpController.clear();
            });
          },
          child: Text(
            _isLogin ? 'S\'inscrire' : 'Se connecter',
            style: const TextStyle(
              color: Color(0xFF00FF88),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage() {
    final isError = _message.toLowerCase().contains('erreur');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isError
          ? Colors.red.withValues(alpha: 0.1)
          : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
            ? Colors.red
            : const Color(0xFF00FF88),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isError
              ? Colors.red.withValues(alpha: 0.2)
              : const Color(0xFF00FF88).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_rounded : Icons.info_rounded,
            color: isError ? Colors.red : const Color(0xFF00FF88),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _message,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAuth() async {
    if (_showOtpField) {
      await _verifyOtp();
    } else if (_isLogin) {
      await _login();
    } else {
      await _register();
    }
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _message = 'Veuillez remplir tous les champs');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      // CODE PRODUCTION : Utiliser le processus OTP normal
      final result = await ApiService.login(_emailController.text);
      
      if (result.containsKey('message') && 
          result['message'].toString().contains('OTP')) {
        setState(() {
          _showOtpField = true;
          _message = result['message'];
        });
      } else if (result.containsKey('accessToken')) {
        if (mounted) {
          final appProvider = Provider.of<AppProvider>(context, listen: false);
          appProvider.setAuthenticated(
            true,
            token: result['accessToken'],
            user: result['user'],
          );
        }
      } else {
        setState(() => _message = result['message'] ?? 'Erreur de connexion');
      }
      
      /* CODE TEMPORAIRE POUR LES TESTS (décommenter si nécessaire):
      final result = await ApiService.adminLogin(
        _emailController.text,
        _passwordController.text,
      );
      
      if (result.containsKey('accessToken') && result['accessToken'] != null) {
        if (mounted) {
          final appProvider = Provider.of<AppProvider>(context, listen: false);
          appProvider.setAuthenticated(
            true,
            token: result['accessToken'],
            user: result['user'],
          );
        }
      } else {
        setState(() => _message = result['message'] ?? 'Erreur de connexion');
      }
      */
    } catch (e) {
      setState(() => _message = 'Erreur: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    // Validation plus stricte des champs
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // DEBUG : Afficher les valeurs
    debugPrint('🔍 DEBUG INSCRIPTION:');
    debugPrint('  Nom: "$name" (longueur: ${name.length}, vide: ${name.isEmpty})');
    debugPrint('  Email: "$email" (longueur: ${email.length}, vide: ${email.isEmpty})');
    debugPrint('  Password: "$password" (longueur: ${password.length}, vide: ${password.isEmpty})');

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      List<String> missingFields = [];
      if (name.isEmpty) missingFields.add('nom');
      if (email.isEmpty) missingFields.add('email');
      if (password.isEmpty) missingFields.add('mot de passe');
      
      setState(() => _message = 'Champs manquants: ${missingFields.join(", ")}');
      return;
    }

    // Validation du format email
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _message = 'Format email invalide: $email');
      return;
    }

    // Validation de la longueur du mot de passe
    if (password.length < 6) {
      setState(() => _message = 'Mot de passe trop court (${password.length} caractères, minimum 6)');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      debugPrint('📤 Envoi de la requête d\'inscription...');
      final result = await ApiService.register(email, password, name);

      debugPrint('✅ Inscription réussie: $result');
      setState(() {
        _showOtpField = true;
        _message = result['message'] ?? 'Code OTP envoyé !';
      });
    } catch (e) {
      debugPrint('❌ Erreur inscription: $e');
      setState(() => _message = 'Erreur: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) {
      setState(() => _message = 'Veuillez entrer le code OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final result = await ApiService.verifyOtp(_emailController.text, _otpController.text);
      
      if (result.containsKey('accessToken') && result['accessToken'] != null) {
        if (mounted) {
          final appProvider = Provider.of<AppProvider>(context, listen: false);
          appProvider.setAuthenticated(
            true,
            token: result['accessToken'],
            user: result['user'],
          );
        }
      } else {
        setState(() => _message = result['message'] ?? 'Erreur de vérification');
      }
    } catch (e) {
      setState(() => _message = 'Code OTP invalide ou expiré');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
