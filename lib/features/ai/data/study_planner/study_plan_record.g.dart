// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_plan_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetStudyPlanRecordCollection on Isar {
  IsarCollection<StudyPlanRecord> get studyPlanRecords => this.collection();
}

const StudyPlanRecordSchema = CollectionSchema(
  name: r'StudyPlanRecord',
  id: 8773013963744904915,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'days': PropertySchema(
      id: 1,
      name: r'days',
      type: IsarType.objectList,
      target: r'StudyDayRecord',
    ),
    r'horizonKind': PropertySchema(
      id: 2,
      name: r'horizonKind',
      type: IsarType.string,
    ),
    r'notebookId': PropertySchema(
      id: 3,
      name: r'notebookId',
      type: IsarType.long,
    ),
    r'strategyNote': PropertySchema(
      id: 4,
      name: r'strategyNote',
      type: IsarType.string,
    )
  },
  estimateSize: _studyPlanRecordEstimateSize,
  serialize: _studyPlanRecordSerialize,
  deserialize: _studyPlanRecordDeserialize,
  deserializeProp: _studyPlanRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'notebookId': IndexSchema(
      id: -4215995649193063521,
      name: r'notebookId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'notebookId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {
    r'StudyDayRecord': StudyDayRecordSchema,
    r'StudyTaskRecord': StudyTaskRecordSchema
  },
  getId: _studyPlanRecordGetId,
  getLinks: _studyPlanRecordGetLinks,
  attach: _studyPlanRecordAttach,
  version: '3.1.0+1',
);

int _studyPlanRecordEstimateSize(
  StudyPlanRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.days.length * 3;
  {
    final offsets = allOffsets[StudyDayRecord]!;
    for (var i = 0; i < object.days.length; i++) {
      final value = object.days[i];
      bytesCount +=
          StudyDayRecordSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  bytesCount += 3 + object.horizonKind.length * 3;
  bytesCount += 3 + object.strategyNote.length * 3;
  return bytesCount;
}

void _studyPlanRecordSerialize(
  StudyPlanRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeObjectList<StudyDayRecord>(
    offsets[1],
    allOffsets,
    StudyDayRecordSchema.serialize,
    object.days,
  );
  writer.writeString(offsets[2], object.horizonKind);
  writer.writeLong(offsets[3], object.notebookId);
  writer.writeString(offsets[4], object.strategyNote);
}

StudyPlanRecord _studyPlanRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = StudyPlanRecord();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.days = reader.readObjectList<StudyDayRecord>(
        offsets[1],
        StudyDayRecordSchema.deserialize,
        allOffsets,
        StudyDayRecord(),
      ) ??
      [];
  object.horizonKind = reader.readString(offsets[2]);
  object.id = id;
  object.notebookId = reader.readLong(offsets[3]);
  object.strategyNote = reader.readString(offsets[4]);
  return object;
}

P _studyPlanRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readObjectList<StudyDayRecord>(
            offset,
            StudyDayRecordSchema.deserialize,
            allOffsets,
            StudyDayRecord(),
          ) ??
          []) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _studyPlanRecordGetId(StudyPlanRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _studyPlanRecordGetLinks(StudyPlanRecord object) {
  return [];
}

void _studyPlanRecordAttach(
    IsarCollection<dynamic> col, Id id, StudyPlanRecord object) {
  object.id = id;
}

extension StudyPlanRecordQueryWhereSort
    on QueryBuilder<StudyPlanRecord, StudyPlanRecord, QWhere> {
  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterWhere> anyNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'notebookId'),
      );
    });
  }
}

