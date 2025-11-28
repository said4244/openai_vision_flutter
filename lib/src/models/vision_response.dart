import '../exceptions/vision_exceptions.dart';

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