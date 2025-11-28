// lib/src/openai_vision_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'models/vision_request.dart';
import 'models/vision_response.dart';
import 'exceptions/vision_exceptions.dart';
import 'utils/image_processor.dart';

/// Service for interacting with OpenAI's Vision API
class OpenAIVisionService {
  static const String _apiEndpoint = 'https://api.openai.com/v1/chat/completions';
  static const String _defaultModel = 'gpt-4o-mini';
  
  final String apiKey;
  final http.Client? httpClient;
  final int maxRetries;
  final Duration timeout;
  final bool enableLogging;
  final String model;
  
  http.Client? _internalClient;
  
  /// Creates a new instance of the OpenAI Vision Service
  /// 
  /// [apiKey] is required and can be obtained from OpenAI's platform
  /// [httpClient] allows you to provide a custom HTTP client
  /// [maxRetries] sets the number of retry attempts for failed requests
  /// [timeout] sets the maximum duration for API requests
  /// [enableLogging] enables detailed logging for debugging
  /// [model] allows you to specify a different model (default: gpt-4o-mini)
  OpenAIVisionService({
    required this.apiKey,
    this.httpClient,
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 30),
    this.enableLogging = true,
    this.model = _defaultModel,
  }) {
    if (apiKey.isEmpty) {
      throw const InvalidApiKeyException('API key cannot be empty');
    }
  }

  /// Analyzes an image using OpenAI's Vision API
  Future<VisionResponse> analyzeImage(VisionRequest request) async {
    final startTime = DateTime.now();
    _log('Starting image analysis');

    try {
      // Validate the request
      _validateRequest(request);
      
      // Process image
      final processedImage = await ImageProcessor.processImage(
        request.imageInput,
        enableLogging: enableLogging,
      );
      
      // Build API request
      final requestBody = _buildRequestBody(
        processedImage: processedImage,
        request: request,
      );
      
      // Make API call
      final response = await _makeApiCall(requestBody);
      
      // Process response
      final result = _parseResponse(response, startTime);
      
      _log('Analysis completed successfully in ${result.processingTime.inMilliseconds}ms');
      
      return result;
    } catch (e) {
      if (e is VisionException) rethrow;
      throw VisionApiException(message: 'Unexpected error: $e');
    }
  }

  /// Validates the request parameters
  void _validateRequest(VisionRequest request) {
    if (request.prompt.isEmpty) {
      throw const VisionApiException(message: 'Prompt cannot be empty');
    }
    
    if (request.maxTokens < 1 || request.maxTokens > 4096) {
      throw const VisionApiException(
        message: 'maxTokens must be between 1 and 4096',
      );
    }
    
    if (request.temperature < 0 || request.temperature > 2) {
      throw const VisionApiException(
        message: 'temperature must be between 0 and 2',
      );
    }
  }

  /// Builds the request body for the API
  Map<String, dynamic> _buildRequestBody({
    required ProcessedImage processedImage,
    required VisionRequest request,
  }) {
    final messages = <Map<String, dynamic>>[];
    
    // Add system message if provided
    if (request.systemPrompt != null && request.systemPrompt!.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': request.systemPrompt,
      });
    }
    
    // Add user message with image
    messages.add({
      'role': 'user',
      'content': [
        {
          'type': 'text',
          'text': request.prompt,
        },
        {
          'type': 'image_url',
          'image_url': {
            'url': processedImage.dataUri,
            'detail': request.detail.name,
          },
        },
      ],
    });
    
    return {
      'model': model,
      'messages': messages,
      'max_tokens': request.maxTokens,
      'temperature': request.temperature,
    };
  }

  /// Makes the API call with retry logic
  Future<http.Response> _makeApiCall(Map<String, dynamic> requestBody) async {
    final client = httpClient ?? (_internalClient ??= http.Client());
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          final delay = Duration(seconds: attempt * 2);
          _log('Retrying API call (attempt ${attempt + 1}/$maxRetries)');
          await Future.delayed(delay);
        }
        
        final response = await client
            .post(
              Uri.parse(_apiEndpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode(requestBody),
            )
            .timeout(timeout);
        
        _log('API response received: ${response.statusCode}');
        
        // Success
        if (response.statusCode == 200) {
          return response;
        }
        
        // Handle specific error cases
        if (response.statusCode == 401) {
          throw const InvalidApiKeyException();
        }
        
        if (response.statusCode == 429) {
          final retryAfter = response.headers['retry-after'];
          if (retryAfter != null && attempt < maxRetries - 1) {
            final seconds = int.tryParse(retryAfter) ?? 5;
            _log('Rate limited, waiting ${seconds}s');
            
            throw RateLimitException(
              message: 'Rate limit exceeded',
              retryAfter: Duration(seconds: seconds),
              statusCode: 429,
            );
          }
        }
        
        // Other errors
        final errorBody = _tryParseErrorBody(response.body);
        throw VisionApiException(
          message: errorBody ?? 'API request failed',
          statusCode: response.statusCode,
        );
        
      } on TimeoutException {
        if (attempt == maxRetries - 1) {
          throw VisionApiException(
            message: 'Request timed out after ${timeout.inSeconds}s',
          );
        }
      } on RateLimitException catch (e) {
        if (attempt < maxRetries - 1 && e.retryAfter != null) {
          await Future.delayed(e.retryAfter!);
          continue;
        }
        rethrow;
      } catch (e) {
        if (attempt == maxRetries - 1 || e is VisionException) {
          rethrow;
        }
      }
    }
    
    throw VisionApiException(
      message: 'Failed after $maxRetries attempts',
    );
  }

  /// Parses the API response
  VisionResponse _parseResponse(http.Response response, DateTime startTime) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final processingTime = DateTime.now().difference(startTime);
      
      return VisionResponse.fromJson(data, processingTime);
    } catch (e) {
      throw VisionApiException(
        message: 'Failed to parse response: $e',
      );
    }
  }

  /// Tries to parse error message from response body
  String? _tryParseErrorBody(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (data['error'] != null) {
        return data['error']['message']?.toString();
      }
      return data['message']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Logging helper
  void _log(String message) {
    if (enableLogging) {
      print('[OpenAIVision] $message');
    }
  }

  /// Disposes of resources
  void dispose() {
    _internalClient?.close();
  }
}