extension StudyPlanRecordQueryWhere
    on QueryBuilder<StudyPlanRecord, StudyPlanRecord, QWhereClause> {
  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterWhereClause>
      notebookIdEqualTo(int notebookId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'notebookId',
        value: [notebookId],
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterWhereClause>
      notebookIdNotEqualTo(int notebookId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'notebookId',
              lower: [],
              upper: [notebookId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'notebookId',
              lower: [notebookId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'notebookId',
              lower: [notebookId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'notebookId',
              lower: [],
              upper: [notebookId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterWhereClause>
      notebookIdGreaterThan(
    int notebookId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'notebookId',
        lower: [notebookId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterWhereClause>
      notebookIdLessThan(
    int notebookId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'notebookId',
        lower: [],
        upper: [notebookId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterWhereClause>
      notebookIdBetween(
    int lowerNotebookId,
    int upperNotebookId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'notebookId',
        lower: [lowerNotebookId],
        includeLower: includeLower,
        upper: [upperNotebookId],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension StudyPlanRecordQueryFilter
    on QueryBuilder<StudyPlanRecord, StudyPlanRecord, QFilterCondition> {
  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      daysLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'days',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      daysIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'days',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      daysIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'days',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      daysLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'days',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      daysLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'days',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      daysLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'days',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      horizonKindEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'horizonKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      horizonKindGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'horizonKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      horizonKindLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'horizonKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      horizonKindBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'horizonKind',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      horizonKindStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'horizonKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      horizonKindEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'horizonKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      horizonKindContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'horizonKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      horizonKindMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'horizonKind',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      horizonKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'horizonKind',
        value: '',
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      horizonKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'horizonKind',
        value: '',
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      notebookIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notebookId',
        value: value,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      notebookIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'notebookId',
        value: value,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      notebookIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'notebookId',
        value: value,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      notebookIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'notebookId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      strategyNoteEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'strategyNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      strategyNoteGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'strategyNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      strategyNoteLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'strategyNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      strategyNoteBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'strategyNote',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      strategyNoteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'strategyNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      strategyNoteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'strategyNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      strategyNoteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'strategyNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      strategyNoteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'strategyNote',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      strategyNoteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'strategyNote',
        value: '',
      ));
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      strategyNoteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'strategyNote',
        value: '',
      ));
    });
  }
}

extension StudyPlanRecordQueryObject
    on QueryBuilder<StudyPlanRecord, StudyPlanRecord, QFilterCondition> {
  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterFilterCondition>
      daysElement(FilterQuery<StudyDayRecord> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'days');
    });
  }
}

extension StudyPlanRecordQueryLinks
    on QueryBuilder<StudyPlanRecord, StudyPlanRecord, QFilterCondition> {}

extension StudyPlanRecordQuerySortBy
    on QueryBuilder<StudyPlanRecord, StudyPlanRecord, QSortBy> {
  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy>
      sortByHorizonKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'horizonKind', Sort.asc);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy>
      sortByHorizonKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'horizonKind', Sort.desc);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy>
      sortByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.asc);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy>
      sortByNotebookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.desc);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy>
      sortByStrategyNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'strategyNote', Sort.asc);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy>
      sortByStrategyNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'strategyNote', Sort.desc);
    });
  }
}

extension StudyPlanRecordQuerySortThenBy
    on QueryBuilder<StudyPlanRecord, StudyPlanRecord, QSortThenBy> {
  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy>
      thenByHorizonKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'horizonKind', Sort.asc);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy>
      thenByHorizonKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'horizonKind', Sort.desc);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy>
      thenByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.asc);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy>
      thenByNotebookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.desc);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy>
      thenByStrategyNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'strategyNote', Sort.asc);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QAfterSortBy>
      thenByStrategyNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'strategyNote', Sort.desc);
    });
  }
}

extension StudyPlanRecordQueryWhereDistinct
    on QueryBuilder<StudyPlanRecord, StudyPlanRecord, QDistinct> {
  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QDistinct>
      distinctByHorizonKind({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'horizonKind', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QDistinct>
      distinctByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notebookId');
    });
  }

  QueryBuilder<StudyPlanRecord, StudyPlanRecord, QDistinct>
      distinctByStrategyNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'strategyNote', caseSensitive: caseSensitive);
    });
  }
}

extension StudyPlanRecordQueryProperty
    on QueryBuilder<StudyPlanRecord, StudyPlanRecord, QQueryProperty> {
  QueryBuilder<StudyPlanRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<StudyPlanRecord, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<StudyPlanRecord, List<StudyDayRecord>, QQueryOperations>
      daysProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'days');
    });
  }

  QueryBuilder<StudyPlanRecord, String, QQueryOperations>
      horizonKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'horizonKind');
    });
  }

  QueryBuilder<StudyPlanRecord, int, QQueryOperations> notebookIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notebookId');
    });
  }

  QueryBuilder<StudyPlanRecord, String, QQueryOperations>
      strategyNoteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'strategyNote');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const StudyDayRecordSchema = Schema(
  name: r'StudyDayRecord',
  id: -8061192754278618517,
  properties: {
    r'completed': PropertySchema(
      id: 0,
      name: r'completed',
      type: IsarType.bool,
    ),
    r'date': PropertySchema(
      id: 1,
      name: r'date',
      type: IsarType.dateTime,
    ),
    r'tasks': PropertySchema(
      id: 2,
      name: r'tasks',
      type: IsarType.objectList,
      target: r'StudyTaskRecord',
    )
  },
  estimateSize: _studyDayRecordEstimateSize,
  serialize: _studyDayRecordSerialize,
  deserialize: _studyDayRecordDeserialize,
  deserializeProp: _studyDayRecordDeserializeProp,
);

int _studyDayRecordEstimateSize(
  StudyDayRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.tasks.length * 3;
  {
    final offsets = allOffsets[StudyTaskRecord]!;
    for (var i = 0; i < object.tasks.length; i++) {
      final value = object.tasks[i];
      bytesCount +=
          StudyTaskRecordSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  return bytesCount;
}

void _studyDayRecordSerialize(
  StudyDayRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.completed);
  writer.writeDateTime(offsets[1], object.date);
  writer.writeObjectList<StudyTaskRecord>(
    offsets[2],
    allOffsets,
    StudyTaskRecordSchema.serialize,
    object.tasks,
  );
}

StudyDayRecord _studyDayRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = StudyDayRecord();
  object.completed = reader.readBool(offsets[0]);
  object.date = reader.readDateTimeOrNull(offsets[1]);
  object.tasks = reader.readObjectList<StudyTaskRecord>(
        offsets[2],
        StudyTaskRecordSchema.deserialize,
        allOffsets,
        StudyTaskRecord(),
      ) ??
      [];
  return object;
}

