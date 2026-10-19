import 'package:flutter/material.dart';

class AvailabilityPage extends StatefulWidget {
  const AvailabilityPage({super.key});
  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}
class _AvailabilityPageState extends State<AvailabilityPage> {
  final Set<int> _days = {1,3,5};
  RangeValues _hours = const RangeValues(18,21);
  bool _repeat = true;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Disponibilità', style: TextStyle(fontWeight: FontWeight.w800))),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Quando puoi\ngiocare?', style: TextStyle(fontSize: 30, height: 1.1, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Le disponibilità aiutano a trovare combinazioni compatibili, ma non confermano una partita.', style: TextStyle(color: Color(0xFF68756F), height: 1.4)),
      const SizedBox(height: 24),
      const Text('Giorni della settimana', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Row(children: List.generate(7, (i) => Expanded(child: GestureDetector(onTap: () => setState(() => _days.contains(i) ? _days.remove(i) : _days.add(i)), child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: _days.contains(i) ? const Color(0xFF146C5A) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE3E9E6))), child: Center(child: Text(const ['L','M','M','G','V','S','D'][i], style: TextStyle(fontWeight: FontWeight.w800, color: _days.contains(i) ? Colors.white : const Color(0xFF4F5D57)))))))),
      const SizedBox(height: 26),
      const Text('Fascia oraria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text('${_time(_hours.start)} – ${_time(_hours.end)}', style: const TextStyle(fontSize: 24, color: Color(0xFF146C5A), fontWeight: FontWeight.w800)),
      RangeSlider(values: _hours, min: 7, max: 23, divisions: 16, onChanged: (v) => setState(() => _hours = v)),
      const SizedBox(height: 16),
      Card(child: SwitchListTile(value: _repeat, onChanged: (v) => setState(() => _repeat = v), title: const Text('Ripeti ogni settimana', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('Le eccezioni si potranno gestire separatamente.'))),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schermata pronta; salvataggio da collegare al database locale.'))), icon: const Icon(Icons.check_rounded), label: const Text('Salva disponibilità'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52))),
    ]),
  );
  static String _time(double v) => '${v.floor().toString().padLeft(2,'0')}:${((v % 1) * 60).round().toString().padLeft(2,'0')}';
}
