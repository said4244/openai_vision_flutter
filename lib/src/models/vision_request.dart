import '../utils/image_processor.dart';

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

  /// Builds the API request body
  Map<String, dynamic> toRequestBody({
    required ProcessedImage processedImage,
    required String model,
  }) {
    final messages = <Map<String, dynamic>>[];
    
    // Add system message if provided
    if (systemPrompt != null && systemPrompt!.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': systemPrompt,
      });
    }
    
    // Add user message with image
    messages.add({
      'role': 'user',
      'content': [
        {
          'type': 'text',
          'text': prompt,
        },
        {
          'type': 'image_url',
          'image_url': {
            'url': processedImage.dataUri,
            'detail': detail.name,
          },
        },
      ],
    });
    
    return {
      'model': model,
      'messages': messages,
      'max_tokens': maxTokens,
      'temperature': temperature,
    };
  }
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