import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:projet_mobile/main.dart';
import 'package:projet_mobile/pages/home_page.dart';
import 'package:projet_mobile/pages/register_page.dart';
import 'package:projet_mobile/services/supabase_auth_service.dart';
import 'package:projet_mobile/services/face_recognition_service.dart';
import 'package:projet_mobile/services/audio_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isFaceLogin = false;
  XFile? _faceImage;
  Uint8List? _faceImageBytes;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = SupabaseAuthService();
  final _faceRecognitionService = FaceRecognitionService();
  final _audioService = AudioService();
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Veuillez entrer un email valide';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre mot de passe';
    }
    return null;
  }

  Future<void> _takeFacePhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery, // Use gallery for web compatibility
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        // Read image bytes
        final bytes = await pickedFile.readAsBytes();

        setState(() {
          _faceImage = pickedFile;
          _faceImageBytes = Uint8List.fromList(bytes);
        });

        // Proceed with face login
        _signInWithFace();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Erreur lors de la sélection de la photo: $e', isError: true);
      }
    }
  }

  Future<void> _signInWithFace() async {
    if (_faceImage == null || _faceImageBytes == null) {
      return;
    }

    if (_emailController.text.isEmpty) {
      context.showSnackBar('Veuillez entrer votre email pour l\'authentification faciale', isError: true);
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Get user ID from email
      final user = await _authService.getUserByEmail(_emailController.text.trim());

      if (user == null) {
        throw Exception('Utilisateur non trouvé');
      }

      // Compare faces
      final isMatch = await _faceRecognitionService.compareFaces(
        _faceImageBytes!,
        user.id,
      );

      if (isMatch) {
        // Play success sound
        await _audioService.playSuccessSound();

        // Sign in the user
        await _authService.signInWithEmailOnly(_emailController.text.trim());

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      } else {
        // Play failure sound
        await _audioService.playFailureSound();

        if (mounted) {
          context.showSnackBar('Authentification faciale échouée. Veuillez réessayer.', isError: true);
        }
      }
    } catch (e) {
      // Play failure sound
      await _audioService.playFailureSound();

      if (mounted) {
        context.showSnackBar('Erreur: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final success = await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success) {
        // Play success sound
        await _audioService.playSuccessSound();

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      } else {
        // Play failure sound
        await _audioService.playFailureSound();

        if (mounted) {
          context.showSnackBar('Email ou mot de passe incorrect', isError: true);
        }
      }
    } catch (e) {
      // Play failure sound
      await _audioService.playFailureSound();

      if (mounted) {
        context.showSnackBar('Erreur: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleLoginMethod() {
    setState(() {
      _isFaceLogin = !_isFaceLogin;
      _faceImage = null;
      _faceImageBytes = null;
    });
  }

  void _navigateToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App logo or icon
                Icon(
                  Icons.face,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'Bienvenue',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Connectez-vous pour continuer',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Email field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: _validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 16),

                // Password field or Face login
                if (_isFaceLogin)
                  Container(
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _takeFacePhoto,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                              image: _faceImageBytes != null
                                  ? DecorationImage(
                                image: MemoryImage(_faceImageBytes!),
                                fit: BoxFit.cover,
                              )
                                  : null,
                            ),
                            child: _faceImage == null
                                ? Icon(
                              Icons.camera_alt,
                              size: 50,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _faceImage == null
                              ? 'Sélectionner une photo de votre visage'
                              : 'Photo sélectionnée',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (kIsWeb)
                          const Text(
                            'Note: Sur le web, la détection faciale est simulée',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: _validatePassword,
                    obscureText: !_isPasswordVisible,
                    autofillHints: const [AutofillHints.password],
                  ),
                const SizedBox(height: 16),

                // Toggle login method
                TextButton.icon(
                  onPressed: _toggleLoginMethod,
                  icon: Icon(_isFaceLogin ? Icons.password : Icons.face),
                  label: Text(_isFaceLogin
                      ? 'Se connecter avec mot de passe'
                      : 'Se connecter avec reconnaissance faciale'),
                ),
                const SizedBox(height: 24),

                // Sign in button
                FilledButton(
                  onPressed: _isLoading
                      ? null
                      : _isFaceLogin
                      ? _takeFacePhoto
                      : _signInWithPassword,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Connexion en cours...'),
                    ],
                  )
                      : Text(_isFaceLogin
                      ? 'Sélectionner une photo'
                      : 'Se connecter'),
                ),
                const SizedBox(height: 16),

                // Forgot password
                if (!_isFaceLogin)
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () {
                        // Implement forgot password functionality
                      },
                      child: const Text('Mot de passe oublié ?'),
                    ),
                  ),

                const SizedBox(height: 24),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Vous n'avez pas de compte ?",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: _navigateToRegister,
                      child: const Text("S'inscrire"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
