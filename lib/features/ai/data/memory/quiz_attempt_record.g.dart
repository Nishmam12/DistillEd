// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz_attempt_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetQuizAttemptRecordCollection on Isar {
  IsarCollection<QuizAttemptRecord> get quizAttemptRecords => this.collection();
}

const QuizAttemptRecordSchema = CollectionSchema(
  name: r'QuizAttemptRecord',
  id: -747519878486109255,
  properties: {
    r'attemptId': PropertySchema(
      id: 0,
      name: r'attemptId',
      type: IsarType.string,
    ),
    r'notebookId': PropertySchema(
      id: 1,
      name: r'notebookId',
      type: IsarType.long,
    ),
    r'outcomes': PropertySchema(
      id: 2,
      name: r'outcomes',
      type: IsarType.objectList,
      target: r'QuizQuestionOutcomeRecord',
    ),
    r'pageId': PropertySchema(
      id: 3,
      name: r'pageId',
      type: IsarType.long,
    ),
    r'takenAt': PropertySchema(
      id: 4,
      name: r'takenAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _quizAttemptRecordEstimateSize,
  serialize: _quizAttemptRecordSerialize,
  deserialize: _quizAttemptRecordDeserialize,
  deserializeProp: _quizAttemptRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'attemptId': IndexSchema(
      id: 3768995775447394589,
      name: r'attemptId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'attemptId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
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
    r'QuizQuestionOutcomeRecord': QuizQuestionOutcomeRecordSchema
  },
  getId: _quizAttemptRecordGetId,
  getLinks: _quizAttemptRecordGetLinks,
  attach: _quizAttemptRecordAttach,
  version: '3.1.0+1',
);

int _quizAttemptRecordEstimateSize(
  QuizAttemptRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.attemptId.length * 3;
  bytesCount += 3 + object.outcomes.length * 3;
  {
    final offsets = allOffsets[QuizQuestionOutcomeRecord]!;
    for (var i = 0; i < object.outcomes.length; i++) {
      final value = object.outcomes[i];
      bytesCount += QuizQuestionOutcomeRecordSchema.estimateSize(
          value, offsets, allOffsets);
    }
  }
  return bytesCount;
}

void _quizAttemptRecordSerialize(
  QuizAttemptRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.attemptId);
  writer.writeLong(offsets[1], object.notebookId);
  writer.writeObjectList<QuizQuestionOutcomeRecord>(
    offsets[2],
    allOffsets,
    QuizQuestionOutcomeRecordSchema.serialize,
    object.outcomes,
  );
  writer.writeLong(offsets[3], object.pageId);
  writer.writeDateTime(offsets[4], object.takenAt);
}

QuizAttemptRecord _quizAttemptRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = QuizAttemptRecord();
  object.attemptId = reader.readString(offsets[0]);
  object.id = id;
  object.notebookId = reader.readLong(offsets[1]);
  object.outcomes = reader.readObjectList<QuizQuestionOutcomeRecord>(
        offsets[2],
        QuizQuestionOutcomeRecordSchema.deserialize,
        allOffsets,
        QuizQuestionOutcomeRecord(),
      ) ??
      [];
  object.pageId = reader.readLong(offsets[3]);
  object.takenAt = reader.readDateTime(offsets[4]);
  return object;
}

P _quizAttemptRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readObjectList<QuizQuestionOutcomeRecord>(
            offset,
            QuizQuestionOutcomeRecordSchema.deserialize,
            allOffsets,
            QuizQuestionOutcomeRecord(),
          ) ??
          []) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _quizAttemptRecordGetId(QuizAttemptRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _quizAttemptRecordGetLinks(
    QuizAttemptRecord object) {
  return [];
}

void _quizAttemptRecordAttach(
    IsarCollection<dynamic> col, Id id, QuizAttemptRecord object) {
  object.id = id;
}

extension QuizAttemptRecordQueryWhereSort
    on QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QWhere> {
  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterWhere>
      anyNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'notebookId'),
      );
    });
  }
}

