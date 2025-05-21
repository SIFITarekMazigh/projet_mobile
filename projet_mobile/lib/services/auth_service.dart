import 'dart:async';
import 'package:projet_mobile/models/user_model.dart';

// Mock authentication service
class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Mock user data
  UserModel? _currentUser;
  final Map<String, String> _users = {
    'test@example.com': 'password123',
  };
  final Map<String, UserModel> _userProfiles = {
    'test@example.com': UserModel(
      id: '1',
      firstName: 'Jean',
      lastName: 'Dupont',
      email: 'test@example.com',
      createdAt: DateTime.now(),
    ),
  };

  // Stream controller for auth state changes
  final _authStateController = StreamController<UserModel?>.broadcast();
  Stream<UserModel?> get authStateChanges => _authStateController.stream;

  // Get current user
  UserModel? get currentUser => _currentUser;

  // Sign in with email and password
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    if (_users.containsKey(email) && _users[email] == password) {
      _currentUser = _userProfiles[email];
      _authStateController.add(_currentUser);
      return true;
    } else {
      throw Exception('Invalid email or password');
    }
  }

  // Register with email and password
  Future<bool> registerWithEmailAndPassword(
      String email, String password, String firstName, String lastName) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    if (_users.containsKey(email)) {
      throw Exception('Email already in use');
    }

    // Create new user
    _users[email] = password;
    _userProfiles[email] = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      firstName: firstName,
      lastName: lastName,
      email: email,
      createdAt: DateTime.now(),
    );

    return true;
  }

  // Sign out
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
    _authStateController.add(null);
  }

  // Get user data
  Future<UserModel?> getUserData() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _currentUser;
  }

  // Reset password (mock)
  Future<void> resetPassword(String email) async {
    await Future.delayed(const Duration(seconds: 1));
    if (!_users.containsKey(email)) {
      throw Exception('No user found with this email');
    }
    // In a real app, this would send a password reset email
  }

  // Update user profile
  Future<void> updateUserProfile(String firstName, String lastName) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (_currentUser != null) {
      final email = _currentUser!.email;
      _userProfiles[email] = UserModel(
        id: _currentUser!.id,
        firstName: firstName,
        lastName: lastName,
        email: email,
        createdAt: _currentUser!.createdAt,
      );
      _currentUser = _userProfiles[email];
      _authStateController.add(_currentUser);
    }
  }

  // Dispose
  void dispose() {
    _authStateController.close();
  }
}
