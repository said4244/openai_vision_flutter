/// Base exception for OpenAI Vision operations
abstract class VisionException implements Exception {
  final String message;
  const VisionException(this.message);
  
  @override
  String toString() => message;
}

/// Thrown when API key is missing or invalid
class InvalidApiKeyException extends VisionException {
  const InvalidApiKeyException([String message = 'Invalid or missing API key']) 
    : super(message);
}

/// Thrown when API request fails
class VisionApiException extends VisionException {
  final int? statusCode;
  final String? errorCode;
  
  const VisionApiException({
    required String message,
    this.statusCode,
    this.errorCode,
  }) : super(message);
}

/// Thrown when image processing fails
class ImageProcessingException extends VisionException {
  const ImageProcessingException([String message = 'Failed to process image']) 
    : super(message);
}

/// Thrown when rate limit is exceeded
class RateLimitException extends VisionApiException {
  final Duration? retryAfter;
  
  const RateLimitException({
    required String message,
    this.retryAfter,
    int? statusCode,
  }) : super(message: message, statusCode: statusCode);
}