import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import '../exceptions/vision_exceptions.dart';

/// Processed image ready for API submission
class ProcessedImage {
  final String dataUri;
  final int originalSize;
  final int processedSize;
  final String format;
  
  const ProcessedImage({
    required this.dataUri,
    required this.originalSize,
    required this.processedSize,
    required this.format,
  });
}

/// Handles image processing and optimization
class ImageProcessor {
  static const int _maxDimension = 1024;
  static const int _jpegQuality = 85;
  
  /// Processes an image for API submission
  static Future<ProcessedImage> processImage(
    dynamic imageInput, {
    bool enableLogging = true,
  }) async {
    try {
      // Get bytes from input
      final imageBytes = await _getImageBytes(imageInput);
      final originalSize = imageBytes.length;
      
      if (enableLogging) {
        print('[ImageProcessor] Original size: ${_formatBytes(originalSize)}');
      }
      
      // Optimize image
      final optimized = await _optimizeImage(imageBytes, enableLogging);
      
      // Detect format
      final format = _detectImageFormat(optimized);
      
      // Create data URI
      final base64String = base64Encode(optimized);
      final dataUri = 'data:image/$format;base64,$base64String';
      
      return ProcessedImage(
        dataUri: dataUri,
        originalSize: originalSize,
        processedSize: optimized.length,
        format: format,
      );
    } catch (e) {
      throw ImageProcessingException('Failed to process image: $e');
    }
  }
  
  /// Gets bytes from various input types
  static Future<Uint8List> _getImageBytes(dynamic input) async {
    if (input is File) {
      return await input.readAsBytes();
    } else if (input is Uint8List) {
      return input;
    } else {
      throw const ImageProcessingException(
        'Image input must be File or Uint8List',
      );
    }
  }
  
  /// Optimizes image size and quality
  static Future<Uint8List> _optimizeImage(
    Uint8List imageBytes,
    bool enableLogging,
  ) async {
    try {
      // Try to decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return imageBytes; // Return original if can't decode
      }
      
      // Check if resizing is needed
      if (image.width <= _maxDimension && image.height <= _maxDimension) {
        return imageBytes; // Already optimal size
      }
      
      // Calculate new dimensions
      final scale = _maxDimension / 
          (image.width > image.height ? image.width : image.height);
      
      final newWidth = (image.width * scale).round();
      final newHeight = (image.height * scale).round();
      
      if (enableLogging) {
        print('[ImageProcessor] Resizing: ${image.width}x${image.height} → ${newWidth}x${newHeight}');
      }
      
      // Resize and encode
      final resized = img.copyResize(image, width: newWidth, height: newHeight);
      final optimized = img.encodeJpg(resized, quality: _jpegQuality);
      
      if (enableLogging) {
        final reduction = ((1 - optimized.length / imageBytes.length) * 100);
        print('[ImageProcessor] Size reduced by ${reduction.toStringAsFixed(1)}%');
      }
      
      return Uint8List.fromList(optimized);
    } catch (e) {
      // Return original if optimization fails
      return imageBytes;
    }
  }
  
  /// Detects image format from bytes
  static String _detectImageFormat(Uint8List bytes) {
    if (bytes.length < 4) return 'jpeg';
    
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && 
        bytes[2] == 0x4E && bytes[3] == 0x47) {
      return 'png';
    }
    
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpeg';
    }
    
    // WebP: RIFF....WEBP
    if (bytes.length > 12 && 
        bytes[0] == 0x52 && bytes[1] == 0x49 && 
        bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && 
        bytes[10] == 0x42 && bytes[11] == 0x50) {
      return 'webp';
    }
    
    return 'jpeg'; // Default
  }
  
  /// Formats bytes to human readable string
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}