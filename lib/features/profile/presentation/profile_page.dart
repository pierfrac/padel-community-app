import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profilo', style: TextStyle(fontWeight: FontWeight.w800))),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: const Color(0xFFEAF3EF), borderRadius: BorderRadius.circular(24)), child: const Column(children: [
        CircleAvatar(radius: 38, backgroundColor: Colors.white, child: Icon(Icons.person_rounded, size: 42, color: Color(0xFF146C5A))),
        SizedBox(height: 12),
        Text('Il tuo profilo', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
        SizedBox(height: 4),
        Text('Account non ancora collegato', style: TextStyle(color: Color(0xFF52645C))),
        SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _Metric(value: '—', label: 'Categoria'), _Metric(value: '0', label: 'Partite'), _Metric(value: '—', label: 'Circolo'),
        ]),
      ])),
      const SizedBox(height: 22),
      const Text('Impostazioni', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      _Option(icon: Icons.badge_outlined, title: 'Dati personali', subtitle: 'Nome e informazioni condivise'),
      _Option(icon: Icons.sports_tennis_outlined, title: 'Categoria di gioco', subtitle: 'Bronze · Silver · Silver-Gold · Gold · Gold+'),
      _Option(icon: Icons.notifications_none_rounded, title: 'Notifiche', subtitle: 'Inviti, partite e promemoria'),
      _Option(icon: Icons.calendar_month_outlined, title: 'Calendario personale', subtitle: 'Solo le tue partite confermate'),
      _Option(icon: Icons.privacy_tip_outlined, title: 'Privacy e dati', subtitle: 'Consensi e cancellazione account'),
      const SizedBox(height: 12),
      const Text('Le impostazioni e l’autenticazione saranno attivate prima della beta pubblica.', style: TextStyle(fontSize: 12, color: Color(0xFF68756F), height: 1.4)),
    ]),
  );
}
class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value; final String label;
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF52645C)))]);
}
class _Option extends StatelessWidget {
  const _Option({required this.icon, required this.title, required this.subtitle});
  final IconData icon; final String title; final String subtitle;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), leading: CircleAvatar(backgroundColor: const Color(0xFFEAF3EF), foregroundColor: const Color(0xFF146C5A), child: Icon(icon)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded)));
}
