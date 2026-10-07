// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SemestersTable extends Semesters
    with TableInfo<$SemestersTable, SemesterRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SemestersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<String> endDate = GeneratedColumn<String>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekStartMeta = const VerificationMeta(
    'weekStart',
  );
  @override
  late final GeneratedColumn<int> weekStart = GeneratedColumn<int>(
    'week_start',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(7),
  );
  static const VerificationMeta _visibleDaysMeta = const VerificationMeta(
    'visibleDays',
  );
  @override
  late final GeneratedColumn<int> visibleDays = GeneratedColumn<int>(
    'visible_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0x7F),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deleted,
    updatedAt,
    name,
    startDate,
    endDate,
    weekStart,
    visibleDays,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'semesters';
  @override
  VerificationContext validateIntegrity(
    Insertable<SemesterRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('week_start')) {
      context.handle(
        _weekStartMeta,
        weekStart.isAcceptableOrUnknown(data['week_start']!, _weekStartMeta),
      );
    }
    if (data.containsKey('visible_days')) {
      context.handle(
        _visibleDaysMeta,
        visibleDays.isAcceptableOrUnknown(
          data['visible_days']!,
          _visibleDaysMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SemesterRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SemesterRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date'],
      )!,
      weekStart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}week_start'],
      )!,
      visibleDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}visible_days'],
      )!,
    );
  }

  @override
  $SemestersTable createAlias(String alias) {
    return $SemestersTable(attachedDatabase, alias);
  }
}

class SemesterRow extends DataClass implements Insertable<SemesterRow> {
  /// UUIDv7, or a deterministic id for session overrides.
  final String id;
  final bool deleted;

  /// Local wall-clock ms of the last change. Diagnostics only; sync ordering
  /// uses hybrid logical clocks in the outbox.
  final int updatedAt;
  final String name;
  final String startDate;
  final String endDate;
  final int weekStart;

