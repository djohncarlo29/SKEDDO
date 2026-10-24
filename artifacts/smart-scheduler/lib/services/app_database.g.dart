// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $StoredEventsTable extends StoredEvents
    with TableInfo<$StoredEventsTable, StoredEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionMeta = const VerificationMeta(
    'collection',
  );
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
    'collection',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [collection, id, position, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stored_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection')) {
      context.handle(
        _collectionMeta,
        collection.isAcceptableOrUnknown(data['collection']!, _collectionMeta),
      );
    } else if (isInserting) {
      context.missing(_collectionMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collection, id};
  @override
  StoredEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredEvent(
      collection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $StoredEventsTable createAlias(String alias) {
    return $StoredEventsTable(attachedDatabase, alias);
  }
}

class StoredEvent extends DataClass implements Insertable<StoredEvent> {
  final String collection;
  final String id;
  final int position;
  final String payload;
  const StoredEvent({
    required this.collection,
    required this.id,
    required this.position,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection'] = Variable<String>(collection);
    map['id'] = Variable<String>(id);
    map['position'] = Variable<int>(position);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  StoredEventsCompanion toCompanion(bool nullToAbsent) {
    return StoredEventsCompanion(
      collection: Value(collection),
      id: Value(id),
      position: Value(position),
      payload: Value(payload),
    );
  }

  factory StoredEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredEvent(
      collection: serializer.fromJson<String>(json['collection']),
      id: serializer.fromJson<String>(json['id']),
      position: serializer.fromJson<int>(json['position']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<String>(collection),
      'id': serializer.toJson<String>(id),
      'position': serializer.toJson<int>(position),
      'payload': serializer.toJson<String>(payload),
    };
  }

  StoredEvent copyWith({
    String? collection,
    String? id,
    int? position,
    String? payload,
  }) => StoredEvent(
    collection: collection ?? this.collection,
    id: id ?? this.id,
    position: position ?? this.position,
    payload: payload ?? this.payload,
  );
  StoredEvent copyWithCompanion(StoredEventsCompanion data) {
    return StoredEvent(
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      id: data.id.present ? data.id.value : this.id,
      position: data.position.present ? data.position.value : this.position,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredEvent(')
          ..write('collection: $collection, ')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collection, id, position, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredEvent &&
          other.collection == this.collection &&
          other.id == this.id &&
          other.position == this.position &&
          other.payload == this.payload);
}

class StoredEventsCompanion extends UpdateCompanion<StoredEvent> {
  final Value<String> collection;
  final Value<String> id;
  final Value<int> position;
  final Value<String> payload;
  final Value<int> rowid;
  const StoredEventsCompanion({
    this.collection = const Value.absent(),
    this.id = const Value.absent(),
    this.position = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredEventsCompanion.insert({
    required String collection,
    required String id,
    required int position,
    required String payload,
    this.rowid = const Value.absent(),
  }) : collection = Value(collection),
       id = Value(id),
       position = Value(position),
       payload = Value(payload);
  static Insertable<StoredEvent> custom({
    Expression<String>? collection,
    Expression<String>? id,
    Expression<int>? position,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collection != null) 'collection': collection,
      if (id != null) 'id': id,
      if (position != null) 'position': position,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredEventsCompanion copyWith({
    Value<String>? collection,
    Value<String>? id,
    Value<int>? position,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return StoredEventsCompanion(
      collection: collection ?? this.collection,
      id: id ?? this.id,
      position: position ?? this.position,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredEventsCompanion(')
          ..write('collection: $collection, ')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredContentTable extends StoredContent
    with TableInfo<$StoredContentTable, StoredContentData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredContentTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'stored_content';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredContentData> instance, {
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
  StoredContentData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredContentData(
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
  $StoredContentTable createAlias(String alias) {
    return $StoredContentTable(attachedDatabase, alias);
  }
}

class StoredContentData extends DataClass
    implements Insertable<StoredContentData> {
  final String key;
  final String value;
  const StoredContentData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  StoredContentCompanion toCompanion(bool nullToAbsent) {
    return StoredContentCompanion(key: Value(key), value: Value(value));
  }

  factory StoredContentData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredContentData(
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

  StoredContentData copyWith({String? key, String? value}) =>
      StoredContentData(key: key ?? this.key, value: value ?? this.value);
  StoredContentData copyWithCompanion(StoredContentCompanion data) {
    return StoredContentData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredContentData(')
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
      (other is StoredContentData &&
          other.key == this.key &&
          other.value == this.value);
}

class StoredContentCompanion extends UpdateCompanion<StoredContentData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const StoredContentCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredContentCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<StoredContentData> custom({
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

  StoredContentCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return StoredContentCompanion(
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
    return (StringBuffer('StoredContentCompanion(')
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
  late final $StoredEventsTable storedEvents = $StoredEventsTable(this);
  late final $StoredContentTable storedContent = $StoredContentTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    storedEvents,
    storedContent,
  ];
}

typedef $$StoredEventsTableCreateCompanionBuilder =
    StoredEventsCompanion Function({
      required String collection,
      required String id,
      required int position,
      required String payload,
      Value<int> rowid,
    });
typedef $$StoredEventsTableUpdateCompanionBuilder =
    StoredEventsCompanion Function({
      Value<String> collection,
      Value<String> id,
      Value<int> position,
      Value<String> payload,
      Value<int> rowid,
    });

class $$StoredEventsTableFilterComposer
    extends Composer<_$AppDatabase, $StoredEventsTable> {
  $$StoredEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredEventsTable> {
  $$StoredEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredEventsTable> {
  $$StoredEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$StoredEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredEventsTable,
          StoredEvent,
          $$StoredEventsTableFilterComposer,
          $$StoredEventsTableOrderingComposer,
          $$StoredEventsTableAnnotationComposer,
          $$StoredEventsTableCreateCompanionBuilder,
          $$StoredEventsTableUpdateCompanionBuilder,
          (
            StoredEvent,
            BaseReferences<_$AppDatabase, $StoredEventsTable, StoredEvent>,
          ),
          StoredEvent,
          PrefetchHooks Function()
        > {
  $$StoredEventsTableTableManager(_$AppDatabase db, $StoredEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoredEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoredEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoredEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> collection = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredEventsCompanion(
                collection: collection,
                id: id,
                position: position,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collection,
                required String id,
                required int position,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => StoredEventsCompanion.insert(
                collection: collection,
                id: id,
                position: position,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StoredEventsTable, StoredEvent>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $StoredEventsTable,
                    StoredEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoredEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredEventsTable,
      StoredEvent,
      $$StoredEventsTableFilterComposer,
      $$StoredEventsTableOrderingComposer,
      $$StoredEventsTableAnnotationComposer,
      $$StoredEventsTableCreateCompanionBuilder,
      $$StoredEventsTableUpdateCompanionBuilder,
      (
        StoredEvent,
        BaseReferences<_$AppDatabase, $StoredEventsTable, StoredEvent>,
      ),
      StoredEvent,
      PrefetchHooks Function()
    >;
typedef $$StoredContentTableCreateCompanionBuilder =
    StoredContentCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$StoredContentTableUpdateCompanionBuilder =
    StoredContentCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$StoredContentTableFilterComposer
    extends Composer<_$AppDatabase, $StoredContentTable> {
  $$StoredContentTableFilterComposer({
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

class $$StoredContentTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredContentTable> {
  $$StoredContentTableOrderingComposer({
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

class $$StoredContentTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredContentTable> {
  $$StoredContentTableAnnotationComposer({
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

class $$StoredContentTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredContentTable,
          StoredContentData,
          $$StoredContentTableFilterComposer,
          $$StoredContentTableOrderingComposer,
          $$StoredContentTableAnnotationComposer,
          $$StoredContentTableCreateCompanionBuilder,
          $$StoredContentTableUpdateCompanionBuilder,
          (
            StoredContentData,
            BaseReferences<
              _$AppDatabase,
              $StoredContentTable,
              StoredContentData
            >,
          ),
          StoredContentData,
          PrefetchHooks Function()
        > {
  $$StoredContentTableTableManager(_$AppDatabase db, $StoredContentTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoredContentTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoredContentTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoredContentTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  StoredContentCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => StoredContentCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StoredContentTable, StoredContentData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $StoredContentTable,
                    StoredContentData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoredContentTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredContentTable,
      StoredContentData,
      $$StoredContentTableFilterComposer,
      $$StoredContentTableOrderingComposer,
      $$StoredContentTableAnnotationComposer,
      $$StoredContentTableCreateCompanionBuilder,
      $$StoredContentTableUpdateCompanionBuilder,
      (
        StoredContentData,
        BaseReferences<_$AppDatabase, $StoredContentTable, StoredContentData>,
      ),
      StoredContentData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StoredEventsTableTableManager get storedEvents =>
      $$StoredEventsTableTableManager(_db, _db.storedEvents);
  $$StoredContentTableTableManager get storedContent =>
      $$StoredContentTableTableManager(_db, _db.storedContent);
}
