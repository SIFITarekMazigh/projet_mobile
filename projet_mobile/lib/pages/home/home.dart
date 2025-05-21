import 'package:flutter/material.dart';
import 'package:projet_mobile/main.dart';
import 'package:projet_mobile/models/user_model.dart';
import 'package:projet_mobile/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  UserModel? _userData;
  bool _isLoading = true;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  Future<void> _getUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Essayer d'abord de récupérer les données depuis les préférences partagées
      final prefsUser = await _authService.getUserFromPrefs();

      if (prefsUser != null) {
        setState(() {
          _userData = prefsUser;
        });
        print(
            'Utilisateur récupéré depuis les préférences: ${prefsUser.email}');
        return;
      }

      // Si aucun utilisateur n'est trouvé dans les préférences, essayer Supabase
      final userData = await _authService.getUserData();

      if (userData != null) {
        setState(() {
          _userData = userData;
        });
        print('Utilisateur récupéré depuis Supabase: ${userData.email}');
      } else {
        if (mounted) {
          context.showSnackBar('Aucun utilisateur connecté', isError: true);
          // Rediriger vers la page de connexion
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des données: $e');

      // Dernière tentative: vérifier à nouveau les préférences
      try {
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('user_email');
        final firstName = prefs.getString('user_first_name') ?? 'Utilisateur';
        final lastName = prefs.getString('user_last_name') ?? '';

        if (email != null) {
          setState(() {
            _userData = UserModel(
              id: prefs.getString('user_id') ?? 'unknown',
              email: email,
              firstName: firstName,
              lastName: lastName,
              createdAt: null,
            );
          });
          print(
              'Utilisateur récupéré depuis les préférences (seconde tentative): $email');
          return;
        }
      } catch (prefError) {
        print('Erreur lors de la récupération des préférences: $prefError');
      }

      if (mounted) {
        context.showSnackBar(
            'Erreur lors du chargement des données: $e', isError: true);
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      // Déconnexion de Supabase
      await _authService.signOut();

      // Supprimer les données de session des préférences partagées
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('user_first_name');
      await prefs.remove('user_last_name');

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
            'Erreur lors de la déconnexion: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // User avatar
              CircleAvatar(
                radius: 50,
                backgroundColor: Theme
                    .of(context)
                    .colorScheme
                    .primaryContainer,
                child: Text(
                  _userData != null
                      ? _userData!.firstName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    fontSize: 40,
                    color: Theme
                        .of(context)
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Welcome message
              Text(
                'Bienvenue, ${_userData?.firstName ?? 'Utilisateur'}!',
                style: Theme
                    .of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // User email
              Text(
                _userData?.email ?? '',
                style: Theme
                    .of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                  color: Theme
                      .of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Success message
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: Colors.green,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Vous êtes connecté avec succès !',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Vous pouvez maintenant accéder à toutes les fonctionnalités de l\'application.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Logout button
              OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}