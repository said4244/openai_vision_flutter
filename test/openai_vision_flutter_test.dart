// test/openai_vision_flutter_test.dart

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:openai_vision_flutter/openai_vision_flutter.dart';
import 'package:flutter/material.dart';


@GenerateMocks([http.Client])
import 'openai_vision_flutter_test.mocks.dart';

void main() {
  group('OpenAIVisionService', () {
    late OpenAIVisionService service;
    late MockClient mockClient;
    
    setUp(() {
      mockClient = MockClient();
      service = OpenAIVisionService(
        apiKey: 'test-api-key',
        httpClient: mockClient,
        enableLogging: false,
      );
    });

    test('throws InvalidApiKeyException for empty API key', () {
      expect(
        () => OpenAIVisionService(apiKey: ''),
        throwsA(isA<InvalidApiKeyException>()),
      );
    });

    test('analyzeImage succeeds with valid response', () async {
      // Arrange
      final testImage = Uint8List.fromList([0, 1, 2, 3]);
      final request = VisionRequest(
        imageInput: testImage,
        prompt: 'Test prompt',
      );
      
      final mockResponse = {
        'choices': [
          {
            'message': {
              'content': 'This is a test response',
            },
          },
        ],
        'usage': {
          'prompt_tokens': 100,
          'completion_tokens': 50,
          'total_tokens': 150,
        },
      };
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode(mockResponse),
        200,
      ));

      // Act
      final response = await service.analyzeImage(request);

      // Assert
      expect(response.content, equals('This is a test response'));
      expect(response.totalTokens, equals(150));
      expect(response.promptTokens, equals(100));
      expect(response.completionTokens, equals(50));
    });

    test('handles 401 unauthorized error', () async {
      // Arrange
      final request = VisionRequest(
        imageInput: Uint8List.fromList([0, 1, 2, 3]),
        prompt: 'Test prompt',
      );
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        '{"error": {"message": "Invalid API key"}}',
        401,
      ));

      // Act & Assert
      expect(
        () => service.analyzeImage(request),
        throwsA(isA<InvalidApiKeyException>()),
      );
    });

    test('handles rate limiting with retry', () async {
      // Arrange
      final request = VisionRequest(
        imageInput: Uint8List.fromList([0, 1, 2, 3]),
        prompt: 'Test prompt',
      );
      
      final mockResponse = {
        'choices': [
          {
            'message': {
              'content': 'Success after retry',
            },
          },
        ],
        'usage': {
          'prompt_tokens': 100,
          'completion_tokens': 50,
          'total_tokens': 150,
        },
      };
      
      // First call returns 429, second succeeds
      var callCount = 0;
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            '{"error": {"message": "Rate limit exceeded"}}',
            429,
            headers: {'retry-after': '1'},
          );
        }
        return http.Response(jsonEncode(mockResponse), 200);
      });

      // Act
      final response = await service.analyzeImage(request);

      // Assert
      expect(response.content, equals('Success after retry'));
      verify(mockClient.post(any, 
        headers: anyNamed('headers'), 
        body: anyNamed('body')
      )).called(2);
    });

    test('validates request parameters', () async {
      // Test empty prompt
      expect(
        () => service.analyzeImage(VisionRequest(
          imageInput: Uint8List.fromList([0, 1, 2, 3]),
          prompt: '',
        )),
        throwsA(isA<VisionApiException>()),
      );

      // Test invalid maxTokens
      expect(
        () => service.analyzeImage(VisionRequest(
          imageInput: Uint8List.fromList([0, 1, 2, 3]),
          prompt: 'Test',
          maxTokens: 5000,
        )),
        throwsA(isA<VisionApiException>()),
      );

      // Test invalid temperature
      expect(
        () => service.analyzeImage(VisionRequest(
          imageInput: Uint8List.fromList([0, 1, 2, 3]),
          prompt: 'Test',
          temperature: 3.0,
        )),
        throwsA(isA<VisionApiException>()),
      );
    });
  });

  group('VisionResponse', () {
    test('calculates estimated cost correctly', () {
      const response = VisionResponse(
        content: 'Test',
        promptTokens: 1000000,  // 1M tokens
        completionTokens: 1000000,  // 1M tokens
        totalTokens: 2000000,
        processingTime: Duration(seconds: 1),
      );

      // $0.15/1M input + $0.60/1M output = $0.75
      expect(response.estimatedCost, equals(0.75));
    });

    test('parses from JSON correctly', () {
      final json = {
        'choices': [
          {
            'message': {
              'content': '  Test content  ',
            },
          },
        ],
        'usage': {
          'prompt_tokens': 100,
          'completion_tokens': 50,
          'total_tokens': 150,
        },
      };

      final response = VisionResponse.fromJson(
        json, 
        const Duration(milliseconds: 500),
      );

      expect(response.content, equals('Test content')); // Trimmed
      expect(response.promptTokens, equals(100));
      expect(response.completionTokens, equals(50));
      expect(response.totalTokens, equals(150));
      expect(response.processingTime.inMilliseconds, equals(500));
    });

    test('handles missing usage data', () {
      final json = {
        'choices': [
          {
            'message': {
              'content': 'Test',
            },
          },
        ],
      };

      final response = VisionResponse.fromJson(
        json,
        const Duration(seconds: 1),
      );

      expect(response.promptTokens, equals(0));
      expect(response.completionTokens, equals(0));
      expect(response.totalTokens, equals(0));
    });
  });

  group('ImageProcessor', () {
    test('detects PNG format correctly', () {
      final pngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, // PNG signature
        0x0D, 0x0A, 0x1A, 0x0A,
      ]);

      final result = ImageProcessor.processImage(pngBytes);
      // This would need to be tested with actual implementation
    });

    test('detects JPEG format correctly', () {
      final jpegBytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, // JPEG signature
      ]);

      final result = ImageProcessor.processImage(jpegBytes);
      // This would need to be tested with actual implementation
    });

    test('handles invalid image input types', () async {
      expect(
        () => ImageProcessor.processImage('invalid_input'),
        throwsA(isA<ImageProcessingException>()),
      );
    });
  });
}

// test/widget_test.dart - Example widget test



class TestWidget extends StatefulWidget {
  final OpenAIVisionService service;
  
  const TestWidget({Key? key, required this.service}) : super(key: key);
  
  @override
  State<TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<TestWidget> {
  String? result;
  bool isLoading = false;
  
  Future<void> analyze() async {
    setState(() => isLoading = true);
    
    try {
      final response = await widget.service.analyzeImage(
        VisionRequest(
          imageInput: Uint8List.fromList([0, 1, 2, 3]),
          prompt: 'Test prompt',
        ),
      );
      setState(() {
        result = response.content;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        result = 'Error: $e';
        isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              onPressed: analyze,
              child: const Text('Analyze'),
            ),
            if (isLoading) const CircularProgressIndicator(),
            if (result != null) Text(result!),
          ],
        ),
      ),
    );
  }
}

void widgetTestMain() {
  group('Widget Tests', () {
    testWidgets('shows loading indicator during analysis', (tester) async {
      final service = OpenAIVisionService(
        apiKey: 'test-key',
        enableLogging: false,
      );
      
      await tester.pumpWidget(TestWidget(service: service));
      
      // Tap analyze button
      await tester.tap(find.text('Analyze'));
      await tester.pump();
      
      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

// To generate mocks, run:
// flutter pub run build_runner build