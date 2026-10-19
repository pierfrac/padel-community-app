import 'package:flutter/material.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}
class _CalendarPageState extends State<CalendarPage> {
  DateTime _selected = DateTime.now();
  bool _monthView = false;
  static const _green = Color(0xFF146C5A);
  static const _muted = Color(0xFF68756F);
  static const _months = ['Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno','Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre'];
  static const _days = ['Lun','Mar','Mer','Gio','Ven','Sab','Dom'];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Calendario', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(tooltip: 'Vai a oggi', onPressed: () => setState(() => _selected = DateTime.now()), icon: const Icon(Icons.today_outlined)), const SizedBox(width: 8)]),
    body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [
      Row(children: [
        Expanded(child: Text('${_months[_selected.month - 1]} ${_selected.year}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
        SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('Settimana')), ButtonSegment(value: true, label: Text('Mese'))], selected: {_monthView}, showSelectedIcon: false, onSelectionChanged: (v) => setState(() => _monthView = v.first)),
      ]),
      const SizedBox(height: 18),
      _monthView ? _monthGrid() : _weekStrip(),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: Text('Agenda · ${_selected.day} ${_months[_selected.month - 1]}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
        IconButton(onPressed: () => setState(() => _selected = _selected.subtract(const Duration(days: 1))), icon: const Icon(Icons.chevron_left_rounded)),
        IconButton(onPressed: () => setState(() => _selected = _selected.add(const Duration(days: 1))), icon: const Icon(Icons.chevron_right_rounded)),
      ]),
      const SizedBox(height: 8),
      _event('18:00 – 19:30', 'Doppio misto', '2 posti disponibili · Circolo da definire', 'IN FORMAZIONE', const Color(0xFFFFF0D9), const Color(0xFF8A5700)),
      const SizedBox(height: 10),
      _event('20:00 – 21:30', 'Doppio maschile', '4 giocatori · Campo da assegnare', 'AZIONE RICHIESTA', const Color(0xFFFBE8E7), const Color(0xFFAD3832)),
      const SizedBox(height: 16),
      const Wrap(spacing: 14, runSpacing: 8, children: [
        _Legend(color: Color(0xFFE6A23C), text: 'In formazione'),
        _Legend(color: Color(0xFF146C5A), text: 'Confermata'),
        _Legend(color: Color(0xFFC84D45), text: 'Azione richiesta'),
      ]),
      const SizedBox(height: 20),
      const Text('Il calendario interno gestisce tutte le attività della comunità. Gli eventi qui mostrati sono dimostrativi; il calendario personale riceverà soltanto le tue partite confermate.', style: TextStyle(color: _muted, fontSize: 12, height: 1.5)),
    ]),
  );

  Widget _weekStrip() {
    final start = _selected.subtract(Duration(days: _selected.weekday - 1));
    return Row(children: List.generate(7, (i) {
      final day = start.add(Duration(days: i));
      final chosen = day.year == _selected.year && day.month == _selected.month && day.day == _selected.day;
      return Expanded(child: GestureDetector(onTap: () => setState(() => _selected = day), child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: chosen ? _green : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: chosen ? _green : const Color(0xFFE3E9E6))), child: Column(children: [
        Text(_days[day.weekday - 1], style: TextStyle(fontSize: 10, color: chosen ? Colors.white70 : _muted)),
        const SizedBox(height: 8),
        Text('${day.day}', style: TextStyle(fontWeight: FontWeight.w800, color: chosen ? Colors.white : const Color(0xFF17221F))),
        const SizedBox(height: 7),
        Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: [1,3,5].contains(i) ? (chosen ? Colors.white : _green) : Colors.transparent)),
      ]))));
    }));
  }

  Widget _monthGrid() {
    final first = DateTime(_selected.year, _selected.month, 1);
    final start = first.subtract(Duration(days: first.weekday - 1));
    return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE3E9E6))), child: Column(children: [
      Row(children: List.generate(7, (i) => Expanded(child: Center(child: Text(_days[i], style: const TextStyle(fontSize: 11, color: _muted)))))),
      const SizedBox(height: 8),
      ...List.generate(6, (week) => Row(children: List.generate(7, (i) {
        final day = start.add(Duration(days: week * 7 + i));
        final chosen = day.year == _selected.year && day.month == _selected.month && day.day == _selected.day;
        final inMonth = day.month == _selected.month;
        return Expanded(child: GestureDetector(onTap: () => setState(() => _selected = day), child: Container(height: 37, margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: chosen ? _green : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: Center(child: Text('${day.day}', style: TextStyle(color: chosen ? Colors.white : (inMonth ? const Color(0xFF17221F) : const Color(0xFFB5BDB9)), fontWeight: chosen ? FontWeight.w800 : FontWeight.w500))))));
      }))),
    ]));
  }

  Widget _event(String time, String title, String detail, String status, Color tint, Color ink) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE3E9E6))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 86, child: Text(time, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted))),
    Container(width: 3, height: 76, decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 11),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      const SizedBox(height: 5),
      Text(detail, style: const TextStyle(fontSize: 12, color: _muted)),
      const SizedBox(height: 9),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(6)), child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: ink))),
    ])),
  ]));
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)), const SizedBox(width: 5), Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF68756F)))]);
}
