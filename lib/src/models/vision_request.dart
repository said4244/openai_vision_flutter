/// Configuration for Vision API requests
class VisionRequest {
  final dynamic imageInput;
  final String prompt;
  final int maxTokens;
  final double temperature;
  final String? systemPrompt;
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

enum ImageDetail { low, high, auto }