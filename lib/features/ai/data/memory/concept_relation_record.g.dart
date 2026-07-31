// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'concept_relation_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetConceptRelationRecordCollection on Isar {
  IsarCollection<ConceptRelationRecord> get conceptRelationRecords =>
      this.collection();
}

const ConceptRelationRecordSchema = CollectionSchema(
  name: r'ConceptRelationRecord',
  id: 4799229859301499292,
  properties: {
    r'confidence': PropertySchema(
      id: 0,
      name: r'confidence',
      type: IsarType.double,
    ),
    r'fromKey': PropertySchema(
      id: 1,
      name: r'fromKey',
      type: IsarType.string,
    ),
    r'fromName': PropertySchema(
      id: 2,
      name: r'fromName',
      type: IsarType.string,
    ),
    r'lastPageId': PropertySchema(
      id: 3,
      name: r'lastPageId',
      type: IsarType.long,
    ),
    r'lastSeenAt': PropertySchema(
      id: 4,
      name: r'lastSeenAt',
      type: IsarType.dateTime,
    ),
    r'notebookId': PropertySchema(
      id: 5,
      name: r'notebookId',
      type: IsarType.long,
    ),
    r'relation': PropertySchema(
      id: 6,
      name: r'relation',
      type: IsarType.string,
    ),
    r'toKey': PropertySchema(
      id: 7,
      name: r'toKey',
      type: IsarType.string,
    ),
    r'toName': PropertySchema(
      id: 8,
      name: r'toName',
      type: IsarType.string,
    )
  },
  estimateSize: _conceptRelationRecordEstimateSize,
  serialize: _conceptRelationRecordSerialize,
  deserialize: _conceptRelationRecordDeserialize,
  deserializeProp: _conceptRelationRecordDeserializeProp,
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
    r'fromKey': IndexSchema(
      id: -7936230246737321615,
      name: r'fromKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'fromKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _conceptRelationRecordGetId,
  getLinks: _conceptRelationRecordGetLinks,
  attach: _conceptRelationRecordAttach,
  version: '3.1.0+1',
);

int _conceptRelationRecordEstimateSize(
  ConceptRelationRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.fromKey.length * 3;
  bytesCount += 3 + object.fromName.length * 3;
  bytesCount += 3 + object.relation.length * 3;
  bytesCount += 3 + object.toKey.length * 3;
  bytesCount += 3 + object.toName.length * 3;
  return bytesCount;
}

void _conceptRelationRecordSerialize(
  ConceptRelationRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.confidence);
  writer.writeString(offsets[1], object.fromKey);
  writer.writeString(offsets[2], object.fromName);
  writer.writeLong(offsets[3], object.lastPageId);
  writer.writeDateTime(offsets[4], object.lastSeenAt);
  writer.writeLong(offsets[5], object.notebookId);
  writer.writeString(offsets[6], object.relation);
  writer.writeString(offsets[7], object.toKey);
  writer.writeString(offsets[8], object.toName);
}

ConceptRelationRecord _conceptRelationRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ConceptRelationRecord();
  object.confidence = reader.readDouble(offsets[0]);
  object.fromKey = reader.readString(offsets[1]);
  object.fromName = reader.readString(offsets[2]);
  object.id = id;
  object.lastPageId = reader.readLongOrNull(offsets[3]);
  object.lastSeenAt = reader.readDateTime(offsets[4]);
  object.notebookId = reader.readLong(offsets[5]);
  object.relation = reader.readString(offsets[6]);
  object.toKey = reader.readString(offsets[7]);
  object.toName = reader.readString(offsets[8]);
  return object;
}

P _conceptRelationRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDouble(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _conceptRelationRecordGetId(ConceptRelationRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _conceptRelationRecordGetLinks(
    ConceptRelationRecord object) {
  return [];
}

void _conceptRelationRecordAttach(
    IsarCollection<dynamic> col, Id id, ConceptRelationRecord object) {
  object.id = id;
}

extension ConceptRelationRecordQueryWhereSort
    on QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QWhere> {
  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterWhere>
      anyNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'notebookId'),
      );
    });
  }
}

extension ConceptRelationRecordQueryWhere on QueryBuilder<ConceptRelationRecord,
    ConceptRelationRecord, QWhereClause> {
  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterWhereClause>
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterWhereClause>
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterWhereClause>
      notebookIdEqualTo(int notebookId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'notebookId',
        value: [notebookId],
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterWhereClause>
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterWhereClause>
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterWhereClause>
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterWhereClause>
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterWhereClause>
      fromKeyEqualTo(String fromKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'fromKey',
        value: [fromKey],
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterWhereClause>
      fromKeyNotEqualTo(String fromKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'fromKey',
              lower: [],
              upper: [fromKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'fromKey',
              lower: [fromKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'fromKey',
              lower: [fromKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'fromKey',
              lower: [],
              upper: [fromKey],
              includeUpper: false,
            ));
      }
    });
  }
}

