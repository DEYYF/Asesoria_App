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

          return Ingrediente(
            id: '', // New ingredient
            nombre: product['product_name'] ?? 'Producto desconocido',
            kcal: (nutriments['energy-kcal_100g'] as num?)?.toDouble() ?? 0,
            proteinas: (nutriments['proteins_100g'] as num?)?.toDouble() ?? 0,
            carbohidratos:
                (nutriments['carbohydrates_100g'] as num?)?.toDouble() ?? 0,
            grasas: (nutriments['fat_100g'] as num?)?.toDouble() ?? 0,
            tipo: null, // To be filled manually
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