// lib/src/models/vision_request.dart

/// Configuration for Vision API requests
class VisionRequest {
  /// The image to analyze (File or Uint8List)
  final dynamic imageInput;
  
  /// The question or instruction about the image
  final String prompt;
  
  /// Maximum tokens in the response
  final int maxTokens;
  
  /// Controls randomness (0-2)
  final double temperature;
  
  /// Optional system message for context
  final String? systemPrompt;
  
  /// Image detail level
  final ImageDetail detail;

  const VisionRequest({
    required this.imageInput,
    required this.prompt,
    this.maxTokens = 300,
    this.temperature = 0.7,
    this.systemPrompt,
    this.detail = ImageDetail.low,
  });
}

/// Image detail level for API requests
enum ImageDetail { 
  /// Low detail - faster and cheaper
  low, 
  /// High detail - more accurate but slower
  high, 
  /// Auto - let API decide
  auto 
}

// lib/src/models/vision_response.dart

/// Response from Vision API
class VisionResponse {
  /// The AI's response text
  final String content;
  
  /// Number of input tokens used
  final int promptTokens;
  
  /// Number of output tokens generated
  final int completionTokens;
  
  /// Total tokens consumed
  final int totalTokens;
  
  /// Time taken to process the request
  final Duration processingTime;

  const VisionResponse({
    required this.content,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.processingTime,
  });

  /// Creates a VisionResponse from API JSON
  factory VisionResponse.fromJson(Map<String, dynamic> json, Duration processingTime) {
    final usage = json['usage'] as Map<String, dynamic>? ?? {};
    final choices = json['choices'] as List? ?? [];
    
    if (choices.isEmpty) {
      throw const VisionApiException(message: 'No choices in response');
    }
    
    final message = choices[0]['message'] as Map<String, dynamic>?;
    final content = message?['content']?.toString() ?? '';
    
    return VisionResponse(
      content: content.trim(),
      promptTokens: usage['prompt_tokens'] as int? ?? 0,
      completionTokens: usage['completion_tokens'] as int? ?? 0,
      totalTokens: usage['total_tokens'] as int? ?? 0,
      processingTime: processingTime,
    );
  }
  
  /// Estimated cost in USD
  double get estimatedCost {
    // GPT-4o-mini pricing: $0.15/1M input, $0.60/1M output
    const inputCostPerMillion = 0.15;
    const outputCostPerMillion = 0.60;
    
    final inputCost = (promptTokens / 1000000) * inputCostPerMillion;
    final outputCost = (completionTokens / 1000000) * outputCostPerMillion;
    
    return inputCost + outputCost;
  }
}

// lib/src/utils/image_processor.dart

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