extension QuizAttemptRecordQueryWhere
    on QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QWhereClause> {
  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterWhereClause>
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

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterWhereClause>
      idBetween(
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

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterWhereClause>
      attemptIdEqualTo(String attemptId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'attemptId',
        value: [attemptId],
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterWhereClause>
      attemptIdNotEqualTo(String attemptId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'attemptId',
              lower: [],
              upper: [attemptId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'attemptId',
              lower: [attemptId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'attemptId',
              lower: [attemptId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'attemptId',
              lower: [],
              upper: [attemptId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterWhereClause>
      notebookIdEqualTo(int notebookId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'notebookId',
        value: [notebookId],
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterWhereClause>
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

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterWhereClause>
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

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterWhereClause>
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

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterWhereClause>
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

extension QuizAttemptRecordQueryFilter
    on QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QFilterCondition> {
  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      attemptIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attemptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      attemptIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'attemptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      attemptIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'attemptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      attemptIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'attemptId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      attemptIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'attemptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      attemptIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'attemptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      attemptIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'attemptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      attemptIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'attemptId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      attemptIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attemptId',
        value: '',
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      attemptIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'attemptId',
        value: '',
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
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

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
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

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
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

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      notebookIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notebookId',
        value: value,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
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

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
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

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
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

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      outcomesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'outcomes',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      outcomesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'outcomes',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      outcomesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'outcomes',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      outcomesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'outcomes',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      outcomesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'outcomes',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      outcomesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'outcomes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      pageIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pageId',
        value: value,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      pageIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pageId',
        value: value,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      pageIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pageId',
        value: value,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      pageIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pageId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      takenAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'takenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      takenAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'takenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      takenAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'takenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      takenAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'takenAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension QuizAttemptRecordQueryObject
    on QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QFilterCondition> {
  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterFilterCondition>
      outcomesElement(FilterQuery<QuizQuestionOutcomeRecord> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'outcomes');
    });
  }
}

extension QuizAttemptRecordQueryLinks
    on QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QFilterCondition> {}

extension QuizAttemptRecordQuerySortBy
    on QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QSortBy> {
  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      sortByAttemptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptId', Sort.asc);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      sortByAttemptIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptId', Sort.desc);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      sortByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.asc);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      sortByNotebookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.desc);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      sortByPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageId', Sort.asc);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      sortByPageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageId', Sort.desc);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      sortByTakenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'takenAt', Sort.asc);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      sortByTakenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'takenAt', Sort.desc);
    });
  }
}

extension QuizAttemptRecordQuerySortThenBy
    on QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QSortThenBy> {
  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      thenByAttemptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptId', Sort.asc);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      thenByAttemptIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptId', Sort.desc);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      thenByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.asc);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      thenByNotebookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.desc);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      thenByPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageId', Sort.asc);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      thenByPageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageId', Sort.desc);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      thenByTakenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'takenAt', Sort.asc);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QAfterSortBy>
      thenByTakenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'takenAt', Sort.desc);
    });
  }
}

extension QuizAttemptRecordQueryWhereDistinct
    on QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QDistinct> {
  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QDistinct>
      distinctByAttemptId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attemptId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QDistinct>
      distinctByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notebookId');
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QDistinct>
      distinctByPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pageId');
    });
  }

  QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QDistinct>
      distinctByTakenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'takenAt');
    });
  }
}

