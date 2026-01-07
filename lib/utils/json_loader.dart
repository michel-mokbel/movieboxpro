import 'dart:convert';
import 'package:flutter/services.dart';

class JsonLoader {
  static Future<List<String>> loadIds(String fileName) async {
    final String response = await rootBundle.loadString('lib/assets/json/$fileName');
    final List<dynamic> data = jsonDecode(response);
    return data.cast<String>();
  }
}
