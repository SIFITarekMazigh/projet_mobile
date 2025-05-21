import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:projet_mobile/services/face_recognition_service.dart';

import '../models/user_model.dart';

class SupabaseAuthService {
  // Singleton pattern
  static final SupabaseAuthService _instance = SupabaseAuthService._internal();
  factory SupabaseAuthService() => _instance;
  SupabaseAuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final FaceRecognitionService _faceRecognitionService = FaceRecognitionService();

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Stream for auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Sign in with email and password
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      print('Attempting email/password login for $email');
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        print('Login successful for $email');
        await _ensureProfileExists(response.user!);
        if (response.session?.refreshToken != null) {
          await storeRefreshToken(response.session!.refreshToken!);
        }
        return true;
      }
      print('Login failed for $email: user null');
      return false;
    } catch (e) {
      print('Login error for $email: $e');
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // Register with email and password
  Future<bool> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required Uint8List faceImageBytes,
  }) async {
    try {
      print('Tentative d\'inscription pour $email');
      // Register user
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
        },
      );

      if (response.user == null) {
        print('Échec d\'inscription pour $email: utilisateur null');
        throw Exception('Échec de création du compte');
      }

      print('Inscription réussie pour $email, ID: ${response.user!.id}');

      // Upload face image
      final userId = response.user!.id;
      final imagePath = '$userId.jpg';

      print('Téléchargement de l\'image faciale pour $email');
      await _supabase.storage.from('images').uploadBinary(
        imagePath,
        faceImageBytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
        ),
      );
      print('Image faciale téléchargée avec succès pour $email');

      // Create profile record - using insert instead of upsert
      try {
        print('Création du profil pour $email');
        await _supabase.from('profiles').insert({
          'id': userId,
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'face_image_path': imagePath,
        });

        print('Profil créé avec succès pour $email');
      } catch (e) {
        print('Erreur lors de la création du profil pour $email: $e');
        // Essayer une approche alternative
        try {
          print('Tentative de création de profil via RPC pour $email');
          await _supabase.rpc('create_profile', params: {
            'user_id': userId,
            'user_email': email,
            'first_name': firstName,
            'last_name': lastName,
            'face_path': imagePath,
          });
          print('Profil créé via RPC pour $email');
        } catch (rpcError) {
          print('Erreur RPC pour $email: $rpcError');
        }
      }

      return true;
    } catch (e) {
      print('Erreur d\'inscription pour $email: $e');
      throw Exception('Échec d\'inscription: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    print('Déconnexion de l\'utilisateur ${currentUser?.email}');
    await _supabase.auth.signOut();
    print('Déconnexion réussie');
  }

  // Get user data
  Future<UserModel?> getUserData() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        print('Impossible de récupérer les données utilisateur: utilisateur non connecté');
        return null;
      }

      print('Récupération des données pour l\'utilisateur $userId');

      // Vérifier si le profil existe
      final profileExists = await _checkProfileExists(userId);

      if (!profileExists) {
        print('Profil non trouvé pour $userId, création d\'un nouveau profil');
        // Créer le profil s'il n'existe pas
        await _createProfileFromAuthData(userId);
      }

      // Récupérer les données du profil
      try {
        print('Récupération du profil pour $userId');
        final response = await _supabase
            .from('profiles')
            .select()
            .eq('id', userId)
            .single();

        print('Profil récupéré pour $userId: ${response['email']}');

        return UserModel(
          id: response['id'],
          firstName: response['first_name'] ?? '',
          lastName: response['last_name'] ?? '',
          email: response['email'],
          createdAt: response['created_at'] != null
              ? DateTime.parse(response['created_at'])
              : null,
        );
      } catch (e) {
        print('Erreur lors de la récupération du profil pour $userId: $e');

        // Si le profil n'existe pas, créer un modèle à partir des données d'authentification
        print('Création d\'un modèle utilisateur à partir des données d\'authentification');
        return UserModel(
          id: userId,
          firstName: currentUser?.userMetadata?['first_name'] ?? '',
          lastName: currentUser?.userMetadata?['last_name'] ?? '',
          email: currentUser?.email ?? '',
          createdAt: null,
        );
      }
    } catch (e) {
      print('Erreur lors de la récupération des données utilisateur: $e');
      return null;
    }
  }

  Future<bool> signUp(String email, String password) async {
    try {
      print('Inscription simple pour $email');
      await _supabase.auth.signUp(email: email, password: password);
      print('Inscription simple réussie pour $email');
      return true;
    } catch (e) {
      print('Erreur lors de l\'inscription simple pour $email: $e');
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      print('Connexion simple pour $email');
      await _supabase.auth.signInWithPassword(email: email, password: password);
      print('Connexion simple réussie pour $email');
      return true;
    } catch (e) {
      print('Erreur lors de la connexion simple pour $email: $e');
      return false;
    }
  }

  Future<void> storeRefreshToken(String refreshToken) async {
    print('Stockage du jeton de rafraîchissement');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('refresh_token', refreshToken);
  }

  Future<String?> getRefreshToken() async {
    print('Récupération du jeton de rafraîchissement');
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  Future<void> removeRefreshToken() async {
    print('Suppression du jeton de rafraîchissement');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('refresh_token');
  }

  // Get face image URL for a user
  Future<String?> getFaceImageUrl(String userId) async {
    try {
      print('Récupération de l\'URL de l\'image faciale pour $userId');
      // Essayer d'obtenir le chemin de l'image depuis le profil
      try {
        final response = await _supabase
            .from('profiles')
            .select('face_image_path')
            .eq('id', userId)
            .single();

        final imagePath = response['face_image_path'];
        if (imagePath != null) {
          final url = _supabase.storage.from('images').getPublicUrl(imagePath);
          print('URL de l\'image faciale trouvée dans le profil: $url');
          return url;
        }
      } catch (e) {
        print('Profil non trouvé ou sans chemin d\'image pour $userId: $e');
      }

      // Si le chemin n'est pas trouvé, essayer avec l'ID utilisateur comme nom de fichier
      final defaultPath = '$userId.jpg';

      // Vérifier si l'image existe dans le stockage
      try {
        final url = _supabase.storage.from('images').getPublicUrl(defaultPath);
        print('URL de l\'image faciale trouvée avec le chemin par défaut: $url');
        return url;
      } catch (e) {
        print('Image non trouvée dans le stockage pour $userId: $e');
        return null;
      }
    } catch (e) {
      print('Erreur lors de la récupération de l\'URL de l\'image pour $userId: $e');
      return null;
    }
  }

  // Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      print('Recherche de l\'utilisateur par email: $email');
      // D'abord, essayer de trouver l'utilisateur dans la table profiles
      try {
        final profileResponse = await _supabase
            .from('profiles')
            .select()
            .eq('email', email)
            .single();

        print('Utilisateur trouvé dans la table profiles: ${profileResponse['id']}');

        return UserModel(
          id: profileResponse['id'],
          firstName: profileResponse['first_name'] ?? '',
          lastName: profileResponse['last_name'] ?? '',
          email: email,
          createdAt: profileResponse['created_at'] != null
              ? DateTime.parse(profileResponse['created_at'])
              : null,
        );
      } catch (e) {
        print('Profil non trouvé pour $email: $e');
      }

      // Si non trouvé dans profiles, chercher dans auth.users via currentUser
      if (currentUser?.email?.toLowerCase() == email.toLowerCase()) {
        final userId = currentUser!.id;
        print('Utilisateur trouvé via currentUser: $userId');

        // Créer un profil pour cet utilisateur
        await _createProfileFromAuthData(userId);

        return UserModel(
          id: userId,
          firstName: currentUser?.userMetadata?['first_name'] ?? '',
          lastName: currentUser?.userMetadata?['last_name'] ?? '',
          email: email,
          createdAt: null,
        );
      }

      // Essayer de trouver l'utilisateur via RPC
      try {
        print('Recherche de l\'utilisateur via RPC pour $email');
        final rpcResponse = await _supabase.rpc(
          'find_user_by_email',
          params: {'user_email': email},
        );

        if (rpcResponse != null && rpcResponse.isNotEmpty) {
          final userData = rpcResponse[0];
          print('Utilisateur trouvé via RPC: ${userData['id']}');

          return UserModel(
            id: userData['id'],
            firstName: userData['first_name'] ?? '',
            lastName: userData['last_name'] ?? '',
            email: email,
            createdAt: userData['created_at'] != null
                ? DateTime.parse(userData['created_at'])
                : null,
          );
        }
      } catch (e) {
        print('Erreur lors de la recherche via RPC pour $email: $e');
      }

      print('Utilisateur non trouvé pour $email');
      throw Exception('Utilisateur non trouvé');
    } catch (e) {
      print('Erreur lors de la recherche de l\'utilisateur par email $email: $e');
      return null;
    }
  }

  // Sign in with face
  Future<bool> signInWithFace({
    required String email,
    required Uint8List faceImageBytes,
  }) async {
    try {
      print('Attempting face login for $email');

      // Find user by email
      final user = await getUserByEmail(email);
      if (user == null) {
        print('User not found for email: $email');
        throw Exception('User not found');
      }

      print('User found: ${user.id}');

      // Ensure profile exists
      final profileExists = await _checkProfileExists(user.id);
      if (!profileExists) {
        print('Creating profile for ${user.id}');
        await _createProfileFromAuthData(user.id);
      }

      // Compare faces
      final isMatch = await _faceRecognitionService.compareFaces(
        faceImageBytes,
        user.id,
      );

      print('Face comparison result: $isMatch');

      if (!isMatch) {
        print('Face comparison failed for $email');
        return false;
      }

      // Check for existing session
      if (_supabase.auth.currentSession != null) {
        print('Existing session found for $email');
        return true;
      }

      // Try to restore session with refresh token
      final refreshToken = await getRefreshToken();
      if (refreshToken != null) {
        try {
          print('Restoring session with refresh token for $email');
          final response = await _supabase.auth.refreshSession(refreshToken);
          if (response.session != null) {
            print('Session restored successfully for $email');
            return true;
          }
        } catch (e) {
          print('Error restoring session for $email: $e');
        }
      }

      // Fallback: Prompt for password (or implement secure token storage)
      print('No valid session or refresh token, manual login required');
      throw Exception('No valid session. Please log in with password first.');
    } catch (e) {
      print('Error during face authentication for $email: $e');
      return false;
    }
  }
  // Vérifier si un profil existe pour un utilisateur
  Future<bool> _checkProfileExists(String userId) async {
    try {
      print('Vérification de l\'existence du profil pour $userId');
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      final exists = response != null;
      print('Profil pour $userId existe: $exists');
      return exists;
    } catch (e) {
      print('Erreur lors de la vérification du profil pour $userId: $e');
      return false;
    }
  }

  // Créer un profil à partir des données d'authentification
  Future<void> _createProfileFromAuthData(String userId) async {
    try {
      print('Création du profil pour l\'utilisateur $userId');

      // Vérifier si l'image existe dans le stockage
      String? imagePath;
      try {
        // Essayer avec l'ID utilisateur comme nom de fichier
        final defaultPath = '$userId.jpg';
        _supabase.storage.from('images').getPublicUrl(defaultPath);
        imagePath = defaultPath;
        print('Image trouvée pour $userId: $imagePath');
      } catch (e) {
        print('Image non trouvée dans le stockage pour $userId: $e');
      }

      // Obtenir les données utilisateur
      String email = '';
      String firstName = '';
      String lastName = '';

      if (currentUser?.id == userId) {
        email = currentUser?.email ?? '';
        firstName = currentUser?.userMetadata?['first_name'] ?? '';
        lastName = currentUser?.userMetadata?['last_name'] ?? '';
        print('Données utilisateur récupérées pour $userId: $email, $firstName, $lastName');
      }

      // Créer le profil - essayer d'abord avec insert
      try {
        print('Tentative d\'insertion du profil pour $userId');
        await _supabase.from('profiles').insert({
          'id': userId,
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'face_image_path': imagePath,
        });

        print('Profil créé avec succès pour $userId');
      } catch (insertError) {
        print('Erreur lors de l\'insertion du profil pour $userId: $insertError');

        // Essayer avec upsert
        try {
          print('Tentative d\'upsert du profil pour $userId');
          await _supabase.from('profiles').upsert({
            'id': userId,
            'email': email,
            'first_name': firstName,
            'last_name': lastName,
            'face_image_path': imagePath,
          });

          print('Profil créé avec upsert pour $userId');
        } catch (upsertError) {
          print('Erreur lors de l\'upsert du profil pour $userId: $upsertError');
        }
      }
    } catch (e) {
      print('Erreur lors de la création du profil pour $userId: $e');
    }
  }

  // Assurer qu'un profil existe pour un utilisateur
  Future<void> _ensureProfileExists(User user) async {
    try {
      print('Vérification/création du profil pour ${user.id}');
      final profileExists = await _checkProfileExists(user.id);

      if (!profileExists) {
        print('Profil non trouvé pour ${user.id}, création d\'un nouveau profil');
        await _createProfileFromAuthData(user.id);
      } else {
        print('Profil existant pour ${user.id}');
      }
    } catch (e) {
      print('Erreur lors de la vérification/création du profil pour ${user.id}: $e');
    }
  }
}