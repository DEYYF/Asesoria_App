import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/ingrediente_model.dart';

class OCRService {
  late TextRecognizer _textRecognizer;

  OCRService() {
    if (kIsWeb) {
      throw Exception(
        'OCR no es compatible con la Web. Por favor, usa un dispositivo físico o emulador (Android/iOS).',
      );
    }
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  Future<Ingrediente?> extractNutritionalData(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(
      inputImage,
    );

    print('--- OCR Recognized Text Begin ---');
    print(recognizedText.text);
    print('--- OCR Recognized Text End ---');

    String fullText = recognizedText.text.toLowerCase();

    double kcal = _extractValue(fullText, [
      r'kcal',
      r'energía',
      r'energy',
      r'valor energético',
    ]);
    double proteinas = _extractValue(fullText, [
      r'proteínas',
      r'proteins',
      r'proteina',
    ]);
    double carbohidratos = _extractValue(fullText, [
      r'carbohidratos',
      r'carbohydrates',
      r'hidratos de carbono',
      r'carbono',
    ]);
    double grasas = _extractValue(fullText, [
      r'grasas',
      r'fats',
      r'grasa',
      r'fat',
      r'lípidos',
    ]);

    print(
      'Extracted Values: Kcal: $kcal, Prot: $proteinas, Carb: $carbohidratos, Grasa: $grasas',
    );

    return Ingrediente(
      id: '',
      nombre: '', // User will put manually
      kcal: kcal,
      proteinas: proteinas,
      carbohidratos: carbohidratos,
      grasas: grasas,
      tipo: null, // User will put manually
    );
  }

  double _extractValue(String text, List<String> keywords) {
    for (String keyword in keywords) {
      final regExp = RegExp(
        '$keyword[:\\s]*(\\d+[.,]?\\d*)',
        caseSensitive: false,
      );
      final match = regExp.firstMatch(text);
      if (match != null) {
        print('Match found for keyword "$keyword": ${match.group(0)}');
        String? valueStr = match.group(1)?.replaceAll(',', '.');
        if (valueStr != null) {
          return double.tryParse(valueStr) ?? 0;
        }
      }
    }
    return 0;
  }

  void dispose() {
    if (!kIsWeb) {
      _textRecognizer.close();
    }
  }
}
