// This file provides stub implementations for packages that don't work on web

// Stub for dart:io File
class File {
  final String path;

  File(this.path);

  Future<List<int>> readAsBytes() async {
    return [];
  }
}

// Stub for GoogleMlKit
class GoogleMlKit {
  static final Vision vision = Vision();
}

class Vision {
  FaceDetector faceDetector(FaceDetectorOptions options) {
    return FaceDetector();
  }
}

class FaceDetector {
  Future<List<dynamic>> processImage(dynamic inputImage) async {
    return [{'simulated': true}];
  }

  void close() {}
}

class FaceDetectorOptions {
  final bool enableContours;
  final bool enableClassification;
  final bool enableLandmarks;
  final FaceDetectorMode performanceMode;

  FaceDetectorOptions({
    this.enableContours = false,
    this.enableClassification = false,
    this.enableLandmarks = false,
    this.performanceMode = FaceDetectorMode.fast,
  });
}

enum FaceDetectorMode { fast, accurate }

class InputImage {
  static InputImage fromFilePath(String path) {
    return InputImage();
  }

  static InputImage fromBytes({
    required List<int> bytes,
    required InputImageMetadata metadata,
  }) {
    return InputImage();
  }
}

class InputImageMetadata {
  final Size size;
  final InputImageRotation rotation;
  final InputImageFormat format;
  final int bytesPerRow;

  InputImageMetadata({
    required this.size,
    required this.rotation,
    required this.format,
    required this.bytesPerRow,
  });
}

class Size {
  final double width;
  final double height;

  const Size(this.width, this.height);
}

enum InputImageRotation { rotation0deg, rotation90deg, rotation180deg, rotation270deg }

enum InputImageFormat { bgra8888, nv21, yuv420, yuv_420_888, yuv_422_888, yuv_444_888 }

// Stub for image package
class img {
  static dynamic decodeImage(List<int> bytes) {
    return {};
  }

  static dynamic copyResize(dynamic image, {required int width}) {
    return image;
  }

  static dynamic grayscale(dynamic image) {
    return image;
  }

  static List<int> encodeJpg(dynamic image, {required int quality}) {
    return [];
  }
}
