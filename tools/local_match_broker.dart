import 'dart:async';
import 'dart:convert';
import 'dart:io';

class LocalMatchBroker {
  LocalMatchBroker({required this.dataFile});

  final File dataFile;
  final List<Map<String, dynamic>> _matches = <Map<String, dynamic>>[];

  Future<void> load() async {
    await dataFile.parent.create(recursive: true);
    if (!await dataFile.exists()) {
      await _persist();
      return;
    }
    try {
      final decoded = jsonDecode(await dataFile.readAsString());
      if (decoded is Map<String, dynamic> && decoded['matches'] is List) {
        _matches
          ..clear()
          ..addAll(
            (decoded['matches'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item)),
          );
      }
    } on FormatException {
      stderr.writeln('Stored match data is invalid JSON; starting an empty test store.');
      _matches.clear();
      await _persist();
    }
  }

  Future<void> handle(HttpRequest request) async {
    _addCorsHeaders(request);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    final path = request.uri.path;
    if (request.method == 'GET' && path == '/api/health') {
      await _respond(request, HttpStatus.ok, <String, dynamic>{'ok': true});
      return;
    }
    if (request.method == 'GET' && path == '/api/matches') {
      final sorted = List<Map<String, dynamic>>.from(_matches)
        ..sort((a, b) => (b['createdAt'] as String? ?? '')
            .compareTo(a['createdAt'] as String? ?? ''));
      await _respond(request, HttpStatus.ok, <String, dynamic>{'matches': sorted});
      return;
    }
    if (request.method == 'POST' && path == '/api/matches') {
      await _createMatch(request);
      return;
    }

    final matchPath = RegExp(r'^/api/matches/([^/]+)/join$').firstMatch(path);
    if (request.method == 'POST' && matchPath != null) {
      await _joinMatch(request, Uri.decodeComponent(matchPath.group(1)!));
      return;
    }

    await _respond(
      request,
      HttpStatus.notFound,
      <String, dynamic>{'error': 'endpoint_not_found'},
    );
  }

  void _addCorsHeaders(HttpRequest request) {
    final origin = request.headers.value(HttpHeaders.originHeader);
    final parsed = origin == null ? null : Uri.tryParse(origin);
    final allowed = parsed != null &&
        parsed.scheme == 'http' &&
        parsed.host == '127.0.0.1' &&
        parsed.port >= 7357 &&
        parsed.port <= 7399;
    if (allowed) {
      request.response.headers.set(HttpHeaders.accessControlAllowOriginHeader, origin!);
      request.response.headers.set(HttpHeaders.varyHeader, 'Origin');
    }
    request.response.headers.set(
      HttpHeaders.accessControlAllowMethodsHeader,
      'GET, POST, OPTIONS',
    );
    request.response.headers.set(
      HttpHeaders.accessControlAllowHeadersHeader,
      'Content-Type',
    );
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
  }

