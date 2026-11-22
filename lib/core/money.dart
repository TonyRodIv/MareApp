import 'package:intl/intl.dart';

/// Dinheiro sempre em centavos inteiros: evita os erros de ponto flutuante
/// do app original (0.1 + 0.2 != 0.3).
typedef Cents = int;

final _full = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: 2,
);
final _num = NumberFormat.decimalPattern('pt_BR')
  ..minimumFractionDigits = 2
  ..maximumFractionDigits = 2;
final _compact = NumberFormat.decimalPattern('pt_BR')
  ..maximumFractionDigits = 0;

String fmtMoney(Cents c, {bool hidden = false}) {
  if (hidden) return 'R\$ •••••';
  return _full.format(c / 100).replaceAll(' ', ' ');
}

/// Só o número, sem símbolo (o símbolo vai menor, como no Figma).
String fmtNumber(Cents c, {bool hidden = false}) {
  if (hidden) return '•••••';
  return _num.format(c / 100);
}

String fmtCompact(Cents c) => _compact.format(c / 100);

/// "12,50" / "12.5" / "1.234,56" → centavos. Retorna null se inválido.
Cents? parseMoney(String raw) {
  var s = raw.trim().replaceAll('R\$', '').replaceAll(RegExp(r'\s+'), '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  }
  final v = double.tryParse(s);
  if (v == null || !v.isFinite) return null;
  return (v * 100).round();
}

/// Converte valores float do app antigo (reais) para centavos.
Cents centsFromLegacy(dynamic v) {
  final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  if (!n.isFinite) return 0;
  return (n * 100).round();
}