extension ConceptRelationRecordQueryFilter on QueryBuilder<
    ConceptRelationRecord, ConceptRelationRecord, QFilterCondition> {
  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> confidenceEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'confidence',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> confidenceGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'confidence',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> confidenceLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'confidence',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> confidenceBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'confidence',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> fromKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fromKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> fromKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fromKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> fromKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fromKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> fromKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fromKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> fromKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'fromKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> fromKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'fromKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
          QAfterFilterCondition>
      fromKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'fromKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
          QAfterFilterCondition>
      fromKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'fromKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> fromKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fromKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> fromKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'fromKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> fromNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fromName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> fromNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fromName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> fromNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fromName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> fromNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fromName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> fromNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'fromName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> fromNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'fromName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
          QAfterFilterCondition>
      fromNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'fromName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
          QAfterFilterCondition>
      fromNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'fromName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> fromNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fromName',
        value: '',
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> fromNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'fromName',
        value: '',
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> lastPageIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastPageId',
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> lastPageIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastPageId',
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> lastPageIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastPageId',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> lastSeenAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastSeenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> notebookIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notebookId',
        value: value,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
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

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> relationEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> relationGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> relationLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> relationBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'relation',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> relationStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> relationEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
          QAfterFilterCondition>
      relationContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
          QAfterFilterCondition>
      relationMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'relation',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> relationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'relation',
        value: '',
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> relationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'relation',
        value: '',
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> toKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'toKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> toKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'toKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> toKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'toKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> toKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'toKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> toKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'toKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> toKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'toKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
          QAfterFilterCondition>
      toKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'toKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
          QAfterFilterCondition>
      toKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'toKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> toKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'toKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> toKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'toKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> toNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'toName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> toNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'toName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> toNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'toName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> toNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'toName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> toNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'toName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> toNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'toName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
          QAfterFilterCondition>
      toNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'toName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
          QAfterFilterCondition>
      toNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'toName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> toNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'toName',
        value: '',
      ));
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord,
      QAfterFilterCondition> toNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'toName',
        value: '',
      ));
    });
  }
}

extension ConceptRelationRecordQueryObject on QueryBuilder<
    ConceptRelationRecord, ConceptRelationRecord, QFilterCondition> {}

extension ConceptRelationRecordQueryLinks on QueryBuilder<ConceptRelationRecord,
    ConceptRelationRecord, QFilterCondition> {}

extension ConceptRelationRecordQuerySortBy
    on QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QSortBy> {
  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByConfidence() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confidence', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByConfidenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confidence', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByFromKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromKey', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByFromKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromKey', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByFromName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromName', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByFromNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromName', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByLastPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPageId', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByLastPageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPageId', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByLastSeenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByNotebookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByRelation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relation', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByRelationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relation', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByToKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toKey', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByToKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toKey', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByToName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toName', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      sortByToNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toName', Sort.desc);
    });
  }
}

extension ConceptRelationRecordQuerySortThenBy
    on QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QSortThenBy> {
  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByConfidence() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confidence', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByConfidenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confidence', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByFromKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromKey', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByFromKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromKey', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByFromName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromName', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByFromNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromName', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByLastPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPageId', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByLastPageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPageId', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByLastSeenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByNotebookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByRelation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relation', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByRelationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relation', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByToKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toKey', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByToKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toKey', Sort.desc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByToName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toName', Sort.asc);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QAfterSortBy>
      thenByToNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toName', Sort.desc);
    });
  }
}

extension ConceptRelationRecordQueryWhereDistinct
    on QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QDistinct> {
  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QDistinct>
      distinctByConfidence() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'confidence');
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QDistinct>
      distinctByFromKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fromKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QDistinct>
      distinctByFromName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fromName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QDistinct>
      distinctByLastPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastPageId');
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QDistinct>
      distinctByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSeenAt');
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QDistinct>
      distinctByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notebookId');
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QDistinct>
      distinctByRelation({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'relation', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QDistinct>
      distinctByToKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'toKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ConceptRelationRecord, ConceptRelationRecord, QDistinct>
      distinctByToName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'toName', caseSensitive: caseSensitive);
    });
  }
}

extension ConceptRelationRecordQueryProperty on QueryBuilder<
    ConceptRelationRecord, ConceptRelationRecord, QQueryProperty> {
  QueryBuilder<ConceptRelationRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ConceptRelationRecord, double, QQueryOperations>
      confidenceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'confidence');
    });
  }

  QueryBuilder<ConceptRelationRecord, String, QQueryOperations>
      fromKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fromKey');
    });
  }

  QueryBuilder<ConceptRelationRecord, String, QQueryOperations>
      fromNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fromName');
    });
  }

  QueryBuilder<ConceptRelationRecord, int?, QQueryOperations>
      lastPageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastPageId');
    });
  }

  QueryBuilder<ConceptRelationRecord, DateTime, QQueryOperations>
      lastSeenAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSeenAt');
    });
  }

  QueryBuilder<ConceptRelationRecord, int, QQueryOperations>
      notebookIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notebookId');
    });
  }

  QueryBuilder<ConceptRelationRecord, String, QQueryOperations>
      relationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'relation');
    });
  }

  QueryBuilder<ConceptRelationRecord, String, QQueryOperations>
      toKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'toKey');
    });
  }

  QueryBuilder<ConceptRelationRecord, String, QQueryOperations>
      toNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'toName');
    });
  }
}
