import 'package:flutter/material.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});
  @override
  State<MatchesPage> createState() => _MatchesPageState();
}
class _MatchesPageState extends State<MatchesPage> {
  String _filter = 'Tutte';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Partite', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: _create, icon: const Icon(Icons.add_circle_outline_rounded)), const SizedBox(width: 8)]),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Trova il tuo\nprossimo match.', style: TextStyle(fontSize: 30, height: 1.1, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Richieste della comunità e posti disponibili.', style: TextStyle(color: Color(0xFF68756F))),
      const SizedBox(height: 18),
      Wrap(spacing: 7, children: ['Tutte','Aperte','In formazione','Confermate'].map((v) => ChoiceChip(label: Text(v), selected: _filter == v, onSelected: (_) => setState(() => _filter = v)).toList()),
      const SizedBox(height: 16),
      if (_filter == 'Tutte' || _filter == 'Aperte') _card('Doppio misto', 'Domani · 18:00–19:30', '2 posti disponibili · Circolo da definire', '2 / 4', '2 POSTI LIBERI', const Color(0xFFFFF0D9), const Color(0xFF8A5700)),
      if (_filter == 'Tutte' || _filter == 'In formazione') ...[const SizedBox(height: 12), _card('Doppio maschile', 'Mercoledì · 20:00–21:30', 'Zona da definire', '3 / 4', 'IN FORMAZIONE', const Color(0xFFE8F0FF), const Color(0xFF315EA8))],
      if (_filter == 'Tutte' || _filter == 'Confermate') ...[const SizedBox(height: 12), _card('Doppio femminile', 'Venerdì · 19:00–20:30', 'Campo assegnato dall’admin', '4 / 4', 'CONFERMATA', const Color(0xFFE4F3EB), const Color(0xFF146C5A))],
      const SizedBox(height: 16),
      const Text('Dati dimostrativi: candidature e conferme saranno collegate al modello dati prima della beta.', style: TextStyle(fontSize: 12, color: Color(0xFF68756F), height: 1.4)),
    ]),
  );

  Widget _card(String title, String date, String detail, String players, String status, Color tint, Color ink) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(7)), child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ink))),
    const SizedBox(height: 12),
    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 8),
    Text(date, style: const TextStyle(fontSize: 13, color: Color(0xFF4F5D57))),
    const SizedBox(height: 5),
    Text(detail, style: const TextStyle(fontSize: 12, color: Color(0xFF68756F))),
    const SizedBox(height: 14),
    Row(children: [const Icon(Icons.groups_2_outlined, size: 17, color: Color(0xFF68756F)), const SizedBox(width: 6), Text('$players giocatori', style: const TextStyle(fontWeight: FontWeight.w700)), const Spacer(), OutlinedButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Candidature disponibili dopo il collegamento ai dati reali.'))), child: Text(players == '4 / 4' ? 'Dettagli' : 'Mi candido'))]),
  ])));

  void _create() {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (context) => const _CreateMatchSheet());
  }
}

class _CreateMatchSheet extends StatefulWidget {
  const _CreateMatchSheet();
  @override
  State<_CreateMatchSheet> createState() => _CreateMatchSheetState();
}
class _CreateMatchSheetState extends State<_CreateMatchSheet> {
  String _format = 'Doppio misto';
  String _category = 'Silver';
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 24), child: Wrap(runSpacing: 12, children: [
    const Text('Crea una partita', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
    DropdownButtonFormField<String>(value: _format, decoration: const InputDecoration(labelText: 'Formato', border: OutlineInputBorder()), items: ['Doppio maschile','Doppio femminile','Doppio misto','Composizione eccezionale'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _format = v ?? _format)),
    DropdownButtonFormField<String>(value: _category, decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()), items: ['Bronze','Silver','Silver-Gold','Gold','Gold+'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _category = v ?? _category)),
    SizedBox(width: double.infinity, child: FilledButton(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Il salvataggio sarà attivato con il modello dati.'))); }, child: const Text('Continua')),
  ]));
}
