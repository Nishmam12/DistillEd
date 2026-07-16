// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'summary_cache.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSummaryCacheCollection on Isar {
  IsarCollection<SummaryCache> get summaryCaches => this.collection();
}

const SummaryCacheSchema = CollectionSchema(
  name: r'SummaryCache',
  id: -3308921853868882559,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'modelUsed': PropertySchema(
      id: 1,
      name: r'modelUsed',
      type: IsarType.string,
    ),
    r'notebookId': PropertySchema(
      id: 2,
      name: r'notebookId',
      type: IsarType.long,
    ),
    r'summary': PropertySchema(
      id: 3,
      name: r'summary',
      type: IsarType.string,
    ),
    r'textHash': PropertySchema(
      id: 4,
      name: r'textHash',
      type: IsarType.string,
    )
  },
  estimateSize: _summaryCacheEstimateSize,
  serialize: _summaryCacheSerialize,
  deserialize: _summaryCacheDeserialize,
  deserializeProp: _summaryCacheDeserializeProp,
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
  embeddedSchemas: {},
  getId: _summaryCacheGetId,
  getLinks: _summaryCacheGetLinks,
  attach: _summaryCacheAttach,
  version: '3.1.0+1',
);

int _summaryCacheEstimateSize(
  SummaryCache object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.modelUsed.length * 3;
  bytesCount += 3 + object.summary.length * 3;
  bytesCount += 3 + object.textHash.length * 3;
  return bytesCount;
}

void _summaryCacheSerialize(
  SummaryCache object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.modelUsed);
  writer.writeLong(offsets[2], object.notebookId);
  writer.writeString(offsets[3], object.summary);
  writer.writeString(offsets[4], object.textHash);
}

SummaryCache _summaryCacheDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SummaryCache();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.modelUsed = reader.readString(offsets[1]);
  object.notebookId = reader.readLong(offsets[2]);
  object.summary = reader.readString(offsets[3]);
  object.textHash = reader.readString(offsets[4]);
  return object;
}

P _summaryCacheDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _summaryCacheGetId(SummaryCache object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _summaryCacheGetLinks(SummaryCache object) {
  return [];
}

void _summaryCacheAttach(
    IsarCollection<dynamic> col, Id id, SummaryCache object) {
  object.id = id;
}

extension SummaryCacheQueryWhereSort
    on QueryBuilder<SummaryCache, SummaryCache, QWhere> {
  QueryBuilder<SummaryCache, SummaryCache, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterWhere> anyNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'notebookId'),
      );
    });
  }
}

extension SummaryCacheQueryWhere
    on QueryBuilder<SummaryCache, SummaryCache, QWhereClause> {
  QueryBuilder<SummaryCache, SummaryCache, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterWhereClause> idNotEqualTo(
      Id id) {
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

  QueryBuilder<SummaryCache, SummaryCache, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterWhereClause> idBetween(
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

  QueryBuilder<SummaryCache, SummaryCache, QAfterWhereClause> notebookIdEqualTo(
      int notebookId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'notebookId',
        value: [notebookId],
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterWhereClause>
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

  QueryBuilder<SummaryCache, SummaryCache, QAfterWhereClause>
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

  QueryBuilder<SummaryCache, SummaryCache, QAfterWhereClause>
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

  QueryBuilder<SummaryCache, SummaryCache, QAfterWhereClause> notebookIdBetween(
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

extension SummaryCacheQueryFilter
    on QueryBuilder<SummaryCache, SummaryCache, QFilterCondition> {
  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
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

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
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

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
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

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition> idBetween(
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

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      modelUsedEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'modelUsed',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      modelUsedGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'modelUsed',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      modelUsedLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'modelUsed',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      modelUsedBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'modelUsed',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      modelUsedStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'modelUsed',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      modelUsedEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'modelUsed',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      modelUsedContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'modelUsed',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      modelUsedMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'modelUsed',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      modelUsedIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'modelUsed',
        value: '',
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      modelUsedIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'modelUsed',
        value: '',
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      notebookIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notebookId',
        value: value,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
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

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
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

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
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

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      summaryEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      summaryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      summaryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      summaryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'summary',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      summaryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      summaryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      summaryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      summaryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'summary',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      summaryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'summary',
        value: '',
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      summaryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'summary',
        value: '',
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      textHashEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'textHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      textHashGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'textHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      textHashLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'textHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      textHashBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'textHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      textHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'textHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      textHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'textHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      textHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'textHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      textHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'textHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      textHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'textHash',
        value: '',
      ));
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterFilterCondition>
      textHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'textHash',
        value: '',
      ));
    });
  }
}

extension SummaryCacheQueryObject
    on QueryBuilder<SummaryCache, SummaryCache, QFilterCondition> {}

extension SummaryCacheQueryLinks
    on QueryBuilder<SummaryCache, SummaryCache, QFilterCondition> {}

extension SummaryCacheQuerySortBy
    on QueryBuilder<SummaryCache, SummaryCache, QSortBy> {
  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> sortByModelUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'modelUsed', Sort.asc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> sortByModelUsedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'modelUsed', Sort.desc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> sortByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.asc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy>
      sortByNotebookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.desc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> sortBySummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.asc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> sortBySummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.desc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> sortByTextHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'textHash', Sort.asc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> sortByTextHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'textHash', Sort.desc);
    });
  }
}

extension SummaryCacheQuerySortThenBy
    on QueryBuilder<SummaryCache, SummaryCache, QSortThenBy> {
  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> thenByModelUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'modelUsed', Sort.asc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> thenByModelUsedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'modelUsed', Sort.desc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> thenByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.asc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy>
      thenByNotebookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.desc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> thenBySummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.asc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> thenBySummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.desc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> thenByTextHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'textHash', Sort.asc);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QAfterSortBy> thenByTextHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'textHash', Sort.desc);
    });
  }
}

extension SummaryCacheQueryWhereDistinct
    on QueryBuilder<SummaryCache, SummaryCache, QDistinct> {
  QueryBuilder<SummaryCache, SummaryCache, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QDistinct> distinctByModelUsed(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'modelUsed', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QDistinct> distinctByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notebookId');
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QDistinct> distinctBySummary(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'summary', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SummaryCache, SummaryCache, QDistinct> distinctByTextHash(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'textHash', caseSensitive: caseSensitive);
    });
  }
}

extension SummaryCacheQueryProperty
    on QueryBuilder<SummaryCache, SummaryCache, QQueryProperty> {
  QueryBuilder<SummaryCache, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SummaryCache, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<SummaryCache, String, QQueryOperations> modelUsedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'modelUsed');
    });
  }

  QueryBuilder<SummaryCache, int, QQueryOperations> notebookIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notebookId');
    });
  }

  QueryBuilder<SummaryCache, String, QQueryOperations> summaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'summary');
    });
  }

  QueryBuilder<SummaryCache, String, QQueryOperations> textHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'textHash');
    });
  }
}
