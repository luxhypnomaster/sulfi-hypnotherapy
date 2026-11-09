import 'package:unorm_dart/unorm_dart.dart' as unicode;

const _russian = {
  'а': 'a',
  'б': 'b',
  'в': 'v',
  'г': 'g',
  'д': 'd',
  'е': 'e',
  'ё': 'yo',
  'ж': 'zh',
  'з': 'z',
  'и': 'i',
  'й': 'y',
  'к': 'k',
  'л': 'l',
  'м': 'm',
  'н': 'n',
  'о': 'o',
  'п': 'p',
  'р': 'r',
  'с': 's',
  'т': 't',
  'у': 'u',
  'ф': 'f',
  'х': 'kh',
  'ц': 'ts',
  'ч': 'ch',
  'ш': 'sh',
  'щ': 'shch',
  'ъ': '',
  'ы': 'y',
  'ь': '',
  'э': 'e',
  'ю': 'yu',
  'я': 'ya',
};

String exportFileName({required DateTime localDate, String? title}) {
  final date =
      '${localDate.day.toString().padLeft(2, '0')}.${localDate.month.toString().padLeft(2, '0')}.${(localDate.year % 100).toString().padLeft(2, '0')}';
  if (title == null) return 'Sulfi_backup_$date.zip';
  final original = unicode
      .nfc(title)
      .replaceFirst(RegExp(r'(\.zip)+$', caseSensitive: false), '');
  final translated = StringBuffer();
  for (final rune in original.runes) {
    final char = String.fromCharCode(rune), lower = char.toLowerCase();
    var value = _russian[lower];
    if (value == null) {
      translated.write(char);
      continue;
    }
    if (char != lower && value.isNotEmpty) {
      value = value[0].toUpperCase() + value.substring(1);
    }
    translated.write(value);
  }
  var slug = unicode
      .nfkd(translated.toString())
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (slug.length > 80) {
    slug = slug.substring(0, 80).replaceAll(RegExp(r'_+$'), '');
  }
  if (slug.isEmpty) slug = 'Untitled';
  return 'Sulfi_exp_${slug}_$date.zip';
}
