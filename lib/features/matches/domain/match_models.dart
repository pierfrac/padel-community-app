enum PlayerCategory {
  bronze,
  silver,
  silverGold,
  gold,
  goldPlus,
}

extension PlayerCategoryDetails on PlayerCategory {
  String get label => switch (this) {
        PlayerCategory.bronze => 'Bronze',
        PlayerCategory.silver => 'Silver',
        PlayerCategory.silverGold => 'Silver-Gold',
        PlayerCategory.gold => 'Gold',
        PlayerCategory.goldPlus => 'Gold+',
      };

  int get rank => switch (this) {
        PlayerCategory.bronze => 0,
        PlayerCategory.silver => 1,
        PlayerCategory.silverGold => 2,
        PlayerCategory.gold => 3,
        PlayerCategory.goldPlus => 4,
      };
}

enum PlayerGender {
  male,
  female,
}

enum MatchFormat {
  mensDoubles,
  womensDoubles,
  mixedDoubles,
  exceptionalMixed,
}

class MatchParticipant {
  const MatchParticipant({
    required this.userId,
    required this.gender,
    required this.category,
  });

  final String userId;
  final PlayerGender gender;
  final PlayerCategory category;
}

class CourtBooking {
  const CourtBooking({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.isConfirmed,
  });

  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isConfirmed;
}

class MatchRequest {
  MatchRequest({
    required this.id,
    required this.format,
    required this.requestedCategory,
    required this.startsAt,
    required this.area,
    required List<MatchParticipant> participants,
    Iterable<String> approvedParticipantIds = const [],
    this.courtBooking,
  })  : participants = List.unmodifiable(participants),
        approvedParticipantIds = Set.unmodifiable(approvedParticipantIds);

  final String id;
  final MatchFormat format;
  final PlayerCategory requestedCategory;
  final DateTime startsAt;
  final String area;
  final List<MatchParticipant> participants;
  final Set<String> approvedParticipantIds;
  final CourtBooking? courtBooking;

  static const playerCapacity = 4;

  int get vacantPlaces =>
      participants.length >= playerCapacity ? 0 : playerCapacity - participants.length;

  bool get isFull => participants.length == playerCapacity;

  bool get hasFourDistinctPlayers =>
      isFull && participants.map((player) => player.userId).toSet().length == 4;
}