  /// Bit (weekday - 1) set for every visible ISO weekday.
  final int visibleDays;
  const SemesterRow({
    required this.id,
    required this.deleted,
    required this.updatedAt,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.weekStart,
    required this.visibleDays,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deleted'] = Variable<bool>(deleted);
    map['updated_at'] = Variable<int>(updatedAt);
    map['name'] = Variable<String>(name);
    map['start_date'] = Variable<String>(startDate);
    map['end_date'] = Variable<String>(endDate);
    map['week_start'] = Variable<int>(weekStart);
    map['visible_days'] = Variable<int>(visibleDays);
    return map;
  }

  SemestersCompanion toCompanion(bool nullToAbsent) {
    return SemestersCompanion(
      id: Value(id),
      deleted: Value(deleted),
      updatedAt: Value(updatedAt),
      name: Value(name),
      startDate: Value(startDate),
      endDate: Value(endDate),
      weekStart: Value(weekStart),
      visibleDays: Value(visibleDays),
    );
  }

  factory SemesterRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SemesterRow(
      id: serializer.fromJson<String>(json['id']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      name: serializer.fromJson<String>(json['name']),
      startDate: serializer.fromJson<String>(json['startDate']),
      endDate: serializer.fromJson<String>(json['endDate']),
      weekStart: serializer.fromJson<int>(json['weekStart']),
      visibleDays: serializer.fromJson<int>(json['visibleDays']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deleted': serializer.toJson<bool>(deleted),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'name': serializer.toJson<String>(name),
      'startDate': serializer.toJson<String>(startDate),
      'endDate': serializer.toJson<String>(endDate),
      'weekStart': serializer.toJson<int>(weekStart),
      'visibleDays': serializer.toJson<int>(visibleDays),
    };
  }

  SemesterRow copyWith({
    String? id,
    bool? deleted,
    int? updatedAt,
    String? name,
    String? startDate,
    String? endDate,
    int? weekStart,
    int? visibleDays,
  }) => SemesterRow(
    id: id ?? this.id,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
    name: name ?? this.name,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    weekStart: weekStart ?? this.weekStart,
    visibleDays: visibleDays ?? this.visibleDays,
  );
  SemesterRow copyWithCompanion(SemestersCompanion data) {
    return SemesterRow(
      id: data.id.present ? data.id.value : this.id,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      name: data.name.present ? data.name.value : this.name,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      weekStart: data.weekStart.present ? data.weekStart.value : this.weekStart,
      visibleDays: data.visibleDays.present
          ? data.visibleDays.value
          : this.visibleDays,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SemesterRow(')
          ..write('id: $id, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('name: $name, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('weekStart: $weekStart, ')
          ..write('visibleDays: $visibleDays')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deleted,
    updatedAt,
    name,
    startDate,
    endDate,
    weekStart,
    visibleDays,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SemesterRow &&
          other.id == this.id &&
          other.deleted == this.deleted &&
          other.updatedAt == this.updatedAt &&
          other.name == this.name &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.weekStart == this.weekStart &&
          other.visibleDays == this.visibleDays);
}

class SemestersCompanion extends UpdateCompanion<SemesterRow> {
  final Value<String> id;
  final Value<bool> deleted;
  final Value<int> updatedAt;
  final Value<String> name;
  final Value<String> startDate;
  final Value<String> endDate;
  final Value<int> weekStart;
  final Value<int> visibleDays;
  final Value<int> rowid;
  const SemestersCompanion({
    this.id = const Value.absent(),
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.name = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.weekStart = const Value.absent(),
    this.visibleDays = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SemestersCompanion.insert({
    required String id,
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    required String name,
    required String startDate,
    required String endDate,
    this.weekStart = const Value.absent(),
    this.visibleDays = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       startDate = Value(startDate),
       endDate = Value(endDate);
  static Insertable<SemesterRow> custom({
    Expression<String>? id,
    Expression<bool>? deleted,
    Expression<int>? updatedAt,
    Expression<String>? name,
    Expression<String>? startDate,
    Expression<String>? endDate,
    Expression<int>? weekStart,
    Expression<int>? visibleDays,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deleted != null) 'deleted': deleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (name != null) 'name': name,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (weekStart != null) 'week_start': weekStart,
      if (visibleDays != null) 'visible_days': visibleDays,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SemestersCompanion copyWith({
    Value<String>? id,
    Value<bool>? deleted,
    Value<int>? updatedAt,
    Value<String>? name,
    Value<String>? startDate,
    Value<String>? endDate,
    Value<int>? weekStart,
    Value<int>? visibleDays,
    Value<int>? rowid,
  }) {
    return SemestersCompanion(
      id: id ?? this.id,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      weekStart: weekStart ?? this.weekStart,
      visibleDays: visibleDays ?? this.visibleDays,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (weekStart.present) {
      map['week_start'] = Variable<int>(weekStart.value);
    }
    if (visibleDays.present) {
      map['visible_days'] = Variable<int>(visibleDays.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SemestersCompanion(')
          ..write('id: $id, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('name: $name, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('weekStart: $weekStart, ')
          ..write('visibleDays: $visibleDays, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CoursesTable extends Courses with TableInfo<$CoursesTable, CourseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoursesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _semesterIdMeta = const VerificationMeta(
    'semesterId',
  );
  @override
  late final GeneratedColumn<String> semesterId = GeneratedColumn<String>(
    'semester_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _lecturerMeta = const VerificationMeta(
    'lecturer',
  );
  @override
  late final GeneratedColumn<String> lecturer = GeneratedColumn<String>(
    'lecturer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _colorKeyMeta = const VerificationMeta(
    'colorKey',
  );
  @override
  late final GeneratedColumn<String> colorKey = GeneratedColumn<String>(
    'color_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ocean'),
  );
  static const VerificationMeta _websiteMeta = const VerificationMeta(
    'website',
  );
  @override
  late final GeneratedColumn<String> website = GeneratedColumn<String>(
    'website',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _linksMeta = const VerificationMeta('links');
  @override
  late final GeneratedColumn<String> links = GeneratedColumn<String>(
    'links',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deleted,
    updatedAt,
    semesterId,
    name,
    code,
    lecturer,
    colorKey,
    website,
    notes,
    links,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'courses';
  @override
  VerificationContext validateIntegrity(
    Insertable<CourseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('semester_id')) {
      context.handle(
        _semesterIdMeta,
        semesterId.isAcceptableOrUnknown(data['semester_id']!, _semesterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_semesterIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    }
    if (data.containsKey('lecturer')) {
      context.handle(
        _lecturerMeta,
        lecturer.isAcceptableOrUnknown(data['lecturer']!, _lecturerMeta),
      );
    }
    if (data.containsKey('color_key')) {
      context.handle(
        _colorKeyMeta,
        colorKey.isAcceptableOrUnknown(data['color_key']!, _colorKeyMeta),
      );
    }
    if (data.containsKey('website')) {
      context.handle(
        _websiteMeta,
        website.isAcceptableOrUnknown(data['website']!, _websiteMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('links')) {
      context.handle(
        _linksMeta,
        links.isAcceptableOrUnknown(data['links']!, _linksMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CourseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CourseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      semesterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semester_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      lecturer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lecturer'],
      )!,
      colorKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_key'],
      )!,
      website: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}website'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      links: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}links'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $CoursesTable createAlias(String alias) {
    return $CoursesTable(attachedDatabase, alias);
  }
}

class CourseRow extends DataClass implements Insertable<CourseRow> {
  /// UUIDv7, or a deterministic id for session overrides.
  final String id;
  final bool deleted;

  /// Local wall-clock ms of the last change. Diagnostics only; sync ordering
  /// uses hybrid logical clocks in the outbox.
  final int updatedAt;
  final String semesterId;
  final String name;
  final String code;
  final String lecturer;
  final String colorKey;
  final String website;
  final String notes;

  /// JSON list of `{title, url}`.
  final String links;
  final int sortOrder;
  const CourseRow({
    required this.id,
    required this.deleted,
    required this.updatedAt,
    required this.semesterId,
    required this.name,
    required this.code,
    required this.lecturer,
    required this.colorKey,
    required this.website,
    required this.notes,
    required this.links,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deleted'] = Variable<bool>(deleted);
    map['updated_at'] = Variable<int>(updatedAt);
    map['semester_id'] = Variable<String>(semesterId);
    map['name'] = Variable<String>(name);
    map['code'] = Variable<String>(code);
    map['lecturer'] = Variable<String>(lecturer);
    map['color_key'] = Variable<String>(colorKey);
    map['website'] = Variable<String>(website);
    map['notes'] = Variable<String>(notes);
    map['links'] = Variable<String>(links);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  CoursesCompanion toCompanion(bool nullToAbsent) {
    return CoursesCompanion(
      id: Value(id),
      deleted: Value(deleted),
      updatedAt: Value(updatedAt),
      semesterId: Value(semesterId),
      name: Value(name),
      code: Value(code),
      lecturer: Value(lecturer),
      colorKey: Value(colorKey),
      website: Value(website),
      notes: Value(notes),
      links: Value(links),
      sortOrder: Value(sortOrder),
    );
  }

  factory CourseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CourseRow(
      id: serializer.fromJson<String>(json['id']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      semesterId: serializer.fromJson<String>(json['semesterId']),
      name: serializer.fromJson<String>(json['name']),
      code: serializer.fromJson<String>(json['code']),
      lecturer: serializer.fromJson<String>(json['lecturer']),
      colorKey: serializer.fromJson<String>(json['colorKey']),
      website: serializer.fromJson<String>(json['website']),
      notes: serializer.fromJson<String>(json['notes']),
      links: serializer.fromJson<String>(json['links']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deleted': serializer.toJson<bool>(deleted),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'semesterId': serializer.toJson<String>(semesterId),
      'name': serializer.toJson<String>(name),
      'code': serializer.toJson<String>(code),
      'lecturer': serializer.toJson<String>(lecturer),
      'colorKey': serializer.toJson<String>(colorKey),
      'website': serializer.toJson<String>(website),
      'notes': serializer.toJson<String>(notes),
      'links': serializer.toJson<String>(links),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  CourseRow copyWith({
    String? id,
    bool? deleted,
    int? updatedAt,
    String? semesterId,
    String? name,
    String? code,
    String? lecturer,
    String? colorKey,
    String? website,
    String? notes,
    String? links,
    int? sortOrder,
  }) => CourseRow(
    id: id ?? this.id,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
    semesterId: semesterId ?? this.semesterId,
    name: name ?? this.name,
    code: code ?? this.code,
    lecturer: lecturer ?? this.lecturer,
    colorKey: colorKey ?? this.colorKey,
    website: website ?? this.website,
    notes: notes ?? this.notes,
    links: links ?? this.links,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  CourseRow copyWithCompanion(CoursesCompanion data) {
    return CourseRow(
      id: data.id.present ? data.id.value : this.id,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      semesterId: data.semesterId.present
          ? data.semesterId.value
          : this.semesterId,
      name: data.name.present ? data.name.value : this.name,
      code: data.code.present ? data.code.value : this.code,
      lecturer: data.lecturer.present ? data.lecturer.value : this.lecturer,
      colorKey: data.colorKey.present ? data.colorKey.value : this.colorKey,
      website: data.website.present ? data.website.value : this.website,
      notes: data.notes.present ? data.notes.value : this.notes,
      links: data.links.present ? data.links.value : this.links,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CourseRow(')
          ..write('id: $id, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('semesterId: $semesterId, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('lecturer: $lecturer, ')
          ..write('colorKey: $colorKey, ')
          ..write('website: $website, ')
          ..write('notes: $notes, ')
          ..write('links: $links, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deleted,
    updatedAt,
    semesterId,
    name,
    code,
    lecturer,
    colorKey,
    website,
    notes,
    links,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CourseRow &&
          other.id == this.id &&
          other.deleted == this.deleted &&
          other.updatedAt == this.updatedAt &&
          other.semesterId == this.semesterId &&
          other.name == this.name &&
          other.code == this.code &&
          other.lecturer == this.lecturer &&
          other.colorKey == this.colorKey &&
          other.website == this.website &&
          other.notes == this.notes &&
          other.links == this.links &&
          other.sortOrder == this.sortOrder);
}

class CoursesCompanion extends UpdateCompanion<CourseRow> {
  final Value<String> id;
  final Value<bool> deleted;
  final Value<int> updatedAt;
  final Value<String> semesterId;
  final Value<String> name;
  final Value<String> code;
  final Value<String> lecturer;
  final Value<String> colorKey;
  final Value<String> website;
  final Value<String> notes;
  final Value<String> links;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const CoursesCompanion({
    this.id = const Value.absent(),
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.semesterId = const Value.absent(),
    this.name = const Value.absent(),
    this.code = const Value.absent(),
    this.lecturer = const Value.absent(),
    this.colorKey = const Value.absent(),
    this.website = const Value.absent(),
    this.notes = const Value.absent(),
    this.links = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CoursesCompanion.insert({
    required String id,
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    required String semesterId,
    required String name,
    this.code = const Value.absent(),
    this.lecturer = const Value.absent(),
    this.colorKey = const Value.absent(),
    this.website = const Value.absent(),
    this.notes = const Value.absent(),
    this.links = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       semesterId = Value(semesterId),
       name = Value(name);
  static Insertable<CourseRow> custom({
    Expression<String>? id,
    Expression<bool>? deleted,
    Expression<int>? updatedAt,
    Expression<String>? semesterId,
    Expression<String>? name,
    Expression<String>? code,
    Expression<String>? lecturer,
    Expression<String>? colorKey,
    Expression<String>? website,
    Expression<String>? notes,
    Expression<String>? links,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deleted != null) 'deleted': deleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (semesterId != null) 'semester_id': semesterId,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (lecturer != null) 'lecturer': lecturer,
      if (colorKey != null) 'color_key': colorKey,
      if (website != null) 'website': website,
      if (notes != null) 'notes': notes,
      if (links != null) 'links': links,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CoursesCompanion copyWith({
    Value<String>? id,
    Value<bool>? deleted,
    Value<int>? updatedAt,
    Value<String>? semesterId,
    Value<String>? name,
    Value<String>? code,
    Value<String>? lecturer,
    Value<String>? colorKey,
    Value<String>? website,
    Value<String>? notes,
    Value<String>? links,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return CoursesCompanion(
      id: id ?? this.id,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
      semesterId: semesterId ?? this.semesterId,
      name: name ?? this.name,
      code: code ?? this.code,
      lecturer: lecturer ?? this.lecturer,
      colorKey: colorKey ?? this.colorKey,
      website: website ?? this.website,
      notes: notes ?? this.notes,
      links: links ?? this.links,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (semesterId.present) {
      map['semester_id'] = Variable<String>(semesterId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (lecturer.present) {
      map['lecturer'] = Variable<String>(lecturer.value);
    }
    if (colorKey.present) {
      map['color_key'] = Variable<String>(colorKey.value);
    }
    if (website.present) {
      map['website'] = Variable<String>(website.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (links.present) {
      map['links'] = Variable<String>(links.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoursesCompanion(')
          ..write('id: $id, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('semesterId: $semesterId, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('lecturer: $lecturer, ')
          ..write('colorKey: $colorKey, ')
          ..write('website: $website, ')
          ..write('notes: $notes, ')
          ..write('links: $links, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MeetingsTable extends Meetings
    with TableInfo<$MeetingsTable, MeetingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeetingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('lecture'),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('weekly'),
  );
  static const VerificationMeta _weekdayMeta = const VerificationMeta(
    'weekday',
  );
  @override
  late final GeneratedColumn<int> weekday = GeneratedColumn<int>(
    'weekday',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startMinMeta = const VerificationMeta(
    'startMin',
  );
  @override
  late final GeneratedColumn<int> startMin = GeneratedColumn<int>(
    'start_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinMeta = const VerificationMeta('endMin');
  @override
  late final GeneratedColumn<int> endMin = GeneratedColumn<int>(
    'end_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _intervalWeeksMeta = const VerificationMeta(
    'intervalWeeks',
  );
  @override
  late final GeneratedColumn<int> intervalWeeks = GeneratedColumn<int>(
    'interval_weeks',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _validFromMeta = const VerificationMeta(
    'validFrom',
  );
  @override
  late final GeneratedColumn<String> validFrom = GeneratedColumn<String>(
    'valid_from',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _validUntilMeta = const VerificationMeta(
    'validUntil',
  );
  @override
  late final GeneratedColumn<String> validUntil = GeneratedColumn<String>(
    'valid_until',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linksMeta = const VerificationMeta('links');
  @override
  late final GeneratedColumn<String> links = GeneratedColumn<String>(
    'links',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deleted,
    updatedAt,
    courseId,
    type,
    kind,
    weekday,
    date,
    startMin,
    endMin,
    location,
    intervalWeeks,
    validFrom,
    validUntil,
    links,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meetings';
  @override
  VerificationContext validateIntegrity(
    Insertable<MeetingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('weekday')) {
      context.handle(
        _weekdayMeta,
        weekday.isAcceptableOrUnknown(data['weekday']!, _weekdayMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('start_min')) {
      context.handle(
        _startMinMeta,
        startMin.isAcceptableOrUnknown(data['start_min']!, _startMinMeta),
      );
    } else if (isInserting) {
      context.missing(_startMinMeta);
    }
    if (data.containsKey('end_min')) {
      context.handle(
        _endMinMeta,
        endMin.isAcceptableOrUnknown(data['end_min']!, _endMinMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('interval_weeks')) {
      context.handle(
        _intervalWeeksMeta,
        intervalWeeks.isAcceptableOrUnknown(
          data['interval_weeks']!,
          _intervalWeeksMeta,
        ),
      );
    }
    if (data.containsKey('valid_from')) {
      context.handle(
        _validFromMeta,
        validFrom.isAcceptableOrUnknown(data['valid_from']!, _validFromMeta),
      );
    }
    if (data.containsKey('valid_until')) {
      context.handle(
        _validUntilMeta,
        validUntil.isAcceptableOrUnknown(data['valid_until']!, _validUntilMeta),
      );
    }
    if (data.containsKey('links')) {
      context.handle(
        _linksMeta,
        links.isAcceptableOrUnknown(data['links']!, _linksMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MeetingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MeetingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      weekday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekday'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      ),
      startMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_min'],
      )!,
      endMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_min'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      intervalWeeks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_weeks'],
      )!,
      validFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valid_from'],
      ),
      validUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valid_until'],
      ),
      links: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}links'],
      )!,
    );
  }

  @override
  $MeetingsTable createAlias(String alias) {
    return $MeetingsTable(attachedDatabase, alias);
  }
}

class MeetingRow extends DataClass implements Insertable<MeetingRow> {
  /// UUIDv7, or a deterministic id for session overrides.
  final String id;
  final bool deleted;

  /// Local wall-clock ms of the last change. Diagnostics only; sync ordering
  /// uses hybrid logical clocks in the outbox.
  final int updatedAt;
  final String courseId;
  final String type;
  final String kind;
  final int? weekday;
  final String? date;
  final int startMin;
  final int endMin;
  final String location;
  final int intervalWeeks;
  final String? validFrom;
  final String? validUntil;
  final String links;
  const MeetingRow({
    required this.id,
    required this.deleted,
    required this.updatedAt,
    required this.courseId,
    required this.type,
    required this.kind,
    this.weekday,
    this.date,
    required this.startMin,
    required this.endMin,
    required this.location,
    required this.intervalWeeks,
    this.validFrom,
    this.validUntil,
    required this.links,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deleted'] = Variable<bool>(deleted);
    map['updated_at'] = Variable<int>(updatedAt);
    map['course_id'] = Variable<String>(courseId);
    map['type'] = Variable<String>(type);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || weekday != null) {
      map['weekday'] = Variable<int>(weekday);
    }
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<String>(date);
    }
    map['start_min'] = Variable<int>(startMin);
    map['end_min'] = Variable<int>(endMin);
    map['location'] = Variable<String>(location);
    map['interval_weeks'] = Variable<int>(intervalWeeks);
    if (!nullToAbsent || validFrom != null) {
      map['valid_from'] = Variable<String>(validFrom);
    }
    if (!nullToAbsent || validUntil != null) {
      map['valid_until'] = Variable<String>(validUntil);
    }
    map['links'] = Variable<String>(links);
    return map;
  }

  MeetingsCompanion toCompanion(bool nullToAbsent) {
    return MeetingsCompanion(
      id: Value(id),
      deleted: Value(deleted),
      updatedAt: Value(updatedAt),
      courseId: Value(courseId),
      type: Value(type),
      kind: Value(kind),
      weekday: weekday == null && nullToAbsent
          ? const Value.absent()
          : Value(weekday),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      startMin: Value(startMin),
      endMin: Value(endMin),
      location: Value(location),
      intervalWeeks: Value(intervalWeeks),
      validFrom: validFrom == null && nullToAbsent
          ? const Value.absent()
          : Value(validFrom),
      validUntil: validUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(validUntil),
      links: Value(links),
    );
  }

  factory MeetingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MeetingRow(
      id: serializer.fromJson<String>(json['id']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      courseId: serializer.fromJson<String>(json['courseId']),
      type: serializer.fromJson<String>(json['type']),
      kind: serializer.fromJson<String>(json['kind']),
      weekday: serializer.fromJson<int?>(json['weekday']),
      date: serializer.fromJson<String?>(json['date']),
      startMin: serializer.fromJson<int>(json['startMin']),
      endMin: serializer.fromJson<int>(json['endMin']),
      location: serializer.fromJson<String>(json['location']),
      intervalWeeks: serializer.fromJson<int>(json['intervalWeeks']),
      validFrom: serializer.fromJson<String?>(json['validFrom']),
      validUntil: serializer.fromJson<String?>(json['validUntil']),
      links: serializer.fromJson<String>(json['links']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deleted': serializer.toJson<bool>(deleted),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'courseId': serializer.toJson<String>(courseId),
      'type': serializer.toJson<String>(type),
      'kind': serializer.toJson<String>(kind),
      'weekday': serializer.toJson<int?>(weekday),
      'date': serializer.toJson<String?>(date),
      'startMin': serializer.toJson<int>(startMin),
      'endMin': serializer.toJson<int>(endMin),
      'location': serializer.toJson<String>(location),
      'intervalWeeks': serializer.toJson<int>(intervalWeeks),
      'validFrom': serializer.toJson<String?>(validFrom),
      'validUntil': serializer.toJson<String?>(validUntil),
      'links': serializer.toJson<String>(links),
    };
  }

  MeetingRow copyWith({
    String? id,
    bool? deleted,
    int? updatedAt,
    String? courseId,
    String? type,
    String? kind,
    Value<int?> weekday = const Value.absent(),
    Value<String?> date = const Value.absent(),
    int? startMin,
    int? endMin,
    String? location,
    int? intervalWeeks,
    Value<String?> validFrom = const Value.absent(),
    Value<String?> validUntil = const Value.absent(),
    String? links,
  }) => MeetingRow(
    id: id ?? this.id,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
    courseId: courseId ?? this.courseId,
    type: type ?? this.type,
    kind: kind ?? this.kind,
    weekday: weekday.present ? weekday.value : this.weekday,
    date: date.present ? date.value : this.date,
    startMin: startMin ?? this.startMin,
    endMin: endMin ?? this.endMin,
    location: location ?? this.location,
    intervalWeeks: intervalWeeks ?? this.intervalWeeks,
    validFrom: validFrom.present ? validFrom.value : this.validFrom,
    validUntil: validUntil.present ? validUntil.value : this.validUntil,
    links: links ?? this.links,
  );
  MeetingRow copyWithCompanion(MeetingsCompanion data) {
    return MeetingRow(
      id: data.id.present ? data.id.value : this.id,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      type: data.type.present ? data.type.value : this.type,
      kind: data.kind.present ? data.kind.value : this.kind,
      weekday: data.weekday.present ? data.weekday.value : this.weekday,
      date: data.date.present ? data.date.value : this.date,
      startMin: data.startMin.present ? data.startMin.value : this.startMin,
      endMin: data.endMin.present ? data.endMin.value : this.endMin,
      location: data.location.present ? data.location.value : this.location,
      intervalWeeks: data.intervalWeeks.present
          ? data.intervalWeeks.value
          : this.intervalWeeks,
      validFrom: data.validFrom.present ? data.validFrom.value : this.validFrom,
      validUntil: data.validUntil.present
          ? data.validUntil.value
          : this.validUntil,
      links: data.links.present ? data.links.value : this.links,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MeetingRow(')
          ..write('id: $id, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('courseId: $courseId, ')
          ..write('type: $type, ')
          ..write('kind: $kind, ')
          ..write('weekday: $weekday, ')
          ..write('date: $date, ')
          ..write('startMin: $startMin, ')
          ..write('endMin: $endMin, ')
          ..write('location: $location, ')
          ..write('intervalWeeks: $intervalWeeks, ')
          ..write('validFrom: $validFrom, ')
          ..write('validUntil: $validUntil, ')
          ..write('links: $links')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deleted,
    updatedAt,
    courseId,
    type,
    kind,
    weekday,
    date,
    startMin,
    endMin,
    location,
    intervalWeeks,
    validFrom,
    validUntil,
    links,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MeetingRow &&
          other.id == this.id &&
          other.deleted == this.deleted &&
          other.updatedAt == this.updatedAt &&
          other.courseId == this.courseId &&
          other.type == this.type &&
          other.kind == this.kind &&
          other.weekday == this.weekday &&
          other.date == this.date &&
          other.startMin == this.startMin &&
          other.endMin == this.endMin &&
          other.location == this.location &&
          other.intervalWeeks == this.intervalWeeks &&
          other.validFrom == this.validFrom &&
          other.validUntil == this.validUntil &&
          other.links == this.links);
}

class MeetingsCompanion extends UpdateCompanion<MeetingRow> {
  final Value<String> id;
  final Value<bool> deleted;
  final Value<int> updatedAt;
  final Value<String> courseId;
  final Value<String> type;
  final Value<String> kind;
  final Value<int?> weekday;
  final Value<String?> date;
  final Value<int> startMin;
  final Value<int> endMin;
  final Value<String> location;
  final Value<int> intervalWeeks;
  final Value<String?> validFrom;
  final Value<String?> validUntil;
  final Value<String> links;
  final Value<int> rowid;
  const MeetingsCompanion({
    this.id = const Value.absent(),
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.courseId = const Value.absent(),
    this.type = const Value.absent(),
    this.kind = const Value.absent(),
    this.weekday = const Value.absent(),
    this.date = const Value.absent(),
    this.startMin = const Value.absent(),
    this.endMin = const Value.absent(),
    this.location = const Value.absent(),
    this.intervalWeeks = const Value.absent(),
    this.validFrom = const Value.absent(),
    this.validUntil = const Value.absent(),
    this.links = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MeetingsCompanion.insert({
    required String id,
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    required String courseId,
    this.type = const Value.absent(),
    this.kind = const Value.absent(),
    this.weekday = const Value.absent(),
    this.date = const Value.absent(),
    required int startMin,
    required int endMin,
    this.location = const Value.absent(),
    this.intervalWeeks = const Value.absent(),
    this.validFrom = const Value.absent(),
    this.validUntil = const Value.absent(),
    this.links = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       courseId = Value(courseId),
       startMin = Value(startMin),
       endMin = Value(endMin);
  static Insertable<MeetingRow> custom({
    Expression<String>? id,
    Expression<bool>? deleted,
    Expression<int>? updatedAt,
    Expression<String>? courseId,
    Expression<String>? type,
    Expression<String>? kind,
    Expression<int>? weekday,
    Expression<String>? date,
    Expression<int>? startMin,
    Expression<int>? endMin,
    Expression<String>? location,
    Expression<int>? intervalWeeks,
    Expression<String>? validFrom,
    Expression<String>? validUntil,
    Expression<String>? links,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deleted != null) 'deleted': deleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (courseId != null) 'course_id': courseId,
      if (type != null) 'type': type,
      if (kind != null) 'kind': kind,
      if (weekday != null) 'weekday': weekday,
      if (date != null) 'date': date,
      if (startMin != null) 'start_min': startMin,
      if (endMin != null) 'end_min': endMin,
      if (location != null) 'location': location,
      if (intervalWeeks != null) 'interval_weeks': intervalWeeks,
      if (validFrom != null) 'valid_from': validFrom,
      if (validUntil != null) 'valid_until': validUntil,
      if (links != null) 'links': links,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MeetingsCompanion copyWith({
    Value<String>? id,
    Value<bool>? deleted,
    Value<int>? updatedAt,
    Value<String>? courseId,
    Value<String>? type,
    Value<String>? kind,
    Value<int?>? weekday,
    Value<String?>? date,
    Value<int>? startMin,
    Value<int>? endMin,
    Value<String>? location,
    Value<int>? intervalWeeks,
    Value<String?>? validFrom,
    Value<String?>? validUntil,
    Value<String>? links,
    Value<int>? rowid,
  }) {
    return MeetingsCompanion(
      id: id ?? this.id,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
      courseId: courseId ?? this.courseId,
      type: type ?? this.type,
      kind: kind ?? this.kind,
      weekday: weekday ?? this.weekday,
      date: date ?? this.date,
      startMin: startMin ?? this.startMin,
      endMin: endMin ?? this.endMin,
      location: location ?? this.location,
      intervalWeeks: intervalWeeks ?? this.intervalWeeks,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      links: links ?? this.links,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (weekday.present) {
      map['weekday'] = Variable<int>(weekday.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (startMin.present) {
      map['start_min'] = Variable<int>(startMin.value);
    }
    if (endMin.present) {
      map['end_min'] = Variable<int>(endMin.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (intervalWeeks.present) {
      map['interval_weeks'] = Variable<int>(intervalWeeks.value);
    }
    if (validFrom.present) {
      map['valid_from'] = Variable<String>(validFrom.value);
    }
    if (validUntil.present) {
      map['valid_until'] = Variable<String>(validUntil.value);
    }
    if (links.present) {
      map['links'] = Variable<String>(links.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeetingsCompanion(')
          ..write('id: $id, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('courseId: $courseId, ')
          ..write('type: $type, ')
          ..write('kind: $kind, ')
          ..write('weekday: $weekday, ')
          ..write('date: $date, ')
          ..write('startMin: $startMin, ')
          ..write('endMin: $endMin, ')
          ..write('location: $location, ')
          ..write('intervalWeeks: $intervalWeeks, ')
          ..write('validFrom: $validFrom, ')
          ..write('validUntil: $validUntil, ')
          ..write('links: $links, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionOverridesTable extends SessionOverrides
    with TableInfo<$SessionOverridesTable, SessionOverrideRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionOverridesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalDateMeta = const VerificationMeta(
    'originalDate',
  );
  @override
  late final GeneratedColumn<String> originalDate = GeneratedColumn<String>(
    'original_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _recordingUrlMeta = const VerificationMeta(
    'recordingUrl',
  );
  @override
  late final GeneratedColumn<String> recordingUrl = GeneratedColumn<String>(
    'recording_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _movedDateMeta = const VerificationMeta(
    'movedDate',
  );
  @override
  late final GeneratedColumn<String> movedDate = GeneratedColumn<String>(
    'moved_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _movedStartMinMeta = const VerificationMeta(
    'movedStartMin',
  );
  @override
  late final GeneratedColumn<int> movedStartMin = GeneratedColumn<int>(
    'moved_start_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _movedEndMinMeta = const VerificationMeta(
    'movedEndMin',
  );
  @override
  late final GeneratedColumn<int> movedEndMin = GeneratedColumn<int>(
    'moved_end_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _movedLocationMeta = const VerificationMeta(
    'movedLocation',
  );
  @override
  late final GeneratedColumn<String> movedLocation = GeneratedColumn<String>(
    'moved_location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deleted,
    updatedAt,
    meetingId,
    originalDate,
    status,
    notes,
    recordingUrl,
    movedDate,
    movedStartMin,
    movedEndMin,
    movedLocation,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_overrides';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionOverrideRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('original_date')) {
      context.handle(
        _originalDateMeta,
        originalDate.isAcceptableOrUnknown(
          data['original_date']!,
          _originalDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalDateMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('recording_url')) {
      context.handle(
        _recordingUrlMeta,
        recordingUrl.isAcceptableOrUnknown(
          data['recording_url']!,
          _recordingUrlMeta,
        ),
      );
    }
    if (data.containsKey('moved_date')) {
      context.handle(
        _movedDateMeta,
        movedDate.isAcceptableOrUnknown(data['moved_date']!, _movedDateMeta),
      );
    }
    if (data.containsKey('moved_start_min')) {
      context.handle(
        _movedStartMinMeta,
        movedStartMin.isAcceptableOrUnknown(
          data['moved_start_min']!,
          _movedStartMinMeta,
        ),
      );
    }
    if (data.containsKey('moved_end_min')) {
      context.handle(
        _movedEndMinMeta,
        movedEndMin.isAcceptableOrUnknown(
          data['moved_end_min']!,
          _movedEndMinMeta,
        ),
      );
    }
    if (data.containsKey('moved_location')) {
      context.handle(
        _movedLocationMeta,
        movedLocation.isAcceptableOrUnknown(
          data['moved_location']!,
          _movedLocationMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionOverrideRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionOverrideRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      originalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_date'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      recordingUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_url'],
      ),
      movedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}moved_date'],
      ),
      movedStartMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}moved_start_min'],
      ),
      movedEndMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}moved_end_min'],
      ),
      movedLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}moved_location'],
      ),
    );
  }

  @override
  $SessionOverridesTable createAlias(String alias) {
    return $SessionOverridesTable(attachedDatabase, alias);
  }
}

class SessionOverrideRow extends DataClass
    implements Insertable<SessionOverrideRow> {
  /// UUIDv7, or a deterministic id for session overrides.
  final String id;
  final bool deleted;

  /// Local wall-clock ms of the last change. Diagnostics only; sync ordering
  /// uses hybrid logical clocks in the outbox.
  final int updatedAt;
  final String meetingId;
  final String originalDate;
  final String? status;
  final String notes;
  final String? recordingUrl;
  final String? movedDate;
  final int? movedStartMin;
  final int? movedEndMin;
  final String? movedLocation;
  const SessionOverrideRow({
    required this.id,
    required this.deleted,
    required this.updatedAt,
    required this.meetingId,
    required this.originalDate,
    this.status,
    required this.notes,
    this.recordingUrl,
    this.movedDate,
    this.movedStartMin,
    this.movedEndMin,
    this.movedLocation,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deleted'] = Variable<bool>(deleted);
    map['updated_at'] = Variable<int>(updatedAt);
    map['meeting_id'] = Variable<String>(meetingId);
    map['original_date'] = Variable<String>(originalDate);
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    map['notes'] = Variable<String>(notes);
    if (!nullToAbsent || recordingUrl != null) {
      map['recording_url'] = Variable<String>(recordingUrl);
    }
    if (!nullToAbsent || movedDate != null) {
      map['moved_date'] = Variable<String>(movedDate);
    }
    if (!nullToAbsent || movedStartMin != null) {
      map['moved_start_min'] = Variable<int>(movedStartMin);
    }
    if (!nullToAbsent || movedEndMin != null) {
      map['moved_end_min'] = Variable<int>(movedEndMin);
    }
    if (!nullToAbsent || movedLocation != null) {
      map['moved_location'] = Variable<String>(movedLocation);
    }
    return map;
  }

  SessionOverridesCompanion toCompanion(bool nullToAbsent) {
    return SessionOverridesCompanion(
      id: Value(id),
      deleted: Value(deleted),
      updatedAt: Value(updatedAt),
      meetingId: Value(meetingId),
      originalDate: Value(originalDate),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      notes: Value(notes),
      recordingUrl: recordingUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(recordingUrl),
      movedDate: movedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(movedDate),
      movedStartMin: movedStartMin == null && nullToAbsent
          ? const Value.absent()
          : Value(movedStartMin),
      movedEndMin: movedEndMin == null && nullToAbsent
          ? const Value.absent()
          : Value(movedEndMin),
      movedLocation: movedLocation == null && nullToAbsent
          ? const Value.absent()
          : Value(movedLocation),
    );
  }

  factory SessionOverrideRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionOverrideRow(
      id: serializer.fromJson<String>(json['id']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      originalDate: serializer.fromJson<String>(json['originalDate']),
      status: serializer.fromJson<String?>(json['status']),
      notes: serializer.fromJson<String>(json['notes']),
      recordingUrl: serializer.fromJson<String?>(json['recordingUrl']),
      movedDate: serializer.fromJson<String?>(json['movedDate']),
      movedStartMin: serializer.fromJson<int?>(json['movedStartMin']),
      movedEndMin: serializer.fromJson<int?>(json['movedEndMin']),
      movedLocation: serializer.fromJson<String?>(json['movedLocation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deleted': serializer.toJson<bool>(deleted),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'meetingId': serializer.toJson<String>(meetingId),
      'originalDate': serializer.toJson<String>(originalDate),
      'status': serializer.toJson<String?>(status),
      'notes': serializer.toJson<String>(notes),
      'recordingUrl': serializer.toJson<String?>(recordingUrl),
      'movedDate': serializer.toJson<String?>(movedDate),
      'movedStartMin': serializer.toJson<int?>(movedStartMin),
      'movedEndMin': serializer.toJson<int?>(movedEndMin),
      'movedLocation': serializer.toJson<String?>(movedLocation),
    };
  }

  SessionOverrideRow copyWith({
    String? id,
    bool? deleted,
    int? updatedAt,
    String? meetingId,
    String? originalDate,
    Value<String?> status = const Value.absent(),
    String? notes,
    Value<String?> recordingUrl = const Value.absent(),
    Value<String?> movedDate = const Value.absent(),
    Value<int?> movedStartMin = const Value.absent(),
    Value<int?> movedEndMin = const Value.absent(),
    Value<String?> movedLocation = const Value.absent(),
  }) => SessionOverrideRow(
    id: id ?? this.id,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
    meetingId: meetingId ?? this.meetingId,
    originalDate: originalDate ?? this.originalDate,
    status: status.present ? status.value : this.status,
    notes: notes ?? this.notes,
    recordingUrl: recordingUrl.present ? recordingUrl.value : this.recordingUrl,
    movedDate: movedDate.present ? movedDate.value : this.movedDate,
    movedStartMin: movedStartMin.present
        ? movedStartMin.value
        : this.movedStartMin,
    movedEndMin: movedEndMin.present ? movedEndMin.value : this.movedEndMin,
    movedLocation: movedLocation.present
        ? movedLocation.value
        : this.movedLocation,
  );
  SessionOverrideRow copyWithCompanion(SessionOverridesCompanion data) {
    return SessionOverrideRow(
      id: data.id.present ? data.id.value : this.id,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      originalDate: data.originalDate.present
          ? data.originalDate.value
          : this.originalDate,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
      recordingUrl: data.recordingUrl.present
          ? data.recordingUrl.value
          : this.recordingUrl,
      movedDate: data.movedDate.present ? data.movedDate.value : this.movedDate,
      movedStartMin: data.movedStartMin.present
          ? data.movedStartMin.value
          : this.movedStartMin,
      movedEndMin: data.movedEndMin.present
          ? data.movedEndMin.value
          : this.movedEndMin,
      movedLocation: data.movedLocation.present
          ? data.movedLocation.value
          : this.movedLocation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionOverrideRow(')
          ..write('id: $id, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('originalDate: $originalDate, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('recordingUrl: $recordingUrl, ')
          ..write('movedDate: $movedDate, ')
          ..write('movedStartMin: $movedStartMin, ')
          ..write('movedEndMin: $movedEndMin, ')
          ..write('movedLocation: $movedLocation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deleted,
    updatedAt,
    meetingId,
    originalDate,
    status,
    notes,
    recordingUrl,
    movedDate,
    movedStartMin,
    movedEndMin,
    movedLocation,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionOverrideRow &&
          other.id == this.id &&
          other.deleted == this.deleted &&
          other.updatedAt == this.updatedAt &&
          other.meetingId == this.meetingId &&
          other.originalDate == this.originalDate &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.recordingUrl == this.recordingUrl &&
          other.movedDate == this.movedDate &&
          other.movedStartMin == this.movedStartMin &&
          other.movedEndMin == this.movedEndMin &&
          other.movedLocation == this.movedLocation);
}

class SessionOverridesCompanion extends UpdateCompanion<SessionOverrideRow> {
  final Value<String> id;
  final Value<bool> deleted;
  final Value<int> updatedAt;
  final Value<String> meetingId;
  final Value<String> originalDate;
  final Value<String?> status;
  final Value<String> notes;
  final Value<String?> recordingUrl;
  final Value<String?> movedDate;
  final Value<int?> movedStartMin;
  final Value<int?> movedEndMin;
  final Value<String?> movedLocation;
  final Value<int> rowid;
  const SessionOverridesCompanion({
    this.id = const Value.absent(),
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.originalDate = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.recordingUrl = const Value.absent(),
    this.movedDate = const Value.absent(),
    this.movedStartMin = const Value.absent(),
    this.movedEndMin = const Value.absent(),
    this.movedLocation = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionOverridesCompanion.insert({
    required String id,
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    required String meetingId,
    required String originalDate,
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.recordingUrl = const Value.absent(),
    this.movedDate = const Value.absent(),
    this.movedStartMin = const Value.absent(),
    this.movedEndMin = const Value.absent(),
    this.movedLocation = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       meetingId = Value(meetingId),
       originalDate = Value(originalDate);
  static Insertable<SessionOverrideRow> custom({
    Expression<String>? id,
    Expression<bool>? deleted,
    Expression<int>? updatedAt,
    Expression<String>? meetingId,
    Expression<String>? originalDate,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<String>? recordingUrl,
    Expression<String>? movedDate,
    Expression<int>? movedStartMin,
    Expression<int>? movedEndMin,
    Expression<String>? movedLocation,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deleted != null) 'deleted': deleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (meetingId != null) 'meeting_id': meetingId,
      if (originalDate != null) 'original_date': originalDate,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (recordingUrl != null) 'recording_url': recordingUrl,
      if (movedDate != null) 'moved_date': movedDate,
      if (movedStartMin != null) 'moved_start_min': movedStartMin,
      if (movedEndMin != null) 'moved_end_min': movedEndMin,
      if (movedLocation != null) 'moved_location': movedLocation,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionOverridesCompanion copyWith({
    Value<String>? id,
    Value<bool>? deleted,
    Value<int>? updatedAt,
    Value<String>? meetingId,
    Value<String>? originalDate,
    Value<String?>? status,
    Value<String>? notes,
    Value<String?>? recordingUrl,
    Value<String?>? movedDate,
    Value<int?>? movedStartMin,
    Value<int?>? movedEndMin,
    Value<String?>? movedLocation,
    Value<int>? rowid,
  }) {
    return SessionOverridesCompanion(
      id: id ?? this.id,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
      meetingId: meetingId ?? this.meetingId,
      originalDate: originalDate ?? this.originalDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      movedDate: movedDate ?? this.movedDate,
      movedStartMin: movedStartMin ?? this.movedStartMin,
      movedEndMin: movedEndMin ?? this.movedEndMin,
      movedLocation: movedLocation ?? this.movedLocation,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (originalDate.present) {
      map['original_date'] = Variable<String>(originalDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (recordingUrl.present) {
      map['recording_url'] = Variable<String>(recordingUrl.value);
    }
    if (movedDate.present) {
      map['moved_date'] = Variable<String>(movedDate.value);
    }
    if (movedStartMin.present) {
      map['moved_start_min'] = Variable<int>(movedStartMin.value);
    }
    if (movedEndMin.present) {
      map['moved_end_min'] = Variable<int>(movedEndMin.value);
    }
    if (movedLocation.present) {
      map['moved_location'] = Variable<String>(movedLocation.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionOverridesCompanion(')
          ..write('id: $id, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('originalDate: $originalDate, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('recordingUrl: $recordingUrl, ')
          ..write('movedDate: $movedDate, ')
          ..write('movedStartMin: $movedStartMin, ')
          ..write('movedEndMin: $movedEndMin, ')
          ..write('movedLocation: $movedLocation, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoClassRangesTable extends NoClassRanges
    with TableInfo<$NoClassRangesTable, NoClassRangeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoClassRangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _semesterIdMeta = const VerificationMeta(
    'semesterId',
  );
  @override
  late final GeneratedColumn<String> semesterId = GeneratedColumn<String>(
    'semester_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<String> endDate = GeneratedColumn<String>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deleted,
    updatedAt,
    semesterId,
    startDate,
    endDate,
    label,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'no_class_ranges';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoClassRangeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('semester_id')) {
      context.handle(
        _semesterIdMeta,
        semesterId.isAcceptableOrUnknown(data['semester_id']!, _semesterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_semesterIdMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoClassRangeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoClassRangeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      semesterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semester_id'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
    );
  }

  @override
  $NoClassRangesTable createAlias(String alias) {
    return $NoClassRangesTable(attachedDatabase, alias);
  }
}

class NoClassRangeRow extends DataClass implements Insertable<NoClassRangeRow> {
  /// UUIDv7, or a deterministic id for session overrides.
  final String id;
  final bool deleted;

  /// Local wall-clock ms of the last change. Diagnostics only; sync ordering
  /// uses hybrid logical clocks in the outbox.
  final int updatedAt;
  final String semesterId;
  final String startDate;
  final String endDate;
  final String label;
  const NoClassRangeRow({
    required this.id,
    required this.deleted,
    required this.updatedAt,
    required this.semesterId,
    required this.startDate,
    required this.endDate,
    required this.label,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deleted'] = Variable<bool>(deleted);
    map['updated_at'] = Variable<int>(updatedAt);
    map['semester_id'] = Variable<String>(semesterId);
    map['start_date'] = Variable<String>(startDate);
    map['end_date'] = Variable<String>(endDate);
    map['label'] = Variable<String>(label);
    return map;
  }

  NoClassRangesCompanion toCompanion(bool nullToAbsent) {
    return NoClassRangesCompanion(
      id: Value(id),
      deleted: Value(deleted),
      updatedAt: Value(updatedAt),
      semesterId: Value(semesterId),
      startDate: Value(startDate),
      endDate: Value(endDate),
      label: Value(label),
    );
  }

  factory NoClassRangeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoClassRangeRow(
      id: serializer.fromJson<String>(json['id']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      semesterId: serializer.fromJson<String>(json['semesterId']),
      startDate: serializer.fromJson<String>(json['startDate']),
      endDate: serializer.fromJson<String>(json['endDate']),
      label: serializer.fromJson<String>(json['label']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deleted': serializer.toJson<bool>(deleted),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'semesterId': serializer.toJson<String>(semesterId),
      'startDate': serializer.toJson<String>(startDate),
      'endDate': serializer.toJson<String>(endDate),
      'label': serializer.toJson<String>(label),
    };
  }

  NoClassRangeRow copyWith({
    String? id,
    bool? deleted,
    int? updatedAt,
    String? semesterId,
    String? startDate,
    String? endDate,
    String? label,
  }) => NoClassRangeRow(
    id: id ?? this.id,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
    semesterId: semesterId ?? this.semesterId,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    label: label ?? this.label,
  );
  NoClassRangeRow copyWithCompanion(NoClassRangesCompanion data) {
    return NoClassRangeRow(
      id: data.id.present ? data.id.value : this.id,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      semesterId: data.semesterId.present
          ? data.semesterId.value
          : this.semesterId,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      label: data.label.present ? data.label.value : this.label,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoClassRangeRow(')
          ..write('id: $id, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('semesterId: $semesterId, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deleted,
    updatedAt,
    semesterId,
    startDate,
    endDate,
    label,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoClassRangeRow &&
          other.id == this.id &&
          other.deleted == this.deleted &&
          other.updatedAt == this.updatedAt &&
          other.semesterId == this.semesterId &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.label == this.label);
}

class NoClassRangesCompanion extends UpdateCompanion<NoClassRangeRow> {
  final Value<String> id;
  final Value<bool> deleted;
  final Value<int> updatedAt;
  final Value<String> semesterId;
  final Value<String> startDate;
  final Value<String> endDate;
  final Value<String> label;
  final Value<int> rowid;
  const NoClassRangesCompanion({
    this.id = const Value.absent(),
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.semesterId = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.label = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoClassRangesCompanion.insert({
    required String id,
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    required String semesterId,
    required String startDate,
    required String endDate,
    this.label = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       semesterId = Value(semesterId),
       startDate = Value(startDate),
       endDate = Value(endDate);
  static Insertable<NoClassRangeRow> custom({
    Expression<String>? id,
    Expression<bool>? deleted,
    Expression<int>? updatedAt,
    Expression<String>? semesterId,
    Expression<String>? startDate,
    Expression<String>? endDate,
    Expression<String>? label,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deleted != null) 'deleted': deleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (semesterId != null) 'semester_id': semesterId,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (label != null) 'label': label,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoClassRangesCompanion copyWith({
    Value<String>? id,
    Value<bool>? deleted,
    Value<int>? updatedAt,
    Value<String>? semesterId,
    Value<String>? startDate,
    Value<String>? endDate,
    Value<String>? label,
    Value<int>? rowid,
  }) {
    return NoClassRangesCompanion(
      id: id ?? this.id,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
      semesterId: semesterId ?? this.semesterId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      label: label ?? this.label,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (semesterId.present) {
      map['semester_id'] = Variable<String>(semesterId.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoClassRangesCompanion(')
          ..write('id: $id, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('semesterId: $semesterId, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('label: $label, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RequirementsTable extends Requirements
    with TableInfo<$RequirementsTable, RequirementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RequirementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minPercentMeta = const VerificationMeta(
    'minPercent',
  );
  @override
  late final GeneratedColumn<int> minPercent = GeneratedColumn<int>(
    'min_percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordingsCountMeta = const VerificationMeta(
    'recordingsCount',
  );
  @override
  late final GeneratedColumn<bool> recordingsCount = GeneratedColumn<bool>(
    'recordings_count',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("recordings_count" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deleted,
    updatedAt,
    courseId,
    type,
    minPercent,
    recordingsCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'requirements';
  @override
  VerificationContext validateIntegrity(
    Insertable<RequirementRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('min_percent')) {
      context.handle(
        _minPercentMeta,
        minPercent.isAcceptableOrUnknown(data['min_percent']!, _minPercentMeta),
      );
    } else if (isInserting) {
      context.missing(_minPercentMeta);
    }
    if (data.containsKey('recordings_count')) {
      context.handle(
        _recordingsCountMeta,
        recordingsCount.isAcceptableOrUnknown(
          data['recordings_count']!,
          _recordingsCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RequirementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RequirementRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      ),
      minPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_percent'],
      )!,
      recordingsCount: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}recordings_count'],
      )!,
    );
  }

  @override
  $RequirementsTable createAlias(String alias) {
    return $RequirementsTable(attachedDatabase, alias);
  }
}

class RequirementRow extends DataClass implements Insertable<RequirementRow> {
  /// UUIDv7, or a deterministic id for session overrides.
  final String id;
  final bool deleted;

  /// Local wall-clock ms of the last change. Diagnostics only; sync ordering
  /// uses hybrid logical clocks in the outbox.
  final int updatedAt;
  final String courseId;

  /// Session type key, or null for "all types".
  final String? type;
  final int minPercent;
  final bool recordingsCount;
  const RequirementRow({
    required this.id,
    required this.deleted,
    required this.updatedAt,
    required this.courseId,
    this.type,
    required this.minPercent,
    required this.recordingsCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deleted'] = Variable<bool>(deleted);
    map['updated_at'] = Variable<int>(updatedAt);
    map['course_id'] = Variable<String>(courseId);
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    map['min_percent'] = Variable<int>(minPercent);
    map['recordings_count'] = Variable<bool>(recordingsCount);
    return map;
  }

  RequirementsCompanion toCompanion(bool nullToAbsent) {
    return RequirementsCompanion(
      id: Value(id),
      deleted: Value(deleted),
      updatedAt: Value(updatedAt),
      courseId: Value(courseId),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      minPercent: Value(minPercent),
      recordingsCount: Value(recordingsCount),
    );
  }

  factory RequirementRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RequirementRow(
      id: serializer.fromJson<String>(json['id']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      courseId: serializer.fromJson<String>(json['courseId']),
      type: serializer.fromJson<String?>(json['type']),
      minPercent: serializer.fromJson<int>(json['minPercent']),
      recordingsCount: serializer.fromJson<bool>(json['recordingsCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deleted': serializer.toJson<bool>(deleted),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'courseId': serializer.toJson<String>(courseId),
      'type': serializer.toJson<String?>(type),
      'minPercent': serializer.toJson<int>(minPercent),
      'recordingsCount': serializer.toJson<bool>(recordingsCount),
    };
  }

  RequirementRow copyWith({
    String? id,
    bool? deleted,
    int? updatedAt,
    String? courseId,
    Value<String?> type = const Value.absent(),
    int? minPercent,
    bool? recordingsCount,
  }) => RequirementRow(
    id: id ?? this.id,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
    courseId: courseId ?? this.courseId,
    type: type.present ? type.value : this.type,
    minPercent: minPercent ?? this.minPercent,
    recordingsCount: recordingsCount ?? this.recordingsCount,
  );
  RequirementRow copyWithCompanion(RequirementsCompanion data) {
    return RequirementRow(
      id: data.id.present ? data.id.value : this.id,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      type: data.type.present ? data.type.value : this.type,
      minPercent: data.minPercent.present
          ? data.minPercent.value
          : this.minPercent,
      recordingsCount: data.recordingsCount.present
          ? data.recordingsCount.value
          : this.recordingsCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RequirementRow(')
          ..write('id: $id, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('courseId: $courseId, ')
          ..write('type: $type, ')
          ..write('minPercent: $minPercent, ')
          ..write('recordingsCount: $recordingsCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deleted,
    updatedAt,
    courseId,
    type,
    minPercent,
    recordingsCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RequirementRow &&
          other.id == this.id &&
          other.deleted == this.deleted &&
          other.updatedAt == this.updatedAt &&
          other.courseId == this.courseId &&
          other.type == this.type &&
          other.minPercent == this.minPercent &&
          other.recordingsCount == this.recordingsCount);
}

class RequirementsCompanion extends UpdateCompanion<RequirementRow> {
  final Value<String> id;
  final Value<bool> deleted;
  final Value<int> updatedAt;
  final Value<String> courseId;
  final Value<String?> type;
  final Value<int> minPercent;
  final Value<bool> recordingsCount;
  final Value<int> rowid;
  const RequirementsCompanion({
    this.id = const Value.absent(),
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.courseId = const Value.absent(),
    this.type = const Value.absent(),
    this.minPercent = const Value.absent(),
    this.recordingsCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RequirementsCompanion.insert({
    required String id,
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    required String courseId,
    this.type = const Value.absent(),
    required int minPercent,
    this.recordingsCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       courseId = Value(courseId),
       minPercent = Value(minPercent);
  static Insertable<RequirementRow> custom({
    Expression<String>? id,
    Expression<bool>? deleted,
    Expression<int>? updatedAt,
    Expression<String>? courseId,
    Expression<String>? type,
    Expression<int>? minPercent,
    Expression<bool>? recordingsCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deleted != null) 'deleted': deleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (courseId != null) 'course_id': courseId,
      if (type != null) 'type': type,
      if (minPercent != null) 'min_percent': minPercent,
      if (recordingsCount != null) 'recordings_count': recordingsCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RequirementsCompanion copyWith({
    Value<String>? id,
    Value<bool>? deleted,
    Value<int>? updatedAt,
    Value<String>? courseId,
    Value<String?>? type,
    Value<int>? minPercent,
    Value<bool>? recordingsCount,
    Value<int>? rowid,
  }) {
    return RequirementsCompanion(
      id: id ?? this.id,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
      courseId: courseId ?? this.courseId,
      type: type ?? this.type,
      minPercent: minPercent ?? this.minPercent,
      recordingsCount: recordingsCount ?? this.recordingsCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (minPercent.present) {
      map['min_percent'] = Variable<int>(minPercent.value);
    }
    if (recordingsCount.present) {
      map['recordings_count'] = Variable<bool>(recordingsCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RequirementsCompanion(')
          ..write('id: $id, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('courseId: $courseId, ')
          ..write('type: $type, ')
          ..write('minPercent: $minPercent, ')
          ..write('recordingsCount: $recordingsCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserSettingsTable extends UserSettings
    with TableInfo<$UserSettingsTable, UserSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _use24hMeta = const VerificationMeta('use24h');
  @override
  late final GeneratedColumn<bool> use24h = GeneratedColumn<bool>(
    'use24h',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use24h" IN (0, 1))',
    ),
  );
  static const VerificationMeta _meetingNumbersMeta = const VerificationMeta(
    'meetingNumbers',
  );
  @override
  late final GeneratedColumn<bool> meetingNumbers = GeneratedColumn<bool>(
    'meeting_numbers',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("meeting_numbers" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deleted,
    updatedAt,
    use24h,
    meetingNumbers,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserSettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('use24h')) {
      context.handle(
        _use24hMeta,
        use24h.isAcceptableOrUnknown(data['use24h']!, _use24hMeta),
      );
    }
    if (data.containsKey('meeting_numbers')) {
      context.handle(
        _meetingNumbersMeta,
        meetingNumbers.isAcceptableOrUnknown(
          data['meeting_numbers']!,
          _meetingNumbersMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserSettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserSettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      use24h: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use24h'],
      ),
      meetingNumbers: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}meeting_numbers'],
      )!,
    );
  }

  @override
  $UserSettingsTable createAlias(String alias) {
    return $UserSettingsTable(attachedDatabase, alias);
  }
}

class UserSettingsRow extends DataClass implements Insertable<UserSettingsRow> {
  /// UUIDv7, or a deterministic id for session overrides.
  final String id;
  final bool deleted;

  /// Local wall-clock ms of the last change. Diagnostics only; sync ordering
  /// uses hybrid logical clocks in the outbox.
  final int updatedAt;

  /// Null = follow the device's 24-hour setting.
  final bool? use24h;
  final bool meetingNumbers;
  const UserSettingsRow({
    required this.id,
    required this.deleted,
    required this.updatedAt,
    this.use24h,
    required this.meetingNumbers,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deleted'] = Variable<bool>(deleted);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || use24h != null) {
      map['use24h'] = Variable<bool>(use24h);
    }
    map['meeting_numbers'] = Variable<bool>(meetingNumbers);
    return map;
  }

  UserSettingsCompanion toCompanion(bool nullToAbsent) {
    return UserSettingsCompanion(
      id: Value(id),
      deleted: Value(deleted),
      updatedAt: Value(updatedAt),
      use24h: use24h == null && nullToAbsent
          ? const Value.absent()
          : Value(use24h),
      meetingNumbers: Value(meetingNumbers),
    );
  }

  factory UserSettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserSettingsRow(
      id: serializer.fromJson<String>(json['id']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      use24h: serializer.fromJson<bool?>(json['use24h']),
      meetingNumbers: serializer.fromJson<bool>(json['meetingNumbers']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deleted': serializer.toJson<bool>(deleted),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'use24h': serializer.toJson<bool?>(use24h),
      'meetingNumbers': serializer.toJson<bool>(meetingNumbers),
    };
  }

  UserSettingsRow copyWith({
    String? id,
    bool? deleted,
    int? updatedAt,
    Value<bool?> use24h = const Value.absent(),
    bool? meetingNumbers,
  }) => UserSettingsRow(
    id: id ?? this.id,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
    use24h: use24h.present ? use24h.value : this.use24h,
    meetingNumbers: meetingNumbers ?? this.meetingNumbers,
  );
  UserSettingsRow copyWithCompanion(UserSettingsCompanion data) {
    return UserSettingsRow(
      id: data.id.present ? data.id.value : this.id,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      use24h: data.use24h.present ? data.use24h.value : this.use24h,
      meetingNumbers: data.meetingNumbers.present
          ? data.meetingNumbers.value
          : this.meetingNumbers,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingsRow(')
          ..write('id: $id, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('use24h: $use24h, ')
          ..write('meetingNumbers: $meetingNumbers')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, deleted, updatedAt, use24h, meetingNumbers);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSettingsRow &&
          other.id == this.id &&
          other.deleted == this.deleted &&
          other.updatedAt == this.updatedAt &&
          other.use24h == this.use24h &&
          other.meetingNumbers == this.meetingNumbers);
}

class UserSettingsCompanion extends UpdateCompanion<UserSettingsRow> {
  final Value<String> id;
  final Value<bool> deleted;
  final Value<int> updatedAt;
  final Value<bool?> use24h;
  final Value<bool> meetingNumbers;
  final Value<int> rowid;
  const UserSettingsCompanion({
    this.id = const Value.absent(),
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.use24h = const Value.absent(),
    this.meetingNumbers = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserSettingsCompanion.insert({
    required String id,
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.use24h = const Value.absent(),
    this.meetingNumbers = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<UserSettingsRow> custom({
    Expression<String>? id,
    Expression<bool>? deleted,
    Expression<int>? updatedAt,
    Expression<bool>? use24h,
    Expression<bool>? meetingNumbers,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deleted != null) 'deleted': deleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (use24h != null) 'use24h': use24h,
      if (meetingNumbers != null) 'meeting_numbers': meetingNumbers,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserSettingsCompanion copyWith({
    Value<String>? id,
    Value<bool>? deleted,
    Value<int>? updatedAt,
    Value<bool?>? use24h,
    Value<bool>? meetingNumbers,
    Value<int>? rowid,
  }) {
    return UserSettingsCompanion(
      id: id ?? this.id,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
      use24h: use24h ?? this.use24h,
      meetingNumbers: meetingNumbers ?? this.meetingNumbers,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (use24h.present) {
      map['use24h'] = Variable<bool>(use24h.value);
    }
    if (meetingNumbers.present) {
      map['meeting_numbers'] = Variable<bool>(meetingNumbers.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingsCompanion(')
          ..write('id: $id, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('use24h: $use24h, ')
          ..write('meetingNumbers: $meetingNumbers, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tblMeta = const VerificationMeta('tbl');
  @override
  late final GeneratedColumn<String> tbl = GeneratedColumn<String>(
    'tbl',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patchMeta = const VerificationMeta('patch');
  @override
  late final GeneratedColumn<String> patch = GeneratedColumn<String>(
    'patch',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ifAbsentMeta = const VerificationMeta(
    'ifAbsent',
  );
  @override
  late final GeneratedColumn<bool> ifAbsent = GeneratedColumn<bool>(
    'if_absent',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("if_absent" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _rejectedMeta = const VerificationMeta(
    'rejected',
  );
  @override
  late final GeneratedColumn<String> rejected = GeneratedColumn<String>(
    'rejected',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    tbl,
    rowId,
    patch,
    hlc,
    ifAbsent,
    rejected,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('tbl')) {
      context.handle(
        _tblMeta,
        tbl.isAcceptableOrUnknown(data['tbl']!, _tblMeta),
      );
    } else if (isInserting) {
      context.missing(_tblMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('patch')) {
      context.handle(
        _patchMeta,
        patch.isAcceptableOrUnknown(data['patch']!, _patchMeta),
      );
    } else if (isInserting) {
      context.missing(_patchMeta);
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    if (data.containsKey('if_absent')) {
      context.handle(
        _ifAbsentMeta,
        ifAbsent.isAcceptableOrUnknown(data['if_absent']!, _ifAbsentMeta),
      );
    }
    if (data.containsKey('rejected')) {
      context.handle(
        _rejectedMeta,
        rejected.isAcceptableOrUnknown(data['rejected']!, _rejectedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      tbl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tbl'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      patch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}patch'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      ifAbsent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}if_absent'],
      )!,
      rejected: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rejected'],
      ),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  final int seq;
  final String tbl;
  final String rowId;

  /// JSON object with only the changed fields.
  final String patch;
  final String hlc;

  /// The server only fills fields it doesn't have yet (data joining an
  /// account, merged backups), so this can't overwrite newer edits.
  final bool ifAbsent;

  /// Why the server refused this change. Kept (not pushed) until retried, so
  /// the edit is never silently dropped.
  final String? rejected;
  const OutboxEntry({
    required this.seq,
    required this.tbl,
    required this.rowId,
    required this.patch,
    required this.hlc,
    required this.ifAbsent,
    this.rejected,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['tbl'] = Variable<String>(tbl);
    map['row_id'] = Variable<String>(rowId);
    map['patch'] = Variable<String>(patch);
    map['hlc'] = Variable<String>(hlc);
    map['if_absent'] = Variable<bool>(ifAbsent);
    if (!nullToAbsent || rejected != null) {
      map['rejected'] = Variable<String>(rejected);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      seq: Value(seq),
      tbl: Value(tbl),
      rowId: Value(rowId),
      patch: Value(patch),
      hlc: Value(hlc),
      ifAbsent: Value(ifAbsent),
      rejected: rejected == null && nullToAbsent
          ? const Value.absent()
          : Value(rejected),
    );
  }

  factory OutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      seq: serializer.fromJson<int>(json['seq']),
      tbl: serializer.fromJson<String>(json['tbl']),
      rowId: serializer.fromJson<String>(json['rowId']),
      patch: serializer.fromJson<String>(json['patch']),
      hlc: serializer.fromJson<String>(json['hlc']),
      ifAbsent: serializer.fromJson<bool>(json['ifAbsent']),
      rejected: serializer.fromJson<String?>(json['rejected']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'tbl': serializer.toJson<String>(tbl),
      'rowId': serializer.toJson<String>(rowId),
      'patch': serializer.toJson<String>(patch),
      'hlc': serializer.toJson<String>(hlc),
      'ifAbsent': serializer.toJson<bool>(ifAbsent),
      'rejected': serializer.toJson<String?>(rejected),
    };
  }

  OutboxEntry copyWith({
    int? seq,
    String? tbl,
    String? rowId,
    String? patch,
    String? hlc,
    bool? ifAbsent,
    Value<String?> rejected = const Value.absent(),
  }) => OutboxEntry(
    seq: seq ?? this.seq,
    tbl: tbl ?? this.tbl,
    rowId: rowId ?? this.rowId,
    patch: patch ?? this.patch,
    hlc: hlc ?? this.hlc,
    ifAbsent: ifAbsent ?? this.ifAbsent,
    rejected: rejected.present ? rejected.value : this.rejected,
  );
  OutboxEntry copyWithCompanion(OutboxCompanion data) {
    return OutboxEntry(
      seq: data.seq.present ? data.seq.value : this.seq,
      tbl: data.tbl.present ? data.tbl.value : this.tbl,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      patch: data.patch.present ? data.patch.value : this.patch,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      ifAbsent: data.ifAbsent.present ? data.ifAbsent.value : this.ifAbsent,
      rejected: data.rejected.present ? data.rejected.value : this.rejected,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('seq: $seq, ')
          ..write('tbl: $tbl, ')
          ..write('rowId: $rowId, ')
          ..write('patch: $patch, ')
          ..write('hlc: $hlc, ')
          ..write('ifAbsent: $ifAbsent, ')
          ..write('rejected: $rejected')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(seq, tbl, rowId, patch, hlc, ifAbsent, rejected);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.seq == this.seq &&
          other.tbl == this.tbl &&
          other.rowId == this.rowId &&
          other.patch == this.patch &&
          other.hlc == this.hlc &&
          other.ifAbsent == this.ifAbsent &&
          other.rejected == this.rejected);
}

class OutboxCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<int> seq;
  final Value<String> tbl;
  final Value<String> rowId;
  final Value<String> patch;
  final Value<String> hlc;
  final Value<bool> ifAbsent;
  final Value<String?> rejected;
  const OutboxCompanion({
    this.seq = const Value.absent(),
    this.tbl = const Value.absent(),
    this.rowId = const Value.absent(),
    this.patch = const Value.absent(),
    this.hlc = const Value.absent(),
    this.ifAbsent = const Value.absent(),
    this.rejected = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String tbl,
    required String rowId,
    required String patch,
    required String hlc,
    this.ifAbsent = const Value.absent(),
    this.rejected = const Value.absent(),
  }) : tbl = Value(tbl),
       rowId = Value(rowId),
       patch = Value(patch),
       hlc = Value(hlc);
  static Insertable<OutboxEntry> custom({
    Expression<int>? seq,
    Expression<String>? tbl,
    Expression<String>? rowId,
    Expression<String>? patch,
    Expression<String>? hlc,
    Expression<bool>? ifAbsent,
    Expression<String>? rejected,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (tbl != null) 'tbl': tbl,
      if (rowId != null) 'row_id': rowId,
      if (patch != null) 'patch': patch,
      if (hlc != null) 'hlc': hlc,
      if (ifAbsent != null) 'if_absent': ifAbsent,
      if (rejected != null) 'rejected': rejected,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? seq,
    Value<String>? tbl,
    Value<String>? rowId,
    Value<String>? patch,
    Value<String>? hlc,
    Value<bool>? ifAbsent,
    Value<String?>? rejected,
  }) {
    return OutboxCompanion(
      seq: seq ?? this.seq,
      tbl: tbl ?? this.tbl,
      rowId: rowId ?? this.rowId,
      patch: patch ?? this.patch,
      hlc: hlc ?? this.hlc,
      ifAbsent: ifAbsent ?? this.ifAbsent,
      rejected: rejected ?? this.rejected,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (tbl.present) {
      map['tbl'] = Variable<String>(tbl.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (patch.present) {
      map['patch'] = Variable<String>(patch.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (ifAbsent.present) {
      map['if_absent'] = Variable<bool>(ifAbsent.value);
    }
    if (rejected.present) {
      map['rejected'] = Variable<String>(rejected.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('tbl: $tbl, ')
          ..write('rowId: $rowId, ')
          ..write('patch: $patch, ')
          ..write('hlc: $hlc, ')
          ..write('ifAbsent: $ifAbsent, ')
          ..write('rejected: $rejected')
          ..write(')'))
        .toString();
  }
}

class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetaEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetaEntry extends DataClass implements Insertable<SyncMetaEntry> {
  final String key;
  final String value;
  const SyncMetaEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(key: Value(key), value: Value(value));
  }

  factory SyncMetaEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncMetaEntry copyWith({String? key, String? value}) =>
      SyncMetaEntry(key: key ?? this.key, value: value ?? this.value);
  SyncMetaEntry copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncMetaEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SemestersTable semesters = $SemestersTable(this);
  late final $CoursesTable courses = $CoursesTable(this);
  late final $MeetingsTable meetings = $MeetingsTable(this);
  late final $SessionOverridesTable sessionOverrides = $SessionOverridesTable(
    this,
  );
  late final $NoClassRangesTable noClassRanges = $NoClassRangesTable(this);
  late final $RequirementsTable requirements = $RequirementsTable(this);
  late final $UserSettingsTable userSettings = $UserSettingsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  late final Index coursesSemester = Index(
    'courses_semester',
    'CREATE INDEX courses_semester ON courses (semester_id)',
  );
  late final Index meetingsCourse = Index(
    'meetings_course',
    'CREATE INDEX meetings_course ON meetings (course_id)',
  );
  late final Index overridesMeeting = Index(
    'overrides_meeting',
    'CREATE INDEX overrides_meeting ON session_overrides (meeting_id)',
  );
  late final Index noclassSemester = Index(
    'noclass_semester',
    'CREATE INDEX noclass_semester ON no_class_ranges (semester_id)',
  );
  late final Index requirementsCourse = Index(
    'requirements_course',
    'CREATE INDEX requirements_course ON requirements (course_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    semesters,
    courses,
    meetings,
    sessionOverrides,
    noClassRanges,
    requirements,
    userSettings,
    outbox,
    syncMeta,
    coursesSemester,
    meetingsCourse,
    overridesMeeting,
    noclassSemester,
    requirementsCourse,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$SemestersTableCreateCompanionBuilder = SemestersCompanion Function({
  required String id,
  Value<bool> deleted,
  Value<int> updatedAt,
  required String name,
  required String startDate,
  required String endDate,
  Value<int> weekStart,
  Value<int> visibleDays,
  Value<int> rowid,
});
typedef $$SemestersTableUpdateCompanionBuilder = SemestersCompanion Function({
  Value<String> id,
  Value<bool> deleted,
  Value<int> updatedAt,
  Value<String> name,
  Value<String> startDate,
  Value<String> endDate,
  Value<int> weekStart,
  Value<int> visibleDays,
  Value<int> rowid,
});

class $$SemestersTableFilterComposer
    extends Composer<_$AppDatabase, $SemestersTable> {
  $$SemestersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekStart => $composableBuilder(
    column: $table.weekStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get visibleDays => $composableBuilder(
    column: $table.visibleDays,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SemestersTableOrderingComposer
    extends Composer<_$AppDatabase, $SemestersTable> {
  $$SemestersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekStart => $composableBuilder(
    column: $table.weekStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get visibleDays => $composableBuilder(
    column: $table.visibleDays,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SemestersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SemestersTable> {
  $$SemestersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get weekStart =>
      $composableBuilder(column: $table.weekStart, builder: (column) => column);

  GeneratedColumn<int> get visibleDays => $composableBuilder(
    column: $table.visibleDays,
    builder: (column) => column,
  );
}

class $$SemestersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SemestersTable,
          SemesterRow,
          $$SemestersTableFilterComposer,
          $$SemestersTableOrderingComposer,
          $$SemestersTableAnnotationComposer,
          $$SemestersTableCreateCompanionBuilder,
          $$SemestersTableUpdateCompanionBuilder,
          (
            SemesterRow,
            BaseReferences<_$AppDatabase, $SemestersTable, SemesterRow>,
          ),
          SemesterRow,
          PrefetchHooks Function()
        > {
  $$SemestersTableTableManager(_$AppDatabase db, $SemestersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SemestersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SemestersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SemestersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<String> endDate = const Value.absent(),
                Value<int> weekStart = const Value.absent(),
                Value<int> visibleDays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SemestersCompanion(
                id: id,
                deleted: deleted,
                updatedAt: updatedAt,
                name: name,
                startDate: startDate,
                endDate: endDate,
                weekStart: weekStart,
                visibleDays: visibleDays,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<bool> deleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                required String name,
                required String startDate,
                required String endDate,
                Value<int> weekStart = const Value.absent(),
                Value<int> visibleDays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SemestersCompanion.insert(
                id: id,
                deleted: deleted,
                updatedAt: updatedAt,
                name: name,
                startDate: startDate,
                endDate: endDate,
                weekStart: weekStart,
                visibleDays: visibleDays,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SemestersTable, SemesterRow>(table),
                  BaseReferences<_$AppDatabase, $SemestersTable, SemesterRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SemestersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SemestersTable,
      SemesterRow,
      $$SemestersTableFilterComposer,
      $$SemestersTableOrderingComposer,
      $$SemestersTableAnnotationComposer,
      $$SemestersTableCreateCompanionBuilder,
      $$SemestersTableUpdateCompanionBuilder,
      (
        SemesterRow,
        BaseReferences<_$AppDatabase, $SemestersTable, SemesterRow>,
      ),
      SemesterRow,
      PrefetchHooks Function()
    >;
typedef $$CoursesTableCreateCompanionBuilder = CoursesCompanion Function({
  required String id,
  Value<bool> deleted,
  Value<int> updatedAt,
  required String semesterId,
  required String name,
  Value<String> code,
  Value<String> lecturer,
  Value<String> colorKey,
  Value<String> website,
  Value<String> notes,
  Value<String> links,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$CoursesTableUpdateCompanionBuilder = CoursesCompanion Function({
  Value<String> id,
  Value<bool> deleted,
  Value<int> updatedAt,
  Value<String> semesterId,
  Value<String> name,
  Value<String> code,
  Value<String> lecturer,
  Value<String> colorKey,
  Value<String> website,
  Value<String> notes,
  Value<String> links,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$CoursesTableFilterComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semesterId => $composableBuilder(
    column: $table.semesterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lecturer => $composableBuilder(
    column: $table.lecturer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorKey => $composableBuilder(
    column: $table.colorKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get website => $composableBuilder(
    column: $table.website,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get links => $composableBuilder(
    column: $table.links,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CoursesTableOrderingComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semesterId => $composableBuilder(
    column: $table.semesterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lecturer => $composableBuilder(
    column: $table.lecturer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorKey => $composableBuilder(
    column: $table.colorKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get website => $composableBuilder(
    column: $table.website,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get links => $composableBuilder(
    column: $table.links,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoursesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get semesterId => $composableBuilder(
    column: $table.semesterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get lecturer =>
      $composableBuilder(column: $table.lecturer, builder: (column) => column);

  GeneratedColumn<String> get colorKey =>
      $composableBuilder(column: $table.colorKey, builder: (column) => column);

  GeneratedColumn<String> get website =>
      $composableBuilder(column: $table.website, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get links =>
      $composableBuilder(column: $table.links, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$CoursesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoursesTable,
          CourseRow,
          $$CoursesTableFilterComposer,
          $$CoursesTableOrderingComposer,
          $$CoursesTableAnnotationComposer,
          $$CoursesTableCreateCompanionBuilder,
          $$CoursesTableUpdateCompanionBuilder,
          (CourseRow, BaseReferences<_$AppDatabase, $CoursesTable, CourseRow>),
          CourseRow,
          PrefetchHooks Function()
        > {
  $$CoursesTableTableManager(_$AppDatabase db, $CoursesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoursesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoursesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoursesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> semesterId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> lecturer = const Value.absent(),
                Value<String> colorKey = const Value.absent(),
                Value<String> website = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> links = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoursesCompanion(
                id: id,
                deleted: deleted,
                updatedAt: updatedAt,
                semesterId: semesterId,
                name: name,
                code: code,
                lecturer: lecturer,
                colorKey: colorKey,
                website: website,
                notes: notes,
                links: links,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<bool> deleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                required String semesterId,
                required String name,
                Value<String> code = const Value.absent(),
                Value<String> lecturer = const Value.absent(),
                Value<String> colorKey = const Value.absent(),
                Value<String> website = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> links = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoursesCompanion.insert(
                id: id,
                deleted: deleted,
                updatedAt: updatedAt,
                semesterId: semesterId,
                name: name,
                code: code,
                lecturer: lecturer,
                colorKey: colorKey,
                website: website,
                notes: notes,
                links: links,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CoursesTable, CourseRow>(table),
                  BaseReferences<_$AppDatabase, $CoursesTable, CourseRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CoursesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoursesTable,
      CourseRow,
      $$CoursesTableFilterComposer,
      $$CoursesTableOrderingComposer,
      $$CoursesTableAnnotationComposer,
      $$CoursesTableCreateCompanionBuilder,
      $$CoursesTableUpdateCompanionBuilder,
      (CourseRow, BaseReferences<_$AppDatabase, $CoursesTable, CourseRow>),
      CourseRow,
      PrefetchHooks Function()
    >;
typedef $$MeetingsTableCreateCompanionBuilder = MeetingsCompanion Function({
  required String id,
  Value<bool> deleted,
  Value<int> updatedAt,
  required String courseId,
  Value<String> type,
  Value<String> kind,
  Value<int?> weekday,
  Value<String?> date,
  required int startMin,
  required int endMin,
  Value<String> location,
  Value<int> intervalWeeks,
  Value<String?> validFrom,
  Value<String?> validUntil,
  Value<String> links,
  Value<int> rowid,
});
typedef $$MeetingsTableUpdateCompanionBuilder = MeetingsCompanion Function({
  Value<String> id,
  Value<bool> deleted,
  Value<int> updatedAt,
  Value<String> courseId,
  Value<String> type,
  Value<String> kind,
  Value<int?> weekday,
  Value<String?> date,
  Value<int> startMin,
  Value<int> endMin,
  Value<String> location,
  Value<int> intervalWeeks,
  Value<String?> validFrom,
  Value<String?> validUntil,
  Value<String> links,
  Value<int> rowid,
});

class $$MeetingsTableFilterComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMin => $composableBuilder(
    column: $table.startMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMin => $composableBuilder(
    column: $table.endMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalWeeks => $composableBuilder(
    column: $table.intervalWeeks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get validFrom => $composableBuilder(
    column: $table.validFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get validUntil => $composableBuilder(
    column: $table.validUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get links => $composableBuilder(
    column: $table.links,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MeetingsTableOrderingComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMin => $composableBuilder(
    column: $table.startMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMin => $composableBuilder(
    column: $table.endMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalWeeks => $composableBuilder(
    column: $table.intervalWeeks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get validFrom => $composableBuilder(
    column: $table.validFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get validUntil => $composableBuilder(
    column: $table.validUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get links => $composableBuilder(
    column: $table.links,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MeetingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get weekday =>
      $composableBuilder(column: $table.weekday, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get startMin =>
      $composableBuilder(column: $table.startMin, builder: (column) => column);

  GeneratedColumn<int> get endMin =>
      $composableBuilder(column: $table.endMin, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<int> get intervalWeeks => $composableBuilder(
    column: $table.intervalWeeks,
    builder: (column) => column,
  );

  GeneratedColumn<String> get validFrom =>
      $composableBuilder(column: $table.validFrom, builder: (column) => column);

  GeneratedColumn<String> get validUntil => $composableBuilder(
    column: $table.validUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get links =>
      $composableBuilder(column: $table.links, builder: (column) => column);
}

class $$MeetingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MeetingsTable,
          MeetingRow,
          $$MeetingsTableFilterComposer,
          $$MeetingsTableOrderingComposer,
          $$MeetingsTableAnnotationComposer,
          $$MeetingsTableCreateCompanionBuilder,
          $$MeetingsTableUpdateCompanionBuilder,
          (
            MeetingRow,
            BaseReferences<_$AppDatabase, $MeetingsTable, MeetingRow>,
          ),
          MeetingRow,
          PrefetchHooks Function()
        > {
  $$MeetingsTableTableManager(_$AppDatabase db, $MeetingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeetingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MeetingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MeetingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int?> weekday = const Value.absent(),
                Value<String?> date = const Value.absent(),
                Value<int> startMin = const Value.absent(),
                Value<int> endMin = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<int> intervalWeeks = const Value.absent(),
                Value<String?> validFrom = const Value.absent(),
                Value<String?> validUntil = const Value.absent(),
                Value<String> links = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeetingsCompanion(
                id: id,
                deleted: deleted,
                updatedAt: updatedAt,
                courseId: courseId,
                type: type,
                kind: kind,
                weekday: weekday,
                date: date,
                startMin: startMin,
                endMin: endMin,
                location: location,
                intervalWeeks: intervalWeeks,
                validFrom: validFrom,
                validUntil: validUntil,
                links: links,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<bool> deleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                required String courseId,
                Value<String> type = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int?> weekday = const Value.absent(),
                Value<String?> date = const Value.absent(),
                required int startMin,
                required int endMin,
                Value<String> location = const Value.absent(),
                Value<int> intervalWeeks = const Value.absent(),
                Value<String?> validFrom = const Value.absent(),
                Value<String?> validUntil = const Value.absent(),
                Value<String> links = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeetingsCompanion.insert(
                id: id,
                deleted: deleted,
                updatedAt: updatedAt,
                courseId: courseId,
                type: type,
                kind: kind,
                weekday: weekday,
                date: date,
                startMin: startMin,
                endMin: endMin,
                location: location,
                intervalWeeks: intervalWeeks,
                validFrom: validFrom,
                validUntil: validUntil,
                links: links,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MeetingsTable, MeetingRow>(table),
                  BaseReferences<_$AppDatabase, $MeetingsTable, MeetingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MeetingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MeetingsTable,
      MeetingRow,
      $$MeetingsTableFilterComposer,
      $$MeetingsTableOrderingComposer,
      $$MeetingsTableAnnotationComposer,
      $$MeetingsTableCreateCompanionBuilder,
      $$MeetingsTableUpdateCompanionBuilder,
      (MeetingRow, BaseReferences<_$AppDatabase, $MeetingsTable, MeetingRow>),
      MeetingRow,
      PrefetchHooks Function()
    >;
typedef $$SessionOverridesTableCreateCompanionBuilder =
    SessionOverridesCompanion Function({
      required String id,
      Value<bool> deleted,
      Value<int> updatedAt,
      required String meetingId,
      required String originalDate,
      Value<String?> status,
      Value<String> notes,
      Value<String?> recordingUrl,
      Value<String?> movedDate,
      Value<int?> movedStartMin,
      Value<int?> movedEndMin,
      Value<String?> movedLocation,
      Value<int> rowid,
    });
typedef $$SessionOverridesTableUpdateCompanionBuilder =
    SessionOverridesCompanion Function({
      Value<String> id,
      Value<bool> deleted,
      Value<int> updatedAt,
      Value<String> meetingId,
      Value<String> originalDate,
      Value<String?> status,
      Value<String> notes,
      Value<String?> recordingUrl,
      Value<String?> movedDate,
      Value<int?> movedStartMin,
      Value<int?> movedEndMin,
      Value<String?> movedLocation,
      Value<int> rowid,
    });

class $$SessionOverridesTableFilterComposer
    extends Composer<_$AppDatabase, $SessionOverridesTable> {
  $$SessionOverridesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalDate => $composableBuilder(
    column: $table.originalDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordingUrl => $composableBuilder(
    column: $table.recordingUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get movedDate => $composableBuilder(
    column: $table.movedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get movedStartMin => $composableBuilder(
    column: $table.movedStartMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get movedEndMin => $composableBuilder(
    column: $table.movedEndMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get movedLocation => $composableBuilder(
    column: $table.movedLocation,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionOverridesTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionOverridesTable> {
  $$SessionOverridesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalDate => $composableBuilder(
    column: $table.originalDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordingUrl => $composableBuilder(
    column: $table.recordingUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get movedDate => $composableBuilder(
    column: $table.movedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get movedStartMin => $composableBuilder(
    column: $table.movedStartMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get movedEndMin => $composableBuilder(
    column: $table.movedEndMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get movedLocation => $composableBuilder(
    column: $table.movedLocation,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionOverridesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionOverridesTable> {
  $$SessionOverridesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get meetingId =>
      $composableBuilder(column: $table.meetingId, builder: (column) => column);

  GeneratedColumn<String> get originalDate => $composableBuilder(
    column: $table.originalDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get recordingUrl => $composableBuilder(
    column: $table.recordingUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get movedDate =>
      $composableBuilder(column: $table.movedDate, builder: (column) => column);

  GeneratedColumn<int> get movedStartMin => $composableBuilder(
    column: $table.movedStartMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get movedEndMin => $composableBuilder(
    column: $table.movedEndMin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get movedLocation => $composableBuilder(
    column: $table.movedLocation,
    builder: (column) => column,
  );
}

class $$SessionOverridesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionOverridesTable,
          SessionOverrideRow,
          $$SessionOverridesTableFilterComposer,
          $$SessionOverridesTableOrderingComposer,
          $$SessionOverridesTableAnnotationComposer,
          $$SessionOverridesTableCreateCompanionBuilder,
          $$SessionOverridesTableUpdateCompanionBuilder,
          (
            SessionOverrideRow,
            BaseReferences<
              _$AppDatabase,
              $SessionOverridesTable,
              SessionOverrideRow
            >,
          ),
          SessionOverrideRow,
          PrefetchHooks Function()
        > {
  $$SessionOverridesTableTableManager(
    _$AppDatabase db,
    $SessionOverridesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionOverridesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionOverridesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionOverridesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> originalDate = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String?> recordingUrl = const Value.absent(),
                Value<String?> movedDate = const Value.absent(),
                Value<int?> movedStartMin = const Value.absent(),
                Value<int?> movedEndMin = const Value.absent(),
                Value<String?> movedLocation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionOverridesCompanion(
                id: id,
                deleted: deleted,
                updatedAt: updatedAt,
                meetingId: meetingId,
                originalDate: originalDate,
                status: status,
                notes: notes,
                recordingUrl: recordingUrl,
                movedDate: movedDate,
                movedStartMin: movedStartMin,
                movedEndMin: movedEndMin,
                movedLocation: movedLocation,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<bool> deleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                required String meetingId,
                required String originalDate,
                Value<String?> status = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String?> recordingUrl = const Value.absent(),
                Value<String?> movedDate = const Value.absent(),
                Value<int?> movedStartMin = const Value.absent(),
                Value<int?> movedEndMin = const Value.absent(),
                Value<String?> movedLocation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionOverridesCompanion.insert(
                id: id,
                deleted: deleted,
                updatedAt: updatedAt,
                meetingId: meetingId,
                originalDate: originalDate,
                status: status,
                notes: notes,
                recordingUrl: recordingUrl,
                movedDate: movedDate,
                movedStartMin: movedStartMin,
                movedEndMin: movedEndMin,
                movedLocation: movedLocation,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionOverridesTable, SessionOverrideRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $SessionOverridesTable,
                    SessionOverrideRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionOverridesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionOverridesTable,
      SessionOverrideRow,
      $$SessionOverridesTableFilterComposer,
      $$SessionOverridesTableOrderingComposer,
      $$SessionOverridesTableAnnotationComposer,
      $$SessionOverridesTableCreateCompanionBuilder,
      $$SessionOverridesTableUpdateCompanionBuilder,
      (
        SessionOverrideRow,
        BaseReferences<
          _$AppDatabase,
          $SessionOverridesTable,
          SessionOverrideRow
        >,
      ),
      SessionOverrideRow,
      PrefetchHooks Function()
    >;
typedef $$NoClassRangesTableCreateCompanionBuilder =
    NoClassRangesCompanion Function({
      required String id,
      Value<bool> deleted,
      Value<int> updatedAt,
      required String semesterId,
      required String startDate,
      required String endDate,
      Value<String> label,
      Value<int> rowid,
    });
typedef $$NoClassRangesTableUpdateCompanionBuilder =
    NoClassRangesCompanion Function({
      Value<String> id,
      Value<bool> deleted,
      Value<int> updatedAt,
      Value<String> semesterId,
      Value<String> startDate,
      Value<String> endDate,
      Value<String> label,
      Value<int> rowid,
    });

class $$NoClassRangesTableFilterComposer
    extends Composer<_$AppDatabase, $NoClassRangesTable> {
  $$NoClassRangesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semesterId => $composableBuilder(
    column: $table.semesterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoClassRangesTableOrderingComposer
    extends Composer<_$AppDatabase, $NoClassRangesTable> {
  $$NoClassRangesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semesterId => $composableBuilder(
    column: $table.semesterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoClassRangesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoClassRangesTable> {
  $$NoClassRangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get semesterId => $composableBuilder(
    column: $table.semesterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);
}

class $$NoClassRangesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoClassRangesTable,
          NoClassRangeRow,
          $$NoClassRangesTableFilterComposer,
          $$NoClassRangesTableOrderingComposer,
          $$NoClassRangesTableAnnotationComposer,
          $$NoClassRangesTableCreateCompanionBuilder,
          $$NoClassRangesTableUpdateCompanionBuilder,
          (
            NoClassRangeRow,
            BaseReferences<_$AppDatabase, $NoClassRangesTable, NoClassRangeRow>,
          ),
          NoClassRangeRow,
          PrefetchHooks Function()
        > {
  $$NoClassRangesTableTableManager(_$AppDatabase db, $NoClassRangesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoClassRangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoClassRangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoClassRangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> semesterId = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<String> endDate = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoClassRangesCompanion(
                id: id,
                deleted: deleted,
                updatedAt: updatedAt,
                semesterId: semesterId,
                startDate: startDate,
                endDate: endDate,
                label: label,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<bool> deleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                required String semesterId,
                required String startDate,
                required String endDate,
                Value<String> label = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoClassRangesCompanion.insert(
                id: id,
                deleted: deleted,
                updatedAt: updatedAt,
                semesterId: semesterId,
                startDate: startDate,
                endDate: endDate,
                label: label,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoClassRangesTable, NoClassRangeRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $NoClassRangesTable,
                    NoClassRangeRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoClassRangesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoClassRangesTable,
      NoClassRangeRow,
      $$NoClassRangesTableFilterComposer,
      $$NoClassRangesTableOrderingComposer,
      $$NoClassRangesTableAnnotationComposer,
      $$NoClassRangesTableCreateCompanionBuilder,
      $$NoClassRangesTableUpdateCompanionBuilder,
      (
        NoClassRangeRow,
        BaseReferences<_$AppDatabase, $NoClassRangesTable, NoClassRangeRow>,
      ),
      NoClassRangeRow,
      PrefetchHooks Function()
    >;
typedef $$RequirementsTableCreateCompanionBuilder =
    RequirementsCompanion Function({
      required String id,
      Value<bool> deleted,
      Value<int> updatedAt,
      required String courseId,
      Value<String?> type,
      required int minPercent,
      Value<bool> recordingsCount,
      Value<int> rowid,
    });
typedef $$RequirementsTableUpdateCompanionBuilder =
    RequirementsCompanion Function({
      Value<String> id,
      Value<bool> deleted,
      Value<int> updatedAt,
      Value<String> courseId,
      Value<String?> type,
      Value<int> minPercent,
      Value<bool> recordingsCount,
      Value<int> rowid,
    });

class $$RequirementsTableFilterComposer
    extends Composer<_$AppDatabase, $RequirementsTable> {
  $$RequirementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minPercent => $composableBuilder(
    column: $table.minPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get recordingsCount => $composableBuilder(
    column: $table.recordingsCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RequirementsTableOrderingComposer
    extends Composer<_$AppDatabase, $RequirementsTable> {
  $$RequirementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minPercent => $composableBuilder(
    column: $table.minPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get recordingsCount => $composableBuilder(
    column: $table.recordingsCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RequirementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RequirementsTable> {
  $$RequirementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get minPercent => $composableBuilder(
    column: $table.minPercent,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get recordingsCount => $composableBuilder(
    column: $table.recordingsCount,
    builder: (column) => column,
  );
}

class $$RequirementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RequirementsTable,
          RequirementRow,
          $$RequirementsTableFilterComposer,
          $$RequirementsTableOrderingComposer,
          $$RequirementsTableAnnotationComposer,
          $$RequirementsTableCreateCompanionBuilder,
          $$RequirementsTableUpdateCompanionBuilder,
          (
            RequirementRow,
            BaseReferences<_$AppDatabase, $RequirementsTable, RequirementRow>,
          ),
          RequirementRow,
          PrefetchHooks Function()
        > {
  $$RequirementsTableTableManager(_$AppDatabase db, $RequirementsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RequirementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RequirementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RequirementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<int> minPercent = const Value.absent(),
                Value<bool> recordingsCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RequirementsCompanion(
                id: id,
                deleted: deleted,
                updatedAt: updatedAt,
                courseId: courseId,
                type: type,
                minPercent: minPercent,
                recordingsCount: recordingsCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<bool> deleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                required String courseId,
                Value<String?> type = const Value.absent(),
                required int minPercent,
                Value<bool> recordingsCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RequirementsCompanion.insert(
                id: id,
                deleted: deleted,
                updatedAt: updatedAt,
                courseId: courseId,
                type: type,
                minPercent: minPercent,
                recordingsCount: recordingsCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RequirementsTable, RequirementRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RequirementsTable,
                    RequirementRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RequirementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RequirementsTable,
      RequirementRow,
      $$RequirementsTableFilterComposer,
      $$RequirementsTableOrderingComposer,
      $$RequirementsTableAnnotationComposer,
      $$RequirementsTableCreateCompanionBuilder,
      $$RequirementsTableUpdateCompanionBuilder,
      (
        RequirementRow,
        BaseReferences<_$AppDatabase, $RequirementsTable, RequirementRow>,
      ),
      RequirementRow,
      PrefetchHooks Function()
    >;
typedef $$UserSettingsTableCreateCompanionBuilder =
    UserSettingsCompanion Function({
      required String id,
      Value<bool> deleted,
      Value<int> updatedAt,
      Value<bool?> use24h,
      Value<bool> meetingNumbers,
      Value<int> rowid,
    });
typedef $$UserSettingsTableUpdateCompanionBuilder =
    UserSettingsCompanion Function({
      Value<String> id,
      Value<bool> deleted,
      Value<int> updatedAt,
      Value<bool?> use24h,
      Value<bool> meetingNumbers,
      Value<int> rowid,
    });

class $$UserSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get use24h => $composableBuilder(
    column: $table.use24h,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get meetingNumbers => $composableBuilder(
    column: $table.meetingNumbers,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get use24h => $composableBuilder(
    column: $table.use24h,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get meetingNumbers => $composableBuilder(
    column: $table.meetingNumbers,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get use24h =>
      $composableBuilder(column: $table.use24h, builder: (column) => column);

  GeneratedColumn<bool> get meetingNumbers => $composableBuilder(
    column: $table.meetingNumbers,
    builder: (column) => column,
  );
}

class $$UserSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserSettingsTable,
          UserSettingsRow,
          $$UserSettingsTableFilterComposer,
          $$UserSettingsTableOrderingComposer,
          $$UserSettingsTableAnnotationComposer,
          $$UserSettingsTableCreateCompanionBuilder,
          $$UserSettingsTableUpdateCompanionBuilder,
          (
            UserSettingsRow,
            BaseReferences<_$AppDatabase, $UserSettingsTable, UserSettingsRow>,
          ),
          UserSettingsRow,
          PrefetchHooks Function()
        > {
  $$UserSettingsTableTableManager(_$AppDatabase db, $UserSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool?> use24h = const Value.absent(),
                Value<bool> meetingNumbers = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserSettingsCompanion(
                id: id,
                deleted: deleted,
                updatedAt: updatedAt,
                use24h: use24h,
                meetingNumbers: meetingNumbers,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<bool> deleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool?> use24h = const Value.absent(),
                Value<bool> meetingNumbers = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserSettingsCompanion.insert(
                id: id,
                deleted: deleted,
                updatedAt: updatedAt,
                use24h: use24h,
                meetingNumbers: meetingNumbers,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserSettingsTable, UserSettingsRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $UserSettingsTable,
                    UserSettingsRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserSettingsTable,
      UserSettingsRow,
      $$UserSettingsTableFilterComposer,
      $$UserSettingsTableOrderingComposer,
      $$UserSettingsTableAnnotationComposer,
      $$UserSettingsTableCreateCompanionBuilder,
      $$UserSettingsTableUpdateCompanionBuilder,
      (
        UserSettingsRow,
        BaseReferences<_$AppDatabase, $UserSettingsTable, UserSettingsRow>,
      ),
      UserSettingsRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  required String tbl,
  required String rowId,
  required String patch,
  required String hlc,
  Value<bool> ifAbsent,
  Value<String?> rejected,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  Value<String> tbl,
  Value<String> rowId,
  Value<String> patch,
  Value<String> hlc,
  Value<bool> ifAbsent,
  Value<String?> rejected,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tbl => $composableBuilder(
    column: $table.tbl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get patch => $composableBuilder(
    column: $table.patch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ifAbsent => $composableBuilder(
    column: $table.ifAbsent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rejected => $composableBuilder(
    column: $table.rejected,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tbl => $composableBuilder(
    column: $table.tbl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get patch => $composableBuilder(
    column: $table.patch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ifAbsent => $composableBuilder(
    column: $table.ifAbsent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rejected => $composableBuilder(
    column: $table.rejected,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get tbl =>
      $composableBuilder(column: $table.tbl, builder: (column) => column);

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get patch =>
      $composableBuilder(column: $table.patch, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<bool> get ifAbsent =>
      $composableBuilder(column: $table.ifAbsent, builder: (column) => column);

  GeneratedColumn<String> get rejected =>
      $composableBuilder(column: $table.rejected, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxEntry,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (
            OutboxEntry,
            BaseReferences<_$AppDatabase, $OutboxTable, OutboxEntry>,
          ),
          OutboxEntry,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> tbl = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<String> patch = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> ifAbsent = const Value.absent(),
                Value<String?> rejected = const Value.absent(),
              }) => OutboxCompanion(
                seq: seq,
                tbl: tbl,
                rowId: rowId,
                patch: patch,
                hlc: hlc,
                ifAbsent: ifAbsent,
                rejected: rejected,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String tbl,
                required String rowId,
                required String patch,
                required String hlc,
                Value<bool> ifAbsent = const Value.absent(),
                Value<String?> rejected = const Value.absent(),
              }) => OutboxCompanion.insert(
                seq: seq,
                tbl: tbl,
                rowId: rowId,
                patch: patch,
                hlc: hlc,
                ifAbsent: ifAbsent,
                rejected: rejected,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxEntry>(table),
                  BaseReferences<_$AppDatabase, $OutboxTable, OutboxEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxEntry,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxEntry, BaseReferences<_$AppDatabase, $OutboxTable, OutboxEntry>),
      OutboxEntry,
      PrefetchHooks Function()
    >;
typedef $$SyncMetaTableCreateCompanionBuilder = SyncMetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SyncMetaTableUpdateCompanionBuilder = SyncMetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SyncMetaTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetaTable,
          SyncMetaEntry,
          $$SyncMetaTableFilterComposer,
          $$SyncMetaTableOrderingComposer,
          $$SyncMetaTableAnnotationComposer,
          $$SyncMetaTableCreateCompanionBuilder,
          $$SyncMetaTableUpdateCompanionBuilder,
          (
            SyncMetaEntry,
            BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaEntry>,
          ),
          SyncMetaEntry,
          PrefetchHooks Function()
        > {
  $$SyncMetaTableTableManager(_$AppDatabase db, $SyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SyncMetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncMetaTable, SyncMetaEntry>(table),
                  BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetaTable,
      SyncMetaEntry,
      $$SyncMetaTableFilterComposer,
      $$SyncMetaTableOrderingComposer,
      $$SyncMetaTableAnnotationComposer,
      $$SyncMetaTableCreateCompanionBuilder,
      $$SyncMetaTableUpdateCompanionBuilder,
      (
        SyncMetaEntry,
        BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaEntry>,
      ),
      SyncMetaEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SemestersTableTableManager get semesters =>
      $$SemestersTableTableManager(_db, _db.semesters);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db, _db.courses);
  $$MeetingsTableTableManager get meetings =>
      $$MeetingsTableTableManager(_db, _db.meetings);
  $$SessionOverridesTableTableManager get sessionOverrides =>
      $$SessionOverridesTableTableManager(_db, _db.sessionOverrides);
  $$NoClassRangesTableTableManager get noClassRanges =>
      $$NoClassRangesTableTableManager(_db, _db.noClassRanges);
  $$RequirementsTableTableManager get requirements =>
      $$RequirementsTableTableManager(_db, _db.requirements);
  $$UserSettingsTableTableManager get userSettings =>
      $$UserSettingsTableTableManager(_db, _db.userSettings);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
}
