import 'package:flutter/material.dart';
import '../features/home/presentation/home_page.dart';
import '../features/calendar/presentation/calendar_page.dart';
import '../features/matches/presentation/matches_page.dart';
import '../features/availability/presentation/availability_page.dart';
import '../features/profile/presentation/profile_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.isAdmin = false,
    this.identityLabel = '',
    this.onSignOut,
  });

  final bool isAdmin;
  final String identityLabel;
  final VoidCallback? onSignOut;
  @override
  State<AppShell> createState() => _AppShellState();
}
class _AppShellState extends State<AppShell> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _index,
      children: [
        HomePage(
          isAdmin: widget.isAdmin,
          identityLabel: widget.identityLabel,
          onSignOut: widget.onSignOut,
        ),
        const CalendarPage(),
        const MatchesPage(),
        const AvailabilityPage(),
        const ProfilePage(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (value) => setState(() => _index = value),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Calendario'),
        NavigationDestination(icon: Icon(Icons.sports_tennis_outlined), selectedIcon: Icon(Icons.sports_tennis_rounded), label: 'Partite'),
        NavigationDestination(icon: Icon(Icons.event_available_outlined), selectedIcon: Icon(Icons.event_available_rounded), label: 'Disponibilità'),
        NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profilo'),
      ],
    ),
  );
}
