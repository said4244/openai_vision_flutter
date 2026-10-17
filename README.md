# OpenAI Vision for Flutter

I built this Flutter package to send an image and a question to OpenAI and display the response in an example app. It brings image preparation, API requests, and typed responses together behind one service.

**Built with:** Flutter, Dart, OpenAI, HTTP, image_picker.

## What it does

- Select an image from the camera or gallery in the example app.
- Resize and compress images before submitting them.
- Return the model response, token usage, and processing time.
- Handle retries and API errors through dedicated exception types.

## Run locally

Install Flutter with a Dart 3 SDK. Copy `example/.env.example` to `example/.env` and set `OPENAI_API_KEY`.

```bash
cd example
flutter pub get
flutter run -d chrome
```

The direct API example is intended for local development with your own key.
For a hosted app, send API requests through a backend that holds the provider key;
Flutter assets and build-time values are visible to the client.

## Project layout

| Path | Purpose |
| --- | --- |
| `lib/src/openai_vision_service.dart` | API client and request handling |
| `lib/src/models/` | Typed request and response models |
| `lib/src/utils/` | Image processing |
| `example/` | Image-selection and analysis demo |

## Main entry point

Import `package:openai_vision_flutter/openai_vision_flutter.dart`, create an
`OpenAIVisionService`, and call `analyzeImage()` with a `VisionRequest`.
The included example shows the full flow.
