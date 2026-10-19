import 'match_models.dart';

enum MatchValidationIssue {
  missingMatchId,
  missingArea,
  invalidPlayerIdentity,
  participantCountMustBeFour,
  duplicatePlayers,
  invalidPlayerComposition,
  missingExceptionalApprovals,
  exceptionalWomanMustBeHigherCategory,
  courtBookingMissing,
  courtBookingNotConfirmed,
  courtBookingDoesNotCoverMatch,
}

class MatchRules {
  const MatchRules._();

  static const matchDuration = Duration(minutes: 90);
  static const invitationLifetime = Duration(minutes: 120);

  static List<MatchValidationIssue> validateForConfirmation(
    MatchRequest request,
  ) {
    final issues = <MatchValidationIssue>[];

    if (request.id.trim().isEmpty) {
      issues.add(MatchValidationIssue.missingMatchId);
    }
    if (request.area.trim().isEmpty) {
      issues.add(MatchValidationIssue.missingArea);
    }
    if (request.participants.any((player) => player.userId.trim().isEmpty)) {
      issues.add(MatchValidationIssue.invalidPlayerIdentity);
    }
    if (!request.isFull) {
      issues.add(MatchValidationIssue.participantCountMustBeFour);
    }

    final playerIds = request.participants.map((player) => player.userId);
    if (playerIds.toSet().length != playerIds.length) {
      issues.add(MatchValidationIssue.duplicatePlayers);
    }

    if (request.isFull && playerIds.toSet().length == MatchRequest.playerCapacity) {
      _validateComposition(request, issues);
    }

    if (request.format == MatchFormat.exceptionalMixed) {
      final participantIds = request.participants.map((player) => player.userId);
      if (!participantIds.every(request.approvedParticipantIds.contains)) {
        issues.add(MatchValidationIssue.missingExceptionalApprovals);
      }
    }

    final booking = request.courtBooking;
    if (booking == null) {
      issues.add(MatchValidationIssue.courtBookingMissing);
    } else {
      if (!booking.isConfirmed) {
        issues.add(MatchValidationIssue.courtBookingNotConfirmed);
      }
      final matchEndsAt = request.startsAt.add(matchDuration);
      if (booking.id.trim().isEmpty ||
          booking.startsAt.isAfter(request.startsAt) ||
          booking.endsAt.isBefore(matchEndsAt) ||
          !booking.endsAt.isAfter(booking.startsAt)) {
        issues.add(MatchValidationIssue.courtBookingDoesNotCoverMatch);
      }
    }

    return List.unmodifiable(issues);
  }

  static void _validateComposition(
    MatchRequest request,
    List<MatchValidationIssue> issues,
  ) {
    final men = request.participants
        .where((player) => player.gender == PlayerGender.male)
        .toList();
    final women = request.participants
        .where((player) => player.gender == PlayerGender.female)
        .toList();

    switch (request.format) {
      case MatchFormat.mensDoubles:
        if (men.length != MatchRequest.playerCapacity) {
          issues.add(MatchValidationIssue.invalidPlayerComposition);
        }
      case MatchFormat.womensDoubles:
        if (women.length != MatchRequest.playerCapacity) {
          issues.add(MatchValidationIssue.invalidPlayerComposition);
        }
      case MatchFormat.mixedDoubles:
        if (men.length != 2 || women.length != 2) {
          issues.add(MatchValidationIssue.invalidPlayerComposition);
        }
      case MatchFormat.exceptionalMixed:
        // The currently specified exceptional composition is three men and
        // one woman. The exact category gap remains a product decision.
        if (men.length != 3 || women.length != 1) {
          issues.add(MatchValidationIssue.invalidPlayerComposition);
        } else if (women.single.category.rank <=
            request.requestedCategory.rank) {
          issues.add(
            MatchValidationIssue.exceptionalWomanMustBeHigherCategory,
          );
        }
    }
  }
}

class MatchInvitation {
  const MatchInvitation({
    required this.id,
    required this.matchId,
    required this.invitedUserId,
    required this.sentAt,
  });

  final String id;
  final String matchId;
  final String invitedUserId;
  final DateTime sentAt;

  DateTime get expiresAt => sentAt.add(MatchRules.invitationLifetime);

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);
}