extension QuizAttemptRecordQueryProperty
    on QueryBuilder<QuizAttemptRecord, QuizAttemptRecord, QQueryProperty> {
  QueryBuilder<QuizAttemptRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<QuizAttemptRecord, String, QQueryOperations>
      attemptIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attemptId');
    });
  }

  QueryBuilder<QuizAttemptRecord, int, QQueryOperations> notebookIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notebookId');
    });
  }

  QueryBuilder<QuizAttemptRecord, List<QuizQuestionOutcomeRecord>,
      QQueryOperations> outcomesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'outcomes');
    });
  }

  QueryBuilder<QuizAttemptRecord, int, QQueryOperations> pageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pageId');
    });
  }

  QueryBuilder<QuizAttemptRecord, DateTime, QQueryOperations>
      takenAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'takenAt');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const QuizQuestionOutcomeRecordSchema = Schema(
  name: r'QuizQuestionOutcomeRecord',
  id: -4926192135434392088,
  properties: {
    r'conceptKeys': PropertySchema(
      id: 0,
      name: r'conceptKeys',
      type: IsarType.stringList,
    ),
    r'correct': PropertySchema(
      id: 1,
      name: r'correct',
      type: IsarType.bool,
    ),
    r'prompt': PropertySchema(
      id: 2,
      name: r'prompt',
      type: IsarType.string,
    )
  },
  estimateSize: _quizQuestionOutcomeRecordEstimateSize,
  serialize: _quizQuestionOutcomeRecordSerialize,
  deserialize: _quizQuestionOutcomeRecordDeserialize,
  deserializeProp: _quizQuestionOutcomeRecordDeserializeProp,
);

int _quizQuestionOutcomeRecordEstimateSize(
  QuizQuestionOutcomeRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final list = object.conceptKeys;
    if (list != null) {
      bytesCount += 3 + list.length * 3;
      {
        for (var i = 0; i < list.length; i++) {
          final value = list[i];
          bytesCount += value.length * 3;
        }
      }
    }
  }
  {
    final value = object.prompt;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _quizQuestionOutcomeRecordSerialize(
  QuizQuestionOutcomeRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeStringList(offsets[0], object.conceptKeys);
  writer.writeBool(offsets[1], object.correct);
  writer.writeString(offsets[2], object.prompt);
}

QuizQuestionOutcomeRecord _quizQuestionOutcomeRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = QuizQuestionOutcomeRecord();
  object.conceptKeys = reader.readStringList(offsets[0]);
  object.correct = reader.readBoolOrNull(offsets[1]);
  object.prompt = reader.readStringOrNull(offsets[2]);
  return object;
}

P _quizQuestionOutcomeRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringList(offset)) as P;
    case 1:
      return (reader.readBoolOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension QuizQuestionOutcomeRecordQueryFilter on QueryBuilder<
    QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord, QFilterCondition> {
  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> conceptKeysIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'conceptKeys',
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> conceptKeysIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'conceptKeys',
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> conceptKeysElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conceptKeys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> conceptKeysElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'conceptKeys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> conceptKeysElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'conceptKeys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> conceptKeysElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'conceptKeys',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> conceptKeysElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'conceptKeys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> conceptKeysElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'conceptKeys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
          QAfterFilterCondition>
      conceptKeysElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'conceptKeys',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
          QAfterFilterCondition>
      conceptKeysElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'conceptKeys',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> conceptKeysElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conceptKeys',
        value: '',
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> conceptKeysElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'conceptKeys',
        value: '',
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> conceptKeysLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'conceptKeys',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> conceptKeysIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'conceptKeys',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> conceptKeysIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'conceptKeys',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> conceptKeysLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'conceptKeys',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> conceptKeysLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'conceptKeys',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> conceptKeysLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'conceptKeys',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> correctIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'correct',
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> correctIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'correct',
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> correctEqualTo(bool? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'correct',
        value: value,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> promptIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'prompt',
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> promptIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'prompt',
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> promptEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'prompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> promptGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'prompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> promptLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'prompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> promptBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'prompt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> promptStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'prompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> promptEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'prompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
          QAfterFilterCondition>
      promptContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'prompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
          QAfterFilterCondition>
      promptMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'prompt',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> promptIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'prompt',
        value: '',
      ));
    });
  }

  QueryBuilder<QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord,
      QAfterFilterCondition> promptIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'prompt',
        value: '',
      ));
    });
  }
}

extension QuizQuestionOutcomeRecordQueryObject on QueryBuilder<
    QuizQuestionOutcomeRecord, QuizQuestionOutcomeRecord, QFilterCondition> {}
