import 'package:flutter_test/flutter_test.dart';
import 'package:padel_community_app/features/matches/domain/match_models.dart';
import 'package:padel_community_app/features/matches/domain/match_rules.dart';

void main() {
  final start = DateTime(2026, 11, 7, 18);
  final validCourtBooking = CourtBooking(
    id: 'booking-1',
    startsAt: start.subtract(const Duration(minutes: 15)),
    endsAt: start.add(MatchRules.matchDuration),
    isConfirmed: true,
  );

  MatchParticipant player(
    String id, {
    PlayerGender gender = PlayerGender.male,
    PlayerCategory category = PlayerCategory.silver,
  }) {
    return MatchParticipant(userId: id, gender: gender, category: category);
  }

  MatchRequest request({
    String id = 'match-1',
    MatchFormat format = MatchFormat.mensDoubles,
    PlayerCategory category = PlayerCategory.silver,
    DateTime? startsAt,
    String area = 'Centro',
    List<MatchParticipant>? participants,
    Iterable<String> approvals = const [],
    CourtBooking? booking,
  }) {
    return MatchRequest(
      id: id,
      format: format,
      requestedCategory: category,
      startsAt: startsAt ?? start,
      area: area,
      participants: participants ??
          [player('p1'), player('p2'), player('p3'), player('p4')],
      approvedParticipantIds: approvals,
      courtBooking: booking ?? validCourtBooking,
    );
  }

  test('a valid four-player men's match with a confirmed court can be confirmed', () {
    expect(
      MatchRules.validateForConfirmation(request()),
      isEmpty,
    );
  });

  test('an incomplete request reports vacancies and cannot be confirmed', () {
    final match = request(participants: [player('p1'), player('p2')]);

    expect(match.vacantPlaces, 2);
    expect(match.isFull, isFalse);
    expect(
      MatchRules.validateForConfirmation(match),
      contains(MatchValidationIssue.participantCountMustBeFour),
    );
  });

  test('ordinary mixed doubles requires two men and two women', () {
    final match = request(
      format: MatchFormat.mixedDoubles,
      participants: [
        player('p1'),
        player('p2'),
        player('p3'),
        player('p4', gender: PlayerGender.female),
      ],
    );

    expect(
      MatchRules.validateForConfirmation(match),
      contains(MatchValidationIssue.invalidPlayerComposition),
    );
  });

  test('exceptional mixed match needs every approval and a higher-category woman', () {
    final participants = [
      player('p1'),
      player('p2'),
      player('p3'),
      player(
        'p4',
        gender: PlayerGender.female,
        category: PlayerCategory.gold,
      ),
    ];

    final withoutApprovals = request(
      format: MatchFormat.exceptionalMixed,
      participants: participants,
    );
    expect(
      MatchRules.validateForConfirmation(withoutApprovals),
      contains(MatchValidationIssue.missingExceptionalApprovals),
    );

    final approved = request(
      format: MatchFormat.exceptionalMixed,
      participants: participants,
      approvals: ['p1', 'p2', 'p3', 'p4'],
    );
    expect(MatchRules.validateForConfirmation(approved), isEmpty);
  });

  test('exceptional mixed match rejects a woman not above requested category', () {
    final match = request(
      format: MatchFormat.exceptionalMixed,
      participants: [
        player('p1'),
        player('p2'),
        player('p3'),
        player(
          'p4',
          gender: PlayerGender.female,
          category: PlayerCategory.silver,
        ),
      ],
      approvals: ['p1', 'p2', 'p3', 'p4'],
    );

    expect(
      MatchRules.validateForConfirmation(match),
      contains(MatchValidationIssue.exceptionalWomanMustBeHigherCategory),
    );
  });

  test('confirmation requires a booking covering the full 90 minutes', () {
    final match = request(
      booking: CourtBooking(
        id: 'booking-short',
        startsAt: start,
        endsAt: start.add(const Duration(minutes: 89)),
        isConfirmed: true,
      ),
    );

    expect(
      MatchRules.validateForConfirmation(match),
      contains(MatchValidationIssue.courtBookingDoesNotCoverMatch),
    );
  });

  test('invitations expire exactly 120 minutes after sending', () {
    final invitation = MatchInvitation(
      id: 'invite-1',
      matchId: 'match-1',
      invitedUserId: 'player-4',
      sentAt: start,
    );

    expect(invitation.expiresAt, start.add(const Duration(minutes: 120)));
    expect(
      invitation.isExpiredAt(start.add(const Duration(minutes: 119))),
      isFalse,
    );
    expect(
      invitation.isExpiredAt(start.add(const Duration(minutes: 120))),
      isTrue,
    );
  });
}
