import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:openai_vision_flutter/openai_vision_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision API Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({Key? key}) : super(key: key);

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  late final OpenAIVisionService _visionService;
  final ImagePicker _picker = ImagePicker();
  
  File? _selectedImage;
  String _result = '';
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    
    // Initialize service with API key from .env
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    
    if (apiKey.isEmpty) {
      setState(() {
        _error = '⚠️ API Key not found! Add OPENAI_API_KEY to .env file';
      });
      return;
    }
    
    _visionService = OpenAIVisionService(
      apiKey: apiKey,
      maxRetries: 3,
      timeout: const Duration(seconds: 30),
    );
  }

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    setState(() {
      _error = '';
      _result = '';
    });

    try {
      // Pick image
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      
      if (image == null) return;
      
      setState(() {
        _selectedImage = File(image.path);
        _isLoading = true;
      });
      // For web, we need to read the image as bytes
      final imageBytes = await image.readAsBytes();

      // Analyze image
      final result = await _visionService.analyzeImage(
        VisionRequest(
          imageInput: imageBytes,
          prompt: 'Which arabic letter is handwritten in this image?',
          maxTokens: 300,
          temperature: 0.7,
        ),
      );

      setState(() {
        _result = result.content;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenAI Vision Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API Status
            if (_error.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _error,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  '✅ API Key loaded successfully',
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Selected Image
            if (_selectedImage != null)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb
                      ? Image.network(
                          _selectedImage!.path,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
              ),
              ),
            
            const SizedBox(height: 20),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _pickAndAnalyzeImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _pickAndAnalyzeImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Loading or Result
            if (_isLoading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Analyzing image...'),
                  ],
                ),
              )
            else if (_result.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analysis Result:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_result),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'How to test:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('1. Make sure you have added your OpenAI API key to .env file'),
                  Text('2. Tap Camera or Gallery button to select an image'),
                  Text('3. The app will automatically analyze the image'),
                  Text('4. Results will appear below'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}