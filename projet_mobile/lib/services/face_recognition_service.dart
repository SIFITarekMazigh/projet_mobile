import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:projet_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class FaceRecognitionService {
  // Singleton pattern
  static final FaceRecognitionService _instance = FaceRecognitionService._internal();
  factory FaceRecognitionService() => _instance;

  // Face detector
  late FaceDetector _faceDetector;

  // Pour le débogage - mettre à false pour une véritable comparaison
  final bool _forceAuthSuccess = false;

  // Seuil de similarité par défaut (peut être ajusté dynamiquement)
  double _similarityThreshold = 0.65; // Augmenté de 0.35 à 0.65 pour être plus strict

  // Clé pour stocker les seuils personnalisés
  final String _thresholdPrefsKey = 'face_similarity_threshold';

  XFile? _faceImage;

  FaceRecognitionService._internal() {
    // Initialize ML Kit face detector for all platforms
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    _loadSimilarityThreshold();
  }

  // Charger le seuil de similarité depuis les préférences
  Future<void> _loadSimilarityThreshold() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final threshold = prefs.getDouble(_thresholdPrefsKey);
      if (threshold != null) {
        _similarityThreshold = threshold;
        print('Seuil de similarité chargé: $_similarityThreshold');
      }
    } catch (e) {
      print('Erreur lors du chargement du seuil de similarité: $e');
    }
  }

  // Sauvegarder le seuil de similarité dans les préférences
  Future<void> _saveSimilarityThreshold() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_thresholdPrefsKey, _similarityThreshold);
      print('Seuil de similarité sauvegardé: $_similarityThreshold');
    } catch (e) {
      print('Erreur lors de la sauvegarde du seuil de similarité: $e');
    }
  }

  // Ajuster le seuil de similarité en fonction des résultats
  Future<void> _adjustSimilarityThreshold(double similarity, bool isCorrectMatch) async {
    // Si c'est un vrai positif mais que la similarité est proche du seuil
    if (isCorrectMatch && similarity < _similarityThreshold + 0.1) {
      // Réduire légèrement le seuil
      _similarityThreshold = math.max(0.2, _similarityThreshold - 0.02);
      await _saveSimilarityThreshold();
      print('Seuil de similarité ajusté à la baisse: $_similarityThreshold');
    }
    // Si c'est un faux négatif (la similarité est proche mais inférieure au seuil)
    else if (isCorrectMatch && similarity < _similarityThreshold) {
      // Réduire davantage le seuil
      _similarityThreshold = math.max(0.2, similarity - 0.05);
      await _saveSimilarityThreshold();
      print('Seuil de similarité ajusté à la baisse (faux négatif): $_similarityThreshold');
    }
    // Si c'est un faux positif (la similarité est supérieure au seuil mais ce n'est pas un match)
    else if (!isCorrectMatch && similarity >= _similarityThreshold) {
      // Augmenter le seuil
      _similarityThreshold = math.min(0.7, similarity + 0.05);
      await _saveSimilarityThreshold();
      print('Seuil de similarité ajusté à la hausse (faux positif): $_similarityThreshold');
    }
  }

  // Compare faces for authentication
  Future<bool> compareFaces(Uint8List capturedImageBytes, String userId, {XFile? faceImage}) async {
    try {
      _faceImage = faceImage; // Stocker l'image pour une utilisation alternative
      print('Début de la comparaison faciale pour l\'utilisateur $userId');

      // Pour le débogage - forcer l'authentification à réussir
      if (_forceAuthSuccess) {
        print('Mode débogage: authentification forcée à réussir');
        return true;
      }

      // Get the stored face image URL
      final storedImageUrl = await AuthService().getFaceImageUrl(userId);
      if (storedImageUrl == null) {
        print('Aucune image de visage stockée trouvée');
        return false;
      }

      print('Image stockée trouvée: $storedImageUrl');

      // Download the stored image
      final response = await http.get(Uri.parse(storedImageUrl));
      if (response.statusCode != 200) {
        print('Échec du téléchargement de l\'image stockée: ${response.statusCode}');
        return false;
      }
      final storedImageBytes = response.bodyBytes;

      // Prétraiter les images
      final processedCapturedBytes = await preprocessImage(capturedImageBytes);
      final processedStoredBytes = await preprocessImage(storedImageBytes);

      // Calculer plusieurs métriques de similarité
      final pixelSimilarity = await _calculatePixelSimilarity(processedCapturedBytes, processedStoredBytes);
      final histogramSimilarity = await _calculateHistogramSimilarity(processedCapturedBytes, processedStoredBytes);

      // Combiner les métriques (moyenne pondérée)
      final combinedSimilarity = (pixelSimilarity * 0.6) + (histogramSimilarity * 0.4);

      print('Similarité des pixels: $pixelSimilarity');
      print('Similarité des histogrammes: $histogramSimilarity');
      print('Similarité combinée: $combinedSimilarity');
      print('Seuil de similarité actuel: $_similarityThreshold');

      // Retourner le résultat de la comparaison
      final result = combinedSimilarity >= _similarityThreshold;
      print('Résultat de la comparaison faciale: $result');

      return result;
    } catch (e) {
      print('Erreur lors de la comparaison des visages: $e');
      return false;
    }
  }

  // Calculer la similarité des pixels entre deux images
  Future<double> _calculatePixelSimilarity(Uint8List image1Bytes, Uint8List image2Bytes) async {
    try {
      // Décoder les images
      final image1 = img.decodeImage(image1Bytes);
      final image2 = img.decodeImage(image2Bytes);

      if (image1 == null || image2 == null) {
        print('Échec du décodage des images');
        return 0.0;
      }

      // Redimensionner les images à la même taille pour la comparaison
      final size = 128; // Taille standardisée pour la comparaison
      final resizedImage1 = img.copyResize(image1, width: size, height: size);
      final resizedImage2 = img.copyResize(image2, width: size, height: size);

      // Convertir en niveaux de gris pour simplifier la comparaison
      final grayImage1 = img.grayscale(resizedImage1);
      final grayImage2 = img.grayscale(resizedImage2);

      // Calculer la différence pixel par pixel
      int totalPixels = size * size;
      int differentPixels = 0;
      double totalDifference = 0.0;

      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          try {
            // Obtenir la luminosité des pixels (valeur entre 0 et 255)
            final pixel1 = img.getLuminance(grayImage1.getPixel(x, y));
            final pixel2 = img.getLuminance(grayImage2.getPixel(x, y));

            // Calculer la différence entre les pixels
            final diff = (pixel1 - pixel2).abs();
            totalDifference += diff;

            // Si la différence est supérieure à un seuil, considérer comme différent
            if (diff > 40) { // Seuil de différence de pixels
              differentPixels++;
            }
          } catch (e) {
            print('Erreur lors de la comparaison des pixels à ($x, $y): $e');
            differentPixels++;
          }
        }
      }

      // Calculer la similarité (1.0 = identique, 0.0 = complètement différent)
      final pixelSimilarity = 1.0 - (differentPixels / totalPixels);
      final normalizedDifference = totalDifference / (totalPixels * 255);
      final intensitySimilarity = 1.0 - normalizedDifference;

      // Combiner les deux métriques
      final combinedSimilarity = (pixelSimilarity * 0.7) + (intensitySimilarity * 0.3);

      print('Pixels différents: $differentPixels sur $totalPixels');
      print('Similarité des pixels: $pixelSimilarity');
      print('Similarité d\'intensité: $intensitySimilarity');
      print('Similarité combinée des pixels: $combinedSimilarity');

      return combinedSimilarity;
    } catch (e) {
      print('Erreur lors du calcul de la similarité des pixels: $e');
      return 0.0;
    }
  }

  // Calculer la similarité des histogrammes entre deux images
  Future<double> _calculateHistogramSimilarity(Uint8List image1Bytes, Uint8List image2Bytes) async {
    try {
      // Décoder les images
      final image1 = img.decodeImage(image1Bytes);
      final image2 = img.decodeImage(image2Bytes);

      if (image1 == null || image2 == null) {
        print('Échec du décodage des images');
        return 0.0;
      }

      // Redimensionner les images à la même taille
      final size = 128;
      final resizedImage1 = img.copyResize(image1, width: size, height: size);
      final resizedImage2 = img.copyResize(image2, width: size, height: size);

      // Convertir en niveaux de gris
      final grayImage1 = img.grayscale(resizedImage1);
      final grayImage2 = img.grayscale(resizedImage2);

      // Calculer les histogrammes (256 niveaux de gris)
      List<int> histogram1 = List.filled(256, 0);
      List<int> histogram2 = List.filled(256, 0);

      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          try {
            final pixel1 = img.getLuminance(grayImage1.getPixel(x, y)).round();
            final pixel2 = img.getLuminance(grayImage2.getPixel(x, y)).round();

            histogram1[pixel1]++;
            histogram2[pixel2]++;
          } catch (e) {
            print('Erreur lors du calcul des histogrammes à ($x, $y): $e');
          }
        }
      }

      // Normaliser les histogrammes
      final totalPixels = size * size;
      List<double> normalizedHist1 = histogram1.map((count) => count / totalPixels).toList();
      List<double> normalizedHist2 = histogram2.map((count) => count / totalPixels).toList();

      // Calculer la distance entre les histogrammes (distance de Bhattacharyya)
      double sum = 0.0;
      for (int i = 0; i < 256; i++) {
        sum += math.sqrt(normalizedHist1[i] * normalizedHist2[i]);
      }

      // La distance de Bhattacharyya est entre 0 et 1, où 1 signifie identique
      final similarity = sum;

      print('Similarité des histogrammes: $similarity');
      return similarity;
    } catch (e) {
      print('Erreur lors du calcul de la similarité des histogrammes: $e');
      return 0.0;
    }
  }

  // Preprocess image for better face detection
  Future<Uint8List> preprocessImage(Uint8List imageBytes) async {
    try {
      // Décoder l'image
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      // Redimensionner l'image pour réduire la taille
      final resized = img.copyResize(image, width: 640);

      // Convertir en niveaux de gris
      final grayscale = img.grayscale(resized);

      // Améliorer le contraste
      final enhanced = _enhanceContrast(grayscale);

      // Réduire le bruit
      final denoised = _reduceNoise(enhanced);

      // Encoder l'image traitée
      return Uint8List.fromList(img.encodeJpg(denoised, quality: 90));
    } catch (e) {
      print('Erreur lors du prétraitement de l\'image: $e');
      return imageBytes;
    }
  }

  // Améliorer le contraste d'une image
  img.Image _enhanceContrast(img.Image image) {
    try {
      // Trouver les valeurs min et max
      int min = 255;
      int max = 0;

      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final luminance = img.getLuminance(pixel).round();
          if (luminance < min) min = luminance;
          if (luminance > max) max = luminance;
        }
      }

      // Si l'image a déjà un bon contraste, la retourner telle quelle
      if (max - min < 30) {
        return image;
      }

      // Créer une nouvelle image avec un contraste amélioré
      final result = img.Image(width: image.width, height: image.height);

      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final luminance = img.getLuminance(pixel).round();

          // Normaliser la luminance
          final normalized = (luminance - min) * 255 ~/ (max - min);

          // Créer un nouveau pixel avec la luminance normalisée
          final newPixel = img.ColorRgb8(normalized, normalized, normalized);
          result.setPixel(x, y, newPixel);
        }
      }

      return result;
    } catch (e) {
      print('Erreur lors de l\'amélioration du contraste: $e');
      return image;
    }
  }

  // Réduire le bruit d'une image (filtre médian simple)
  img.Image _reduceNoise(img.Image image) {
    try {
      // Créer une nouvelle image pour le résultat
      final result = img.Image(width: image.width, height: image.height);

      // Appliquer un filtre médian 3x3
      for (int y = 1; y < image.height - 1; y++) {
        for (int x = 1; x < image.width - 1; x++) {
          // Collecter les pixels voisins
          List<int> neighbors = [];

          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              final pixel = image.getPixel(x + dx, y + dy);
              final luminance = img.getLuminance(pixel).round();
              neighbors.add(luminance);
            }
          }

          // Trier les valeurs et prendre la médiane
          neighbors.sort();
          final median = neighbors[neighbors.length ~/ 2];

          // Créer un nouveau pixel avec la valeur médiane
          final newPixel = img.ColorRgb8(median, median, median);
          result.setPixel(x, y, newPixel);
        }
      }

      // Copier les bords de l'image originale
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          if (x == 0 || x == image.width - 1 || y == 0 || y == image.height - 1) {
            result.setPixel(x, y, image.getPixel(x, y));
          }
        }
      }

      return result;
    } catch (e) {
      print('Erreur lors de la réduction du bruit: $e');
      return image;
    }
  }

  // Ajouter cette méthode pour définir manuellement le seuil
  void setThreshold(double threshold) {
    _similarityThreshold = threshold;
    _saveSimilarityThreshold();
    print('Seuil de similarité défini manuellement à: $_similarityThreshold');
  }

  // Dispose resources
  void dispose() {
    _faceDetector.close();
  }
}