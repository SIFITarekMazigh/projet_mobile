import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:projet_mobile/services/platform_service.dart';
import 'package:projet_mobile/services/supabase_auth_service.dart';
import 'package:http/http.dart' as http;

// Conditionally import packages based on platform
import 'dart:io' if (dart.library.html) 'package:projet_mobile/services/web_stub.dart';
import 'package:google_ml_kit/google_ml_kit.dart' if (dart.library.html) 'package:projet_mobile/services/web_stub.dart';
import 'package:image/image.dart' as img if (dart.library.html) 'package:projet_mobile/services/web_stub.dart';

class FaceRecognitionService {
// Singleton pattern
static final FaceRecognitionService _instance = FaceRecognitionService._internal();
factory FaceRecognitionService() => _instance;

final _platformService = PlatformService();
final _authService = SupabaseAuthService();

// Face detector is only initialized on mobile platforms
dynamic _faceDetector;

FaceRecognitionService._internal() {
if (!kIsWeb) {
// Only initialize ML Kit on mobile platforms
try {
_faceDetector = GoogleMlKit.vision.faceDetector(
FaceDetectorOptions(
enableContours: true,
enableClassification: true,
enableLandmarks: true,
performanceMode: FaceDetectorMode.accurate,
),
);
} catch (e) {
print('Erreur lors de l\'initialisation du détecteur de visage: $e');
}
}
}

// Detect faces in an image
Future<List<dynamic>> detectFaces(dynamic inputImage) async {
if (kIsWeb) {
// On web, we simulate face detection
print('Simulation de détection faciale sur le web');
// Return a simulated face detection result (always detect one face)
return [{'simulated': true}];
} else {
try {
// On mobile, use actual ML Kit face detection
return await _faceDetector.processImage(inputImage);
} catch (e) {
print('Error detecting faces: $e');
return [];
}
}
}

// Compare faces for authentication
Future<bool> compareFaces(Uint8List capturedImageBytes, String userId) async {
if (kIsWeb) {
// On web, we simulate face comparison (always return true for demo)
print('Simulation de comparaison faciale sur le web');
return true;
} else {
try {
// Get the stored face image URL
final storedImageUrl = await _authService.getFaceImageUrl(userId);
if (storedImageUrl == null) {
print('Aucune image de visage stockée trouvée');
return false;
}

// Download the stored image
final response = await http.get(Uri.parse(storedImageUrl));
if (response.statusCode != 200) {
print('Échec du téléchargement de l\'image stockée: ${response.statusCode}');
return false;
}
final storedImageBytes = response.bodyBytes;

// Process both images
final capturedFaces = await _processImageBytes(capturedImageBytes);
final storedFaces = await _processImageBytes(storedImageBytes);

// If no faces detected in either image, return false
if (capturedFaces.isEmpty || storedFaces.isEmpty) {
print('Aucun visage détecté dans une ou les deux images');
return false;
}

// Pour cette démonstration, nous considérons qu'un visage détecté dans les deux images est suffisant
print('Visages détectés dans les deux images');
return true;
} catch (e) {
print('Erreur lors de la comparaison des visages: $e');
return false;
}
}
}

Future<List<dynamic>> _processImageBytes(Uint8List bytes) async {
if (kIsWeb) {
// Simulate processing on web
return [{'simulated': true}];
} else {
final inputImage = InputImage.fromBytes(
bytes: bytes,
metadata: InputImageMetadata(
size: const Size(1080, 1920),
rotation: InputImageRotation.rotation0deg,
format: InputImageFormat.bgra8888,
bytesPerRow: 1080 * 4,
),
);
return await detectFaces(inputImage);
}
}

// Preprocess image for better face detection
Future<Uint8List> preprocessImage(Uint8List imageBytes) async {
if (kIsWeb) {
// On web, just return the original bytes
return imageBytes;
} else {
// On mobile, process the image
final image = img.decodeImage(imageBytes);
if (image == null) return imageBytes;

final resized = img.copyResize(image, width: 640);
final grayscale = img.grayscale(resized);
return Uint8List.fromList(img.encodeJpg(grayscale, quality: 90));
}
}

// Dispose resources
void dispose() {
if (!kIsWeb && _faceDetector != null) {
_faceDetector.close();
}
}
}
