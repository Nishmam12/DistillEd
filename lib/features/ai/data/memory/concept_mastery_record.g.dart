// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'concept_mastery_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetConceptMasteryRecordCollection on Isar {
  IsarCollection<ConceptMasteryRecord> get conceptMasteryRecords =>
      this.collection();
}

const ConceptMasteryRecordSchema = CollectionSchema(
  name: r'ConceptMasteryRecord',
  id: -6493486074252437993,
  properties: {
    r'conceptKey': PropertySchema(
      id: 0,
      name: r'conceptKey',
      type: IsarType.string,
    ),
    r'conceptName': PropertySchema(
      id: 1,
      name: r'conceptName',
      type: IsarType.string,
    ),
    r'lastPageId': PropertySchema(
      id: 2,
      name: r'lastPageId',
      type: IsarType.long,
    ),
    r'lastReviewedAt': PropertySchema(
      id: 3,
      name: r'lastReviewedAt',
      type: IsarType.dateTime,
    ),
    r'lastSeenAt': PropertySchema(
      id: 4,
      name: r'lastSeenAt',
      type: IsarType.dateTime,
    ),
    r'level': PropertySchema(
      id: 5,
      name: r'level',
      type: IsarType.string,
    ),
    r'notebookId': PropertySchema(
      id: 6,
      name: r'notebookId',
      type: IsarType.long,
    ),
    r'timesFlaggedAsGap': PropertySchema(
      id: 7,
      name: r'timesFlaggedAsGap',
      type: IsarType.long,
    ),
    r'timesMissedInQuiz': PropertySchema(
      id: 8,
      name: r'timesMissedInQuiz',
      type: IsarType.long,
    ),
    r'timesReviewed': PropertySchema(
      id: 9,
      name: r'timesReviewed',
      type: IsarType.long,
    )
  },
  estimateSize: _conceptMasteryRecordEstimateSize,
  serialize: _conceptMasteryRecordSerialize,
  deserialize: _conceptMasteryRecordDeserialize,
  deserializeProp: _conceptMasteryRecordDeserializeProp,
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
    ),
    r'conceptKey': IndexSchema(
      id: 2007267346416430200,
      name: r'conceptKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'conceptKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _conceptMasteryRecordGetId,
  getLinks: _conceptMasteryRecordGetLinks,
  attach: _conceptMasteryRecordAttach,
  version: '3.1.0+1',
);

int _conceptMasteryRecordEstimateSize(
  ConceptMasteryRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.conceptKey.length * 3;
  bytesCount += 3 + object.conceptName.length * 3;
  bytesCount += 3 + object.level.length * 3;
  return bytesCount;
}

void _conceptMasteryRecordSerialize(
  ConceptMasteryRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.conceptKey);
  writer.writeString(offsets[1], object.conceptName);
  writer.writeLong(offsets[2], object.lastPageId);
  writer.writeDateTime(offsets[3], object.lastReviewedAt);
  writer.writeDateTime(offsets[4], object.lastSeenAt);
  writer.writeString(offsets[5], object.level);
  writer.writeLong(offsets[6], object.notebookId);
  writer.writeLong(offsets[7], object.timesFlaggedAsGap);
  writer.writeLong(offsets[8], object.timesMissedInQuiz);
  writer.writeLong(offsets[9], object.timesReviewed);
}

ConceptMasteryRecord _conceptMasteryRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ConceptMasteryRecord();
  object.conceptKey = reader.readString(offsets[0]);
  object.conceptName = reader.readString(offsets[1]);
  object.id = id;
  object.lastPageId = reader.readLongOrNull(offsets[2]);
  object.lastReviewedAt = reader.readDateTimeOrNull(offsets[3]);
  object.lastSeenAt = reader.readDateTime(offsets[4]);
  object.level = reader.readString(offsets[5]);
  object.notebookId = reader.readLong(offsets[6]);
  object.timesFlaggedAsGap = reader.readLong(offsets[7]);
  object.timesMissedInQuiz = reader.readLong(offsets[8]);
  object.timesReviewed = reader.readLong(offsets[9]);
  return object;
}

