import 'package:audioplayers/audioplayers.dart';

class AudioService {
  // Singleton pattern
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Play success sound
  Future<void> playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));
    } catch (e) {
      print('Erreur lors de la lecture du son de succès: $e');
      // Fallback to a simple beep if the sound file is not available
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
    }
  }

  // Play failure sound
  Future<void> playFailureSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/failure.mp3'));
    } catch (e) {
      print('Erreur lors de la lecture du son d\'échec: $e');
      // Fallback to a simple beep if the sound file is not available
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
    }
  }

  // Dispose resources
  void dispose() {
    _audioPlayer.dispose();
  }
}
