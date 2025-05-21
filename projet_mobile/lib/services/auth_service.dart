import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:projet_mobile/services/face_recognition_service.dart';
import 'package:projet_mobile/models/user_model.dart';
import 'package:image_picker/image_picker.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final FaceRecognitionService _faceRecognitionService = FaceRecognitionService();

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Stream for auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Sign in with email and password
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      print('Tentative de connexion avec email/mot de passe pour $email');
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        print('Connexion réussie pour $email');
        // Vérifier si le profil existe, sinon le créer
        await _ensureProfileExists(response.user!);
        return true;
      }
      print('Échec de connexion pour $email: utilisateur null');
      return false;
    } catch (e) {
      print('Erreur de connexion pour $email: $e');
      throw Exception('Échec de connexion: ${e.toString()}');
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
    XFile? faceImage,
  }) async {
    try {
      print('Tentative de connexion faciale pour $email');

      // Trouver l'utilisateur par email
      final user = await getUserByEmail(email);
      if (user == null) {
        print('Utilisateur non trouvé pour l\'email: $email');
        throw Exception('Utilisateur non trouvé');
      }

      print('Utilisateur trouvé: ${user.id}');

      // Vérifier si le profil existe, sinon le créer
      final profileExists = await _checkProfileExists(user.id);
      if (!profileExists) {
        print('Création du profil pour ${user.id}');
        await _createProfileFromAuthData(user.id);
      }

      // Comparer les visages
      final isMatch = await _faceRecognitionService.compareFaces(
        faceImageBytes,
        user.id,
        faceImage: faceImage,
      );

      print('Résultat de la comparaison faciale: $isMatch');

      if (!isMatch) {
        print('Échec de la comparaison faciale pour $email');
        return false;
      }

      // Si la comparaison faciale réussit, créer une session manuellement
      try {
        // Stocker les informations de l'utilisateur dans les préférences partagées
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', user.id);
        await prefs.setString('user_email', user.email);
        await prefs.setString('user_first_name', user.firstName);
        await prefs.setString('user_last_name', user.lastName);

        print('Session utilisateur créée manuellement pour $email');

        // Créer une session Supabase si possible
        try {
          // Essayer de se connecter avec un jeton anonyme ou une autre méthode
          // Cette partie est optionnelle et peut être ignorée si elle échoue
          await _supabase.auth.signInAnonymously();
          print('Session anonyme Supabase créée pour $email');
        } catch (e) {
          print('Impossible de créer une session Supabase: $e');
          // Continuer quand même, nous utiliserons la session manuelle
        }

        return true;
      } catch (e) {
        print('Erreur lors de la création de la session pour $email: $e');
        return false;
      }
    } catch (e) {
      print('Erreur lors de l\'authentification faciale pour $email: $e');
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

  // Récupérer l'utilisateur à partir des préférences partagées (pour l'authentification faciale)
  Future<UserModel?> getUserFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final email = prefs.getString('user_email');
      final firstName = prefs.getString('user_first_name');
      final lastName = prefs.getString('user_last_name');

      print('Tentative de récupération utilisateur depuis préférences - ID: $userId, Email: $email');

      if (userId != null && email != null) {
        print('Utilisateur trouvé dans les préférences: $email');
        return UserModel(
          id: userId,
          firstName: firstName ?? '',
          lastName: lastName ?? '',
          email: email,
          createdAt: null,
        );
      }

      print('Aucun utilisateur trouvé dans les préférences');
      return null;
    } catch (e) {
      print('Erreur lors de la récupération de l\'utilisateur depuis les préférences: $e');
      return null;
    }
  }
}