  Future<void> _createMatch(HttpRequest request) async {
    final body = await _readJson(request);
    if (body == null) {
      await _respond(request, HttpStatus.badRequest, <String, dynamic>{'error': 'invalid_json'});
      return;
    }

    final id = _asText(body['id']);
    final createdBy = _asText(body['createdBy']);
    final createdByName = _asText(body['createdByName']);
    final format = _asText(body['format']);
    final category = _asText(body['requestedCategory']);
    final area = _asText(body['area']);
    final startsAt = _asText(body['startsAt']);
    final participantsValue = body['participants'];

    if (id.isEmpty ||
        createdBy.isEmpty ||
        createdByName.isEmpty ||
        format.isEmpty ||
        category.isEmpty ||
        area.isEmpty ||
        DateTime.tryParse(startsAt) == null ||
        participantsValue is! List ||
        participantsValue.isEmpty ||
        participantsValue.length > 4) {
      await _respond(
        request,
        HttpStatus.badRequest,
        <String, dynamic>{'error': 'missing_or_invalid_match_fields'},
      );
      return;
    }
    if (_matches.any((match) => match['id'] == id)) {
      await _respond(request, HttpStatus.conflict, <String, dynamic>{'error': 'match_already_exists'});
      return;
    }

    final participants = <Map<String, dynamic>>[];
    for (final value in participantsValue) {
      if (value is! Map) {
        await _respond(request, HttpStatus.badRequest, <String, dynamic>{'error': 'invalid_participant'});
        return;
      }
      final participant = Map<String, dynamic>.from(value);
      if (_asText(participant['userId']).isEmpty ||
          _asText(participant['displayName']).isEmpty ||
          !_validGender(_asText(participant['gender'])) ||
          !_categoryRank.containsKey(_asText(participant['category']))) {
        await _respond(request, HttpStatus.badRequest, <String, dynamic>{'error': 'invalid_participant'});
        return;
      }
      if (participants.any((item) => item['userId'] == participant['userId'])) {
        await _respond(request, HttpStatus.badRequest, <String, dynamic>{'error': 'duplicate_participant'});
        return;
      }
      participants.add(participant);
    }

    if (!participants.any((item) => item['userId'] == createdBy)) {
      await _respond(
        request,
        HttpStatus.badRequest,
        <String, dynamic>{'error': 'creator_must_be_participant'},
      );
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final match = <String, dynamic>{
      'id': id,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'format': format,
      'requestedCategory': category,
      'area': area,
      'startsAt': DateTime.parse(startsAt).toUtc().toIso8601String(),
      'createdAt': now,
      'participants': participants,
      'status': participants.length == 4 ? _fullStatus(format) : 'in_formation',
    };
    if (participants.length == 4) {
      final compositionError = _compositionError(match, participants);
      if (compositionError != null) {
        await _respond(
          request,
          HttpStatus.unprocessableEntity,
          <String, dynamic>{'error': compositionError},
        );
        return;
      }
    }
    _matches.add(match);
    await _persist();
    await _respond(request, HttpStatus.created, match);
  }

  Future<void> _joinMatch(HttpRequest request, String id) async {
    final body = await _readJson(request);
    if (body == null) {
      await _respond(request, HttpStatus.badRequest, <String, dynamic>{'error': 'invalid_json'});
      return;
    }
    final matchIndex = _matches.indexWhere((match) => match['id'] == id);
    if (matchIndex == -1) {
      await _respond(request, HttpStatus.notFound, <String, dynamic>{'error': 'match_not_found'});
      return;
    }
    final match = _matches[matchIndex];
    final participants = List<Map<String, dynamic>>.from(
      (match['participants'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item)),
    );
    final userId = _asText(body['userId']);
    final displayName = _asText(body['displayName']);
    final gender = _asText(body['gender']);
    final category = _asText(body['category']);
    if (userId.isEmpty ||
        displayName.isEmpty ||
        !_validGender(gender) ||
        !_categoryRank.containsKey(category)) {
      await _respond(request, HttpStatus.badRequest, <String, dynamic>{'error': 'invalid_participant'});
      return;
    }
    if (participants.any((item) => item['userId'] == userId)) {
      await _respond(request, HttpStatus.conflict, <String, dynamic>{'error': 'already_joined'});
      return;
    }
    if (participants.length >= 4) {
      await _respond(request, HttpStatus.conflict, <String, dynamic>{'error': 'match_is_full'});
      return;
    }

    participants.add(<String, dynamic>{
      'userId': userId,
      'displayName': displayName,
      'gender': gender,
      'category': category,
    });
    if (participants.length == 4) {
      final candidate = Map<String, dynamic>.from(match)..['participants'] = participants;
      final compositionError = _compositionError(candidate, participants);
      if (compositionError != null) {
        await _respond(
          request,
          HttpStatus.unprocessableEntity,
          <String, dynamic>{'error': compositionError},
        );
        return;
      }
    }

    match['participants'] = participants;
    match['status'] = participants.length < 4 ? 'in_formation' : _fullStatus(_asText(match['format']));
    await _persist();
    await _respond(request, HttpStatus.ok, match);
  }

  String? _compositionError(Map<String, dynamic> match, List<Map<String, dynamic>> players) {
    final men = players.where((player) => player['gender'] == 'male').length;
    final women = players.where((player) => player['gender'] == 'female').length;
    switch (_asText(match['format'])) {
      case 'mensDoubles':
        return men == 4 ? null : 'mens_doubles_requires_four_men';
      case 'womensDoubles':
        return women == 4 ? null : 'womens_doubles_requires_four_women';
      case 'mixedDoubles':
        return men == 2 && women == 2 ? null : 'mixed_doubles_requires_two_men_and_two_women';
      case 'exceptionalMixed':
        if (men != 3 || women != 1) return 'exceptional_mixed_requires_three_men_and_one_woman';
        final woman = players.singleWhere((player) => player['gender'] == 'female');
        final womanRank = _categoryRank[_asText(woman['category'])] ?? -1;
        final requiredRank = _categoryRank[_asText(match['requestedCategory'])] ?? 99;
        if (womanRank <= requiredRank) return 'exceptional_mixed_woman_category_must_be_higher';
        return null;
      default:
        return 'unknown_match_format';
    }
  }

  String _fullStatus(String format) =>
      format == 'exceptionalMixed' ? 'awaiting_approvals' : 'awaiting_court';

  static const _categoryRank = <String, int>{
    'Bronze': 0,
    'Silver': 1,
    'Silver-Gold': 2,
    'Gold': 3,
    'Gold+': 4,
  };

  bool _validGender(String value) => value == 'male' || value == 'female';

  String _asText(dynamic value) => value is String ? value.trim() : '';

  Future<Map<String, dynamic>?> _readJson(HttpRequest request) async {
    try {
      final decoded = jsonDecode(await utf8.decoder.bind(request).join());
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _persist() async {
    final data = const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'schemaVersion': 1,
      'matches': _matches,
    });
    final tempFile = File('\${dataFile.path}.tmp');
    await tempFile.writeAsString(data, flush: true);
    if (await dataFile.exists()) {
      await dataFile.delete();
    }
    await tempFile.rename(dataFile.path);
  }

  Future<void> _respond(
    HttpRequest request,
    int status,
    Object body,
  ) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }
}

Future<void> main(List<String> args) async {
  var port = 7401;
  var dataPath = '\${Directory.systemTemp.path}\${Platform.pathSeparator}padel-match-test-store.json';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--port' && i + 1 < args.length) {
      port = int.tryParse(args[++i]) ?? port;
    } else if (args[i] == '--data' && i + 1 < args.length) {
      dataPath = args[++i];
    }
  }

  final broker = LocalMatchBroker(dataFile: File(dataPath));
  await broker.load();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Local PADEL test broker listening on http://127.0.0.1:$port');
  await for (final request in server) {
    unawaited(broker.handle(request));
  }
}
