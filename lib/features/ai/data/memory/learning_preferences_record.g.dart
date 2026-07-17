// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_preferences_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLearningPreferencesRecordCollection on Isar {
  IsarCollection<LearningPreferencesRecord> get learningPreferencesRecords =>
      this.collection();
}

const LearningPreferencesRecordSchema = CollectionSchema(
  name: r'LearningPreferencesRecord',
  id: -422704975788470747,
  properties: {
    r'preferredDifficulty': PropertySchema(
      id: 0,
      name: r'preferredDifficulty',
      type: IsarType.string,
    ),
    r'preferredExplainMode': PropertySchema(
      id: 1,
      name: r'preferredExplainMode',
      type: IsarType.string,
    )
  },
  estimateSize: _learningPreferencesRecordEstimateSize,
  serialize: _learningPreferencesRecordSerialize,
  deserialize: _learningPreferencesRecordDeserialize,
  deserializeProp: _learningPreferencesRecordDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _learningPreferencesRecordGetId,
  getLinks: _learningPreferencesRecordGetLinks,
  attach: _learningPreferencesRecordAttach,
  version: '3.1.0+1',
);

int _learningPreferencesRecordEstimateSize(
  LearningPreferencesRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.preferredDifficulty;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.preferredExplainMode;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _learningPreferencesRecordSerialize(
  LearningPreferencesRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.preferredDifficulty);
  writer.writeString(offsets[1], object.preferredExplainMode);
}

LearningPreferencesRecord _learningPreferencesRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LearningPreferencesRecord();
  object.id = id;
  object.preferredDifficulty = reader.readStringOrNull(offsets[0]);
  object.preferredExplainMode = reader.readStringOrNull(offsets[1]);
  return object;
}

P _learningPreferencesRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _learningPreferencesRecordGetId(LearningPreferencesRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _learningPreferencesRecordGetLinks(
    LearningPreferencesRecord object) {
  return [];
}

void _learningPreferencesRecordAttach(
    IsarCollection<dynamic> col, Id id, LearningPreferencesRecord object) {
  object.id = id;
}

extension LearningPreferencesRecordQueryWhereSort on QueryBuilder<
    LearningPreferencesRecord, LearningPreferencesRecord, QWhere> {
  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LearningPreferencesRecordQueryWhere on QueryBuilder<
    LearningPreferencesRecord, LearningPreferencesRecord, QWhereClause> {
  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterWhereClause> idBetween(
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
}

extension LearningPreferencesRecordQueryFilter on QueryBuilder<
    LearningPreferencesRecord, LearningPreferencesRecord, QFilterCondition> {
  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
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

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
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

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
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

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredDifficultyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'preferredDifficulty',
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredDifficultyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'preferredDifficulty',
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredDifficultyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'preferredDifficulty',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredDifficultyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'preferredDifficulty',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredDifficultyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'preferredDifficulty',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredDifficultyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'preferredDifficulty',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredDifficultyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'preferredDifficulty',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredDifficultyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'preferredDifficulty',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
          QAfterFilterCondition>
      preferredDifficultyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'preferredDifficulty',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
          QAfterFilterCondition>
      preferredDifficultyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'preferredDifficulty',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredDifficultyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'preferredDifficulty',
        value: '',
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredDifficultyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'preferredDifficulty',
        value: '',
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredExplainModeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'preferredExplainMode',
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredExplainModeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'preferredExplainMode',
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredExplainModeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'preferredExplainMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredExplainModeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'preferredExplainMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredExplainModeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'preferredExplainMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredExplainModeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'preferredExplainMode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredExplainModeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'preferredExplainMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredExplainModeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'preferredExplainMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
          QAfterFilterCondition>
      preferredExplainModeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'preferredExplainMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
          QAfterFilterCondition>
      preferredExplainModeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'preferredExplainMode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredExplainModeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'preferredExplainMode',
        value: '',
      ));
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterFilterCondition> preferredExplainModeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'preferredExplainMode',
        value: '',
      ));
    });
  }
}

extension LearningPreferencesRecordQueryObject on QueryBuilder<
    LearningPreferencesRecord, LearningPreferencesRecord, QFilterCondition> {}

extension LearningPreferencesRecordQueryLinks on QueryBuilder<
    LearningPreferencesRecord, LearningPreferencesRecord, QFilterCondition> {}

extension LearningPreferencesRecordQuerySortBy on QueryBuilder<
    LearningPreferencesRecord, LearningPreferencesRecord, QSortBy> {
  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterSortBy> sortByPreferredDifficulty() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferredDifficulty', Sort.asc);
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterSortBy> sortByPreferredDifficultyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferredDifficulty', Sort.desc);
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterSortBy> sortByPreferredExplainMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferredExplainMode', Sort.asc);
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterSortBy> sortByPreferredExplainModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferredExplainMode', Sort.desc);
    });
  }
}

extension LearningPreferencesRecordQuerySortThenBy on QueryBuilder<
    LearningPreferencesRecord, LearningPreferencesRecord, QSortThenBy> {
  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterSortBy> thenByPreferredDifficulty() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferredDifficulty', Sort.asc);
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterSortBy> thenByPreferredDifficultyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferredDifficulty', Sort.desc);
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterSortBy> thenByPreferredExplainMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferredExplainMode', Sort.asc);
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord,
      QAfterSortBy> thenByPreferredExplainModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferredExplainMode', Sort.desc);
    });
  }
}

extension LearningPreferencesRecordQueryWhereDistinct on QueryBuilder<
    LearningPreferencesRecord, LearningPreferencesRecord, QDistinct> {
  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord, QDistinct>
      distinctByPreferredDifficulty({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'preferredDifficulty',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LearningPreferencesRecord, LearningPreferencesRecord, QDistinct>
      distinctByPreferredExplainMode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'preferredExplainMode',
          caseSensitive: caseSensitive);
    });
  }
}

extension LearningPreferencesRecordQueryProperty on QueryBuilder<
    LearningPreferencesRecord, LearningPreferencesRecord, QQueryProperty> {
  QueryBuilder<LearningPreferencesRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LearningPreferencesRecord, String?, QQueryOperations>
      preferredDifficultyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'preferredDifficulty');
    });
  }

  QueryBuilder<LearningPreferencesRecord, String?, QQueryOperations>
      preferredExplainModeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'preferredExplainMode');
    });
  }
}
