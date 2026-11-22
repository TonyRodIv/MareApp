import 'package:intl/intl.dart';

/// Um ciclo financeiro: começa no dia de virada escolhido pelo usuário e vai
/// até a véspera da próxima virada.
///
/// Correção em relação ao original: lá o dia era limitado a 28. Aqui aceitamos
/// 1–31 e, em meses curtos, a virada cai no último dia do mês.
class Cycle {
  final DateTime start; // inclusivo, 00:00
  final DateTime end; // exclusivo
  final int key; // year * 12 + month0 do mês de referência

  const Cycle._(this.start, this.end, this.key);

  static int _daysIn(int y, int m) => DateTime(y, m + 1, 0).day;

  static DateTime _boundary(int y, int m, int startDay) {
    // normaliza m fora de 1..12
    final norm = DateTime(y, m, 1);
    final d = startDay.clamp(1, _daysIn(norm.year, norm.month));
    return DateTime(norm.year, norm.month, d);
  }

  factory Cycle.of(DateTime date, int startDay) {
    final day = DateTime(date.year, date.month, date.day);
    var s = _boundary(day.year, day.month, startDay);
    if (day.isBefore(s)) s = _boundary(day.year, day.month - 1, startDay);
    final e = _boundary(s.year, s.month + 1, startDay);
    return Cycle._(s, e, s.year * 12 + (s.month - 1));
  }

  factory Cycle.fromKey(int key, int startDay) {
    final y = key ~/ 12;
    final m = key % 12 + 1;
    return Cycle.of(_boundary(y, m, startDay), startDay);
  }

  Cycle next(int startDay) => Cycle.fromKey(key + 1, startDay);
  Cycle prev(int startDay) => Cycle.fromKey(key - 1, startDay);

  int get lengthInDays => days.length;

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  List<DateTime> get days {
    final out = <DateTime>[];
    var d = start;
    while (d.isBefore(end)) {
      out.add(d);
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return out;
  }

  /// "Novembro" ou "Novembro/2025" quando for de outro ano.
  String label({DateTime? now}) {
    final m = DateFormat.MMMM('pt_BR').format(start);
    final cap = m[0].toUpperCase() + m.substring(1);
    final y = (now ?? DateTime.now()).year;
    return start.year == y ? cap : '$cap/${start.year}';
  }

  String shortLabel() {
    final m = DateFormat.MMM('pt_BR').format(start).replaceAll('.', '');
    return m[0].toUpperCase() + m.substring(1);
  }

  @override
  bool operator ==(Object other) =>
      other is Cycle && other.key == key && other.start == start;
  @override
  int get hashCode => Object.hash(key, start);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
