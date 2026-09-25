import 'dart:convert';
import 'backup_limits.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';

/// The production sink uses a private encrypted node table with a unique
/// (parent,key) index. It does not accumulate object keys or a whole JSON map.
abstract interface class BackupJsonSink {
  int writeNode(int? parent, String? key, String kind, Object? value);
}

/// Incremental strict JSON reader. It holds at most one bounded scalar token
/// and 32 structural frames; a sink owns original order and duplicate checks.
class BackupJsonReader {
  BackupJsonReader(this.sink, this.budget, {this.portableRecords = false}) {
    if (portableRecords) budget.earlyRecordAdmission = true;
  }
  final bool portableRecords;
  final BackupJsonSink sink;
  final BackupBudget budget;
  final _frames = <_Frame>[];
  int? root;
  String _mode = '';
  var _token = StringBuffer();
  int _stringBytes = 0;
  int _stringLimit = BackupLimits.stringBytes;
  int? _highSurrogate;
  bool _escaped = false;
  int _unicodeDigits = 0;
  int _unicodeValue = 0;
  bool _rootComplete = false;

  Future<int> read(Stream<List<int>> utf8Bytes) async {
    try {
      return await _read(utf8Bytes);
    } on FormatException catch (error) {
      if (error is BackupProcessingFailure) rethrow;
      BackupLimits.invalid();
    }
  }