P _studyDayRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 2:
      return (reader.readObjectList<StudyTaskRecord>(
            offset,
            StudyTaskRecordSchema.deserialize,
            allOffsets,
            StudyTaskRecord(),
          ) ??
          []) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension StudyDayRecordQueryFilter
    on QueryBuilder<StudyDayRecord, StudyDayRecord, QFilterCondition> {
  QueryBuilder<StudyDayRecord, StudyDayRecord, QAfterFilterCondition>
      completedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completed',
        value: value,
      ));
    });
  }

  QueryBuilder<StudyDayRecord, StudyDayRecord, QAfterFilterCondition>
      dateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'date',
      ));
    });
  }

  QueryBuilder<StudyDayRecord, StudyDayRecord, QAfterFilterCondition>
      dateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'date',
      ));
    });
  }

  QueryBuilder<StudyDayRecord, StudyDayRecord, QAfterFilterCondition>
      dateEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'date',
        value: value,
      ));
    });
  }

  QueryBuilder<StudyDayRecord, StudyDayRecord, QAfterFilterCondition>
      dateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'date',
        value: value,
      ));
    });
  }

  QueryBuilder<StudyDayRecord, StudyDayRecord, QAfterFilterCondition>
      dateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'date',
        value: value,
      ));
    });
  }

  QueryBuilder<StudyDayRecord, StudyDayRecord, QAfterFilterCondition>
      dateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'date',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StudyDayRecord, StudyDayRecord, QAfterFilterCondition>
      tasksLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tasks',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<StudyDayRecord, StudyDayRecord, QAfterFilterCondition>
      tasksIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tasks',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<StudyDayRecord, StudyDayRecord, QAfterFilterCondition>
      tasksIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tasks',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<StudyDayRecord, StudyDayRecord, QAfterFilterCondition>
      tasksLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tasks',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<StudyDayRecord, StudyDayRecord, QAfterFilterCondition>
      tasksLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tasks',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<StudyDayRecord, StudyDayRecord, QAfterFilterCondition>
      tasksLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tasks',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension StudyDayRecordQueryObject
    on QueryBuilder<StudyDayRecord, StudyDayRecord, QFilterCondition> {
  QueryBuilder<StudyDayRecord, StudyDayRecord, QAfterFilterCondition>
      tasksElement(FilterQuery<StudyTaskRecord> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'tasks');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const StudyTaskRecordSchema = Schema(
  name: r'StudyTaskRecord',
  id: -3425427760099484741,
  properties: {
    r'conceptName': PropertySchema(
      id: 0,
      name: r'conceptName',
      type: IsarType.string,
    ),
    r'kind': PropertySchema(
      id: 1,
      name: r'kind',
      type: IsarType.string,
    )
  },
  estimateSize: _studyTaskRecordEstimateSize,
  serialize: _studyTaskRecordSerialize,
  deserialize: _studyTaskRecordDeserialize,
  deserializeProp: _studyTaskRecordDeserializeProp,
);

int _studyTaskRecordEstimateSize(
  StudyTaskRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.conceptName.length * 3;
  bytesCount += 3 + object.kind.length * 3;
  return bytesCount;
}

void _studyTaskRecordSerialize(
  StudyTaskRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.conceptName);
  writer.writeString(offsets[1], object.kind);
}

StudyTaskRecord _studyTaskRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = StudyTaskRecord();
  object.conceptName = reader.readString(offsets[0]);
  object.kind = reader.readString(offsets[1]);
  return object;
}

P _studyTaskRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension StudyTaskRecordQueryFilter
    on QueryBuilder<StudyTaskRecord, StudyTaskRecord, QFilterCondition> {
  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      conceptNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conceptName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      conceptNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'conceptName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      conceptNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'conceptName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      conceptNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'conceptName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      conceptNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'conceptName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      conceptNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'conceptName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      conceptNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'conceptName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      conceptNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'conceptName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      conceptNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conceptName',
        value: '',
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      conceptNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'conceptName',
        value: '',
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      kindEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'kind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      kindGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'kind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      kindLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'kind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      kindBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'kind',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      kindStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'kind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      kindEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'kind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      kindContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'kind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      kindMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'kind',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      kindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'kind',
        value: '',
      ));
    });
  }

  QueryBuilder<StudyTaskRecord, StudyTaskRecord, QAfterFilterCondition>
      kindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'kind',
        value: '',
      ));
    });
  }
}

extension StudyTaskRecordQueryObject
    on QueryBuilder<StudyTaskRecord, StudyTaskRecord, QFilterCondition> {}
