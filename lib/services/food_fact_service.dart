import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ingrediente_model.dart';

class FoodFactService {
  static const String _baseUrl =
      'https://world.openfoodfacts.org/api/v2/product';

  Future<Ingrediente?> fetchProductByBarcode(String barcode) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/$barcode.json'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1) {
          final product = data['product'];
          final nutriments = product['nutriments'] ?? {};

          // Open Food Facts can have kcal in multiple keys
          double kcal =
              (nutriments['energy-kcal_100g'] as num?)?.toDouble() ??
              (nutriments['energy-kcal_serving'] as num?)?.toDouble() ??
              0;

          // Fallback to energy-kj if kcal is missing (1 kcal = 4.184 kj)
          if (kcal == 0) {
            double kj = (nutriments['energy-kj_100g'] as num?)?.toDouble() ?? 0;
            if (kj > 0) kcal = kj / 4.184;
          }

          return Ingrediente(
            id: '', // New ingredient
            nombre:
                product['product_name'] ??
                product['product_name_es'] ??
                product['product_name_en'] ??
                'Producto desconocido',
            kcal: kcal,
            proteinas: (nutriments['proteins_100g'] as num?)?.toDouble() ?? 0,
            carbohidratos:
                (nutriments['carbohydrates_100g'] as num?)?.toDouble() ?? 0,
            grasas: (nutriments['fat_100g'] as num?)?.toDouble() ?? 0,
            tipo:
                product['categories']?.toString().split(',').first ??
                'Escaneado',
          );
        }
      }
      return null;
    } catch (e) {
      print('Error fetching from OpenFoodFacts: $e');
      return null;
    }
  }
}