P _conceptMasteryRecordDeserializeProp<P>(
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
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _conceptMasteryRecordGetId(ConceptMasteryRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _conceptMasteryRecordGetLinks(
    ConceptMasteryRecord object) {
  return [];
}

void _conceptMasteryRecordAttach(
    IsarCollection<dynamic> col, Id id, ConceptMasteryRecord object) {
  object.id = id;
}

extension ConceptMasteryRecordQueryWhereSort
    on QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QWhere> {
  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterWhere>
      anyNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'notebookId'),
      );
    });
  }
}

extension ConceptMasteryRecordQueryWhere
    on QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QWhereClause> {
  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterWhereClause>
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterWhereClause>
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterWhereClause>
      notebookIdEqualTo(int notebookId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'notebookId',
        value: [notebookId],
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterWhereClause>
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterWhereClause>
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterWhereClause>
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterWhereClause>
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterWhereClause>
      conceptKeyEqualTo(String conceptKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'conceptKey',
        value: [conceptKey],
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterWhereClause>
      conceptKeyNotEqualTo(String conceptKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conceptKey',
              lower: [],
              upper: [conceptKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conceptKey',
              lower: [conceptKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conceptKey',
              lower: [conceptKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conceptKey',
              lower: [],
              upper: [conceptKey],
              includeUpper: false,
            ));
      }
    });
  }
}

extension ConceptMasteryRecordQueryFilter on QueryBuilder<ConceptMasteryRecord,
    ConceptMasteryRecord, QFilterCondition> {
  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> conceptKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conceptKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> conceptKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'conceptKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> conceptKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'conceptKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> conceptKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'conceptKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> conceptKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'conceptKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> conceptKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'conceptKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
          QAfterFilterCondition>
      conceptKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'conceptKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
          QAfterFilterCondition>
      conceptKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'conceptKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> conceptKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conceptKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> conceptKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'conceptKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> conceptNameEqualTo(
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> conceptNameGreaterThan(
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> conceptNameLessThan(
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> conceptNameBetween(
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> conceptNameStartsWith(
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> conceptNameEndsWith(
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
          QAfterFilterCondition>
      conceptNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'conceptName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
          QAfterFilterCondition>
      conceptNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'conceptName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> conceptNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conceptName',
        value: '',
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> conceptNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'conceptName',
        value: '',
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> idLessThan(
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> idBetween(
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> lastPageIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastPageId',
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> lastPageIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastPageId',
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> lastPageIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastPageId',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> lastPageIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastPageId',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> lastPageIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastPageId',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> lastPageIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastPageId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> lastReviewedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastReviewedAt',
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> lastReviewedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastReviewedAt',
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> lastReviewedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastReviewedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> lastReviewedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastReviewedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> lastReviewedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastReviewedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> lastReviewedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastReviewedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> lastSeenAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastSeenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> lastSeenAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastSeenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> lastSeenAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastSeenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> lastSeenAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastSeenAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> levelEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'level',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> levelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'level',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> levelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'level',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> levelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'level',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> levelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'level',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> levelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'level',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
          QAfterFilterCondition>
      levelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'level',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
          QAfterFilterCondition>
      levelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'level',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> levelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'level',
        value: '',
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> levelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'level',
        value: '',
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> notebookIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notebookId',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> notebookIdGreaterThan(
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> notebookIdLessThan(
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> notebookIdBetween(
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

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> timesFlaggedAsGapEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timesFlaggedAsGap',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> timesFlaggedAsGapGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timesFlaggedAsGap',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> timesFlaggedAsGapLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timesFlaggedAsGap',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> timesFlaggedAsGapBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timesFlaggedAsGap',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> timesMissedInQuizEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timesMissedInQuiz',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> timesMissedInQuizGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timesMissedInQuiz',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> timesMissedInQuizLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timesMissedInQuiz',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> timesMissedInQuizBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timesMissedInQuiz',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> timesReviewedEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timesReviewed',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> timesReviewedGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timesReviewed',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> timesReviewedLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timesReviewed',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord,
      QAfterFilterCondition> timesReviewedBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timesReviewed',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ConceptMasteryRecordQueryObject on QueryBuilder<ConceptMasteryRecord,
    ConceptMasteryRecord, QFilterCondition> {}

extension ConceptMasteryRecordQueryLinks on QueryBuilder<ConceptMasteryRecord,
    ConceptMasteryRecord, QFilterCondition> {}

extension ConceptMasteryRecordQuerySortBy
    on QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QSortBy> {
  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByConceptKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conceptKey', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByConceptKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conceptKey', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByConceptName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conceptName', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByConceptNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conceptName', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByLastPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPageId', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByLastPageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPageId', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByLastReviewedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReviewedAt', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByLastReviewedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReviewedAt', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByLastSeenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'level', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByLevelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'level', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByNotebookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByTimesFlaggedAsGap() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timesFlaggedAsGap', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByTimesFlaggedAsGapDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timesFlaggedAsGap', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByTimesMissedInQuiz() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timesMissedInQuiz', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByTimesMissedInQuizDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timesMissedInQuiz', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByTimesReviewed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timesReviewed', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      sortByTimesReviewedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timesReviewed', Sort.desc);
    });
  }
}

extension ConceptMasteryRecordQuerySortThenBy
    on QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QSortThenBy> {
  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByConceptKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conceptKey', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByConceptKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conceptKey', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByConceptName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conceptName', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByConceptNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conceptName', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByLastPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPageId', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByLastPageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPageId', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByLastReviewedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReviewedAt', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByLastReviewedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReviewedAt', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByLastSeenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'level', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByLevelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'level', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByNotebookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByTimesFlaggedAsGap() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timesFlaggedAsGap', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByTimesFlaggedAsGapDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timesFlaggedAsGap', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByTimesMissedInQuiz() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timesMissedInQuiz', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByTimesMissedInQuizDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timesMissedInQuiz', Sort.desc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByTimesReviewed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timesReviewed', Sort.asc);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QAfterSortBy>
      thenByTimesReviewedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timesReviewed', Sort.desc);
    });
  }
}

extension ConceptMasteryRecordQueryWhereDistinct
    on QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QDistinct> {
  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QDistinct>
      distinctByConceptKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'conceptKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QDistinct>
      distinctByConceptName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'conceptName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QDistinct>
      distinctByLastPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastPageId');
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QDistinct>
      distinctByLastReviewedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastReviewedAt');
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QDistinct>
      distinctByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSeenAt');
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QDistinct>
      distinctByLevel({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'level', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QDistinct>
      distinctByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notebookId');
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QDistinct>
      distinctByTimesFlaggedAsGap() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timesFlaggedAsGap');
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QDistinct>
      distinctByTimesMissedInQuiz() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timesMissedInQuiz');
    });
  }

  QueryBuilder<ConceptMasteryRecord, ConceptMasteryRecord, QDistinct>
      distinctByTimesReviewed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timesReviewed');
    });
  }
}

