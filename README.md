# Système d'Authentification Faciale - Flutter & Supabase


Une application mobile de reconnaissance faciale développée avec Flutter et Supabase, permettant aux utilisateurs de s'authentifier via reconnaissance faciale ou méthode traditionnelle (email/mot de passe).
<!--
<p align="center">
  <img src="screenshots/login_screen.png" width="200" alt="Écran de connexion">
  <img src="screenshots/face_auth_screen.png" width="200" alt="Authentification faciale">
  <img src="screenshots/home_screen.png" width="200" alt="Écran d'accueil">
</p>
-->
## 📱 Fonctionnalités

- **Double méthode d'authentification** : Email/mot de passe ou reconnaissance faciale
- **Inscription sécurisée** : Création de compte avec capture de visage
- **Reconnaissance faciale** : Comparaison d'images pour l'authentification
- **Stockage cloud** : Images faciales stockées dans Supabase Storage
- **Interface utilisateur intuitive** : Design Material 3 responsive
- **Retour sonore** : Feedback audio lors de l'authentification
- **Persistance de session** : Maintien de la connexion utilisateur
- **Réinitialisation de mot de passe** : Processus sécurisé de récupération

## 🛠️ Technologies utilisées

- **Flutter** : Framework UI multiplateforme
- **Supabase** : Backend as a Service (BaaS)
- **Google ML Kit** : Détection faciale
- **Image Processing** : Traitement et comparaison d'images
- **Shared Preferences** : Stockage local
- **Material 3** : Design system

## ⚙️ Packages principaux

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.2
  supabase_flutter: ^2.9.0
  google_ml_kit: ^0.20.0
  image_picker: ^1.1.2
  camera: ^0.11.1
  path_provider: ^2.1.5
  path: ^1.9.1
  audioplayers: ^6.4.0
  uuid: ^4.5.1
  http: ^1.4.0
  image: ^4.5.4
  shared_preferences: ^2.5.3
