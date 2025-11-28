// lib/src/openai_vision_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/vision_request.dart';
import 'models/vision_response.dart';
import 'exceptions/vision_exceptions.dart';
import 'utils/image_processor.dart';

export 'models/vision_request.dart';
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
      
      // Build API request - now using the method from VisionRequest
      final requestBody = request.toRequestBody(
        processedImage: processedImage,
        model: model,
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