extension ConceptMasteryRecordQueryProperty on QueryBuilder<
    ConceptMasteryRecord, ConceptMasteryRecord, QQueryProperty> {
  QueryBuilder<ConceptMasteryRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ConceptMasteryRecord, String, QQueryOperations>
      conceptKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conceptKey');
    });
  }

  QueryBuilder<ConceptMasteryRecord, String, QQueryOperations>
      conceptNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conceptName');
    });
  }

  QueryBuilder<ConceptMasteryRecord, int?, QQueryOperations>
      lastPageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastPageId');
    });
  }

  QueryBuilder<ConceptMasteryRecord, DateTime?, QQueryOperations>
      lastReviewedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastReviewedAt');
    });
  }

  QueryBuilder<ConceptMasteryRecord, DateTime, QQueryOperations>
      lastSeenAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSeenAt');
    });
  }

  QueryBuilder<ConceptMasteryRecord, String, QQueryOperations> levelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'level');
    });
  }

  QueryBuilder<ConceptMasteryRecord, int, QQueryOperations>
      notebookIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notebookId');
    });
  }

  QueryBuilder<ConceptMasteryRecord, int, QQueryOperations>
      timesFlaggedAsGapProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timesFlaggedAsGap');
    });
  }

  QueryBuilder<ConceptMasteryRecord, int, QQueryOperations>
      timesMissedInQuizProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timesMissedInQuiz');
    });
  }

  QueryBuilder<ConceptMasteryRecord, int, QQueryOperations>
      timesReviewedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timesReviewed');
    });
  }
}
