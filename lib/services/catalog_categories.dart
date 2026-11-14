import 'package:unorm_dart/unorm_dart.dart' as unicode;

String categoryMatchKey(String value) =>
    unicode.nfc(value).trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Only new input is canonicalized. Existing IDs/links are never merged/renamed.
String? newCatalogCategory(String input, Iterable<String> existing) {
  final value = unicode.nfc(input).trim().replaceAll(RegExp(r'\s+'), ' ');
  if (value.isEmpty ||
      value.length > 60 ||
      value.contains(',') ||
      RegExp(r'[\x00-\x1f]').hasMatch(value)) {
    return null;
  }
  final key = categoryMatchKey(value);
  for (final old in existing) {
    if (categoryMatchKey(old) == key) return old;
  }
  return value;
}
