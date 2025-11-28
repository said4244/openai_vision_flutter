/// Response from Vision API
class VisionResponse {
  final String content;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final Duration processingTime;

  const VisionResponse({
    required this.content,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.processingTime,
  });

  factory VisionResponse.fromJson(Map<String, dynamic> json, Duration processingTime) {
    final usage = json['usage'] ?? {};
    return VisionResponse(
      content: json['choices'][0]['message']['content'],
      promptTokens: usage['prompt_tokens'] ?? 0,
      completionTokens: usage['completion_tokens'] ?? 0,
      totalTokens: usage['total_tokens'] ?? 0,
      processingTime: processingTime,
    );
  }
}