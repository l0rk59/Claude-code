import 'package:get/get.dart';

/// A decimal number as the app's language writes it: "86.1" in English,
/// "86,1" in French.
String decimal(num value, [int digits = 1]) {
  final text = value.toStringAsFixed(digits);
  return Get.locale?.languageCode == 'fr' ? text.replaceFirst('.', ',') : text;
}
