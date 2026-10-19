import 'package:flutter/material.dart';


class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    this.isAdmin = false,
    this.identityLabel = '',
    this.onSignOut,
  });

  final bool isAdmin;
  final String identityLabel;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Padel Community',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (onSignOut != null)
            IconButton(
              tooltip: 'Esci dall’account Google',
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          IconButton(
            tooltip: 'Notifiche',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            if (identityLabel.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isAdmin
                      ? const Color(0xFFE4F3EB)
                      : const Color(0xFFE8F0FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      TestIdentity.isAdmin
                          ? Icons.admin_panel_settings_rounded
                          : Icons.person_rounded,
                      color: TestIdentity.isAdmin
                          ? const Color(0xFF146C5A)
                          : const Color(0xFF315EA8),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TestIdentity.isAdmin
                                ? 'ADMIN · GOOGLE TEST'
                                : 'GIOCATORE · TEST LOCALE',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            isAdmin ? 'Account Google: $identityLabel' : 'Identità simulata: $identityLabel',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Il prossimo match\ncomincia qui.',
              style: TextStyle(
                fontSize: 32,
                height: 1.12,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Trova quattro giocatori, organizza il campo e scendi in partita.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF5D6A65),
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crea una partita'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.search_rounded),
              label: const Text('Trova una partita'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            if (TestIdentity.isAdmin) ...[
              const SizedBox(height: 24),
              const _SectionHeading(
                title: 'Area amministratore',
                subtitle: 'Visibile solo nella sessione 1 di test',
              ),
              const SizedBox(height: 12),
              const Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFE4F3EB),
                    foregroundColor: Color(0xFF146C5A),
                    child: Icon(Icons.admin_panel_settings_rounded),
                  ),
                  title: Text(
                    'Circoli, campi e prenotazioni',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Area dimostrativa: i permessi reali non sono ancora collegati.',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            const _SectionHeading(
              title: 'La tua settimana',
              subtitle: 'Le partite e le richieste da completare',
            ),
            const SizedBox(height: 12),
            const _EmptyStateCard(),
            const SizedBox(height: 24),
            const _SectionHeading(
              title: 'Da tenere d’occhio',
              subtitle: 'Le attività che richiedono attenzione',
            ),
            const SizedBox(height: 12),
            const _InfoTile(
              icon: Icons.groups_2_outlined,
              title: 'Partite in formazione',
              detail: 'Le richieste incomplete appariranno qui.',
            ),
            const SizedBox(height: 10),
            const _InfoTile(
              icon: Icons.sports_tennis_rounded,
              title: 'Campo da assegnare',
              detail: 'Le partite complete senza campo saranno evidenziate.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF68756F), fontSize: 13),
        ),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.calendar_month_rounded, color: Color(0xFF146C5A)),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nessuna partita per ora',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Crea una richiesta oppure candidati a una partita aperta.',
                  style: TextStyle(color: Color(0xFF52645C), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF3EF),
          foregroundColor: const Color(0xFF146C5A),
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(detail),
        ),
      ),
    );
  }
}