  Future<int> _read(Stream<List<int>> utf8Bytes) async {
    var unitsSinceYield = 0;
    await for (final chunk in utf8.decoder.bind(utf8Bytes)) {
      budget.lease?.check();
      for (final code in chunk.codeUnits) {
        _consume(code);
      }
      // Writers may emit punctuation-sized fragments. Yield by actual decoded
      // work, not per fragment, while cancellation is checked on every fragment.
      unitsSinceYield += chunk.length;
      if (unitsSinceYield >= 16384) {
        unitsSinceYield = 0;
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (_mode == 'literal') _finishLiteral();
    if (_mode.isNotEmpty ||
        _frames.isNotEmpty ||
        !_rootComplete ||
        root == null) {
      BackupLimits.invalid();
    }
    return root!;
  }

  bool get _expectsKey =>
      _frames.isNotEmpty &&
      _frames.last.kind == 'object' &&
      (_frames.last.state == 'keyOrEnd' || _frames.last.state == 'key');

  void _consume(int c) {
    if (_mode == 'string') {
      _string(c);
      return;
    }
    if (_mode == 'literal') {
      if (_delimiter(c)) {
        _finishLiteral();
        _consume(c);
      } else {
        if (_token.length == BackupLimits.stringBytes) {
          BackupLimits.exceeded('token');
        }
        _token.writeCharCode(c);
      }
      return;
    }
    if (_whitespace(c)) return;
    if (c == 34) {
      if (!_expectsKey) _requireValue();
      _mode = 'string';
      _token = StringBuffer();
      _stringBytes = 0;
      final identifier =
          _expectsKey ||
          (portableRecords &&
              _frames.isNotEmpty &&
              {'schedule', 'template', 'record'}.contains(_frames.last.role) &&
              {
                'id',
                'nextId',
                'timeZoneId',
                'preparationTemplateId',
                'recurringSegmentId',
                'preparationDefinitionId',
                'ownerId',
                'definitionId',
                'seriesId',
                'preparationId',
                'segmentId',
              }.contains(_frames.last.key));
      _stringLimit = identifier
          ? BackupLimits.identifierBytes
          : BackupLimits.stringBytes;
      return;
    }
    switch (c) {
      case 123:
        _open('object');
      case 91:
        _open('array');
      case 125:
        _close('object');
      case 93:
        _close('array');
      case 58:
        if (_frames.isEmpty || _frames.last.state != 'colon') {
          BackupLimits.invalid();
        }
        _frames.last.state = 'value';
      case 44:
        if (_frames.isEmpty || _frames.last.state != 'commaOrEnd') {
          BackupLimits.invalid();
        }
        final frame = _frames.last;
        frame.state = frame.kind == 'object' ? 'key' : 'value';
      default:
        _requireValue();
        if (!(c == 45 ||
            (c >= 48 && c <= 57) ||
            c == 116 ||
            c == 102 ||
            c == 110)) {
          BackupLimits.invalid();
        }
        _mode = 'literal';
        _token = StringBuffer()..writeCharCode(c);
    }
  }

  static bool _whitespace(int c) => c == 32 || c == 9 || c == 10 || c == 13;
  static bool _delimiter(int c) =>
      _whitespace(c) || c == 44 || c == 93 || c == 125;

  void _requireValue() {
    if (_frames.isEmpty) {
      if (_rootComplete || root != null) BackupLimits.invalid();
    } else if (!{'value', 'valueOrEnd'}.contains(_frames.last.state)) {
      BackupLimits.invalid();
    }
  }

  int _node(String kind, Object? value) {
    _requireValue();
    budget.visit();
    final parent = _frames.isEmpty ? null : _frames.last;
    final key = parent == null
        ? null
        : parent.kind == 'array'
        ? '${parent.index++}'
        : parent.key;
    if (portableRecords && parent != null) {
      final record =
          {
            'schedules',
            'defaultPreparation',
            'preparationList',
            'templates',
            'recurringRecords',
          }.contains(parent.role) ||
          (parent.role == 'root' && {'profile', 'preferences'}.contains(key)) ||
          (parent.role == 'schedule' && key == 'place');
      if (record) {
        if ({'defaultPreparation', 'preparationList'}.contains(parent.role) &&
            parent.index > BackupLimits.preparationSteps) {
          BackupLimits.exceeded('preparationSteps');
        }
        budget.admit(schedule: parent.role == 'schedules');
      }
    }
    final id = sink.writeNode(parent?.id, key, kind, value);
    if (parent == null) {
      root = id;
      _rootComplete = true;
    } else {
      parent.state = 'commaOrEnd';
      parent.key = null;
    }
    return id;
  }

  String _valueRole() {
    if (_frames.isEmpty) return 'root';
    final parent = _frames.last;
    if (parent.role == 'root' &&
        {
          'schedules',
          'defaultPreparation',
          'schedulePreparations',
          'templates',
          'recurring',
        }.contains(parent.key)) {
      return parent.key!;
    }
    if (parent.role == 'schedules') return 'schedule';
    if ({
          'defaultPreparation',
          'preparationList',
          'recurringRecords',
        }.contains(parent.role) ||
        (parent.role == 'schedule' && parent.key == 'place')) {
      return 'record';
    }
    if (parent.role == 'templates') return 'template';
    if (parent.role == 'schedulePreparations' ||
        (parent.role == 'template' && parent.key == 'preparation')) {
      return 'preparationList';
    }
    if (parent.role == 'recurring' &&
        {
          'definitions',
          'steps',
          'segments',
          'exclusions',
        }.contains(parent.key)) {
      return 'recurringRecords';
    }
    return '';
  }

  void _open(String kind) {
    if (_frames.length == BackupLimits.depth) BackupLimits.exceeded('depth');
    final role = _valueRole();
    final id = _node(kind, null);
    _frames.add(_Frame(id, kind, role));
  }

  void _close(String kind) {
    if (_frames.isEmpty || _frames.last.kind != kind) BackupLimits.invalid();
    final state = _frames.last.state;
    if (state != 'commaOrEnd' &&
        state != (kind == 'object' ? 'keyOrEnd' : 'valueOrEnd')) {
      BackupLimits.invalid();
    }
    _frames.removeLast();
  }

  void _string(int c) {
    if (_unicodeDigits > 0) {
      final digit = c >= 48 && c <= 57
          ? c - 48
          : c >= 65 && c <= 70
          ? c - 55
          : c >= 97 && c <= 102
          ? c - 87
          : -1;
      if (digit < 0) BackupLimits.invalid();
      _unicodeValue = _unicodeValue * 16 + digit;
      if (--_unicodeDigits == 0) _appendScalarUnit(_unicodeValue);
      return;
    }
    if (_escaped) {
      _escaped = false;
      if (c == 117) {
        _unicodeDigits = 4;
        _unicodeValue = 0;
        return;
      }
      final decoded = switch (c) {
        34 => 34,
        92 => 92,
        47 => 47,
        98 => 8,
        102 => 12,
        110 => 10,
        114 => 13,
        116 => 9,
        _ => -1,
      };
      if (decoded < 0) BackupLimits.invalid();
      _appendScalarUnit(decoded);
      return;
    }
    if (c == 92) {
      _escaped = true;
      return;
    }
    if (c == 34) {
      if (_highSurrogate != null) BackupLimits.invalid();
      final value = _token.toString();
      _token = StringBuffer();
      _mode = '';
      if (_expectsKey) {
        _frames.last.key = value;
        _frames.last.state = 'colon';
      } else {
        _node('string', value);
      }
      return;
    }
    if (c < 32) BackupLimits.invalid();
    _appendScalarUnit(c);
  }

  void _appendScalarUnit(int c) {
    if (_highSurrogate != null) {
      if (c < 0xdc00 || c > 0xdfff) BackupLimits.invalid();
      _chargeString(4);
      _token.writeCharCode(_highSurrogate!);
      _token.writeCharCode(c);
      _highSurrogate = null;
      return;
    }
    if (c >= 0xd800 && c <= 0xdbff) {
      _highSurrogate = c;
      return;
    }
    if (c >= 0xdc00 && c <= 0xdfff) BackupLimits.invalid();
    _chargeString(
      c < 128
          ? 1
          : c < 2048
          ? 2
          : 3,
    );
    _token.writeCharCode(c);
  }

  void _chargeString(int amount) {
    if (amount > _stringLimit - _stringBytes) {
      BackupLimits.exceeded(_expectsKey ? 'key' : 'string');
    }
    _stringBytes += amount;
    budget.buffer(_stringBytes);
  }

  void _finishLiteral() {
    final raw = _token.toString();
    _token = StringBuffer();
    _mode = '';
    final Object? value;
    try {
      value = jsonDecode(raw);
    } catch (_) {
      BackupLimits.invalid();
    }
    if (value is double && !value.isFinite) BackupLimits.invalid();
    if (value != null && value is! num && value is! bool) {
      BackupLimits.invalid();
    }
    _node(
      value == null
          ? 'null'
          : value is bool
          ? 'bool'
          : 'number',
      value,
    );
  }
}

class _Frame {
  _Frame(this.id, this.kind, this.role)
    : state = kind == 'object' ? 'keyOrEnd' : 'valueOrEnd';
  final int id;
  final String kind;
  final String role;
  String state;
  String? key;
  int index = 0;
}
