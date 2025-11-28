# OpenAI Vision Flutter

A Flutter package for easy integration with OpenAI's Vision API using GPT-4o-mini.

## Features

- 🚀 **Fast & Efficient**: Optimized for low latency with automatic image compression
- 🔄 **Robust**: Built-in retry logic and comprehensive error handling  
- 📊 **Detailed Logging**: Debug easily with step-by-step logs
- 💰 **Cost-Effective**: Uses GPT-4o-mini for reduced costs
- 🎯 **Type-Safe**: Full Dart type safety with custom models
- 🔒 **Secure**: Supports environment variables for API keys

## Installation

```yaml
dependencies:
  openai_vision_flutter: ^1.0.0


Usage
dartimport 'package:openai_vision_flutter/openai_vision_flutter.dart';

// Initialize the service
final visionService = OpenAIVisionService(
  apiKey: 'your-api-key',
);

// Analyze an image
final response = await visionService.analyzeImage(
  VisionRequest(
    imageInput: imageFile,
    prompt: 'What is in this image?',
  ),
);

print('Analysis: ${response.content}');
print('Tokens used: ${response.totalTokens}');
Configuration
Basic Setup
dartfinal service = OpenAIVisionService(
  apiKey: 'your-api-key',
  maxRetries: 3,
  timeout: Duration(seconds: 30),
);
Advanced Usage
dartfinal response = await service.analyzeImage(
  VisionRequest(
    imageInput: imageBytes, // File or Uint8List
    prompt: 'Describe this image in detail',
    maxTokens: 500,
    temperature: 0.5,
    systemPrompt: 'You are an expert image analyst',
    detail: ImageDetail.low, // low, high, or auto
  ),
);
Error Handling
darttry {
  final response = await service.analyzeImage(request);
  // Handle success
} on InvalidApiKeyException {
  // Handle invalid API key
} on RateLimitException catch (e) {
  // Handle rate limiting
  if (e.retryAfter != null) {
    await Future.delayed(e.retryAfter!);
    // Retry
  }
} on VisionApiException catch (e) {
  // Handle other API errors
  print('API Error: ${e.message} (${e.statusCode})');
} on ImageProcessingException {
  // Handle image processing errors
}
Example
See the example directory for a complete Flutter app demonstrating:

Camera integration
Gallery image selection
Real-time analysis
Error handling
Loading states

API
OpenAIVisionService
The main service class for interacting with OpenAI's Vision API.
Constructor Parameters

apiKey (required): Your OpenAI API key
httpClient: Custom HTTP client (optional)
maxRetries: Maximum retry attempts (default: 3)
timeout: Request timeout (default: 30 seconds)
enableLogging: Enable detailed logging (default: true)

Methods

analyzeImage(VisionRequest request): Analyzes an image and returns a VisionResponse
dispose(): Cleans up resources

Models
VisionRequest

imageInput: File or Uint8List of the image
prompt: Question or instruction about the image
maxTokens: Maximum response tokens (default: 300)
temperature: Creativity level 0-2 (default: 0.7)
systemPrompt: Optional system message
detail: Image detail level (low/high/auto)

VisionResponse

content: The AI's response text
promptTokens: Input tokens used
completionTokens: Output tokens generated
totalTokens: Total tokens consumed
processingTime: Request duration

Performance Tips

Image Optimization: Images are automatically resized to 1024px max dimension
Use Low Detail: Set detail: ImageDetail.low for faster processing
Cache Responses: Consider caching for repeated queries
Batch Processing: Process multiple images sequentially to avoid rate limits

Cost Optimization

GPT-4o-mini: $0.15 per 1M input tokens, $0.60 per 1M output tokens
Using "low" detail significantly reduces token usage
Automatic image compression reduces costs

Contributing
Contributions are welcome! Please read our contributing guidelines first.
License
MIT License - see the LICENSE file for details.