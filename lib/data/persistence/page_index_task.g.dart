// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_index_task.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPageIndexTaskCollection on Isar {
  IsarCollection<PageIndexTask> get pageIndexTasks => this.collection();
}

const PageIndexTaskSchema = CollectionSchema(
  name: r'PageIndexTask',
  id: 2943648397649867094,
  properties: {
    r'attempts': PropertySchema(id: 0, name: r'attempts', type: IsarType.long),
    r'modifiedAt': PropertySchema(
      id: 1,
      name: r'modifiedAt',
      type: IsarType.dateTime,
    ),
    r'pageId': PropertySchema(id: 2, name: r'pageId', type: IsarType.long),
    r'state': PropertySchema(
      id: 3,
      name: r'state',
      type: IsarType.byte,
      enumMap: _PageIndexTaskstateEnumValueMap,
    ),
  },

  estimateSize: _pageIndexTaskEstimateSize,
  serialize: _pageIndexTaskSerialize,
  deserialize: _pageIndexTaskDeserialize,
  deserializeProp: _pageIndexTaskDeserializeProp,
  idName: r'id',
  indexes: {
    r'pageId': IndexSchema(
      id: 3928962759474932809,
      name: r'pageId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'pageId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'state': IndexSchema(
      id: 7917036384617311412,
      name: r'state',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'state',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _pageIndexTaskGetId,
  getLinks: _pageIndexTaskGetLinks,
  attach: _pageIndexTaskAttach,
  version: '3.3.2',
);

int _pageIndexTaskEstimateSize(
  PageIndexTask object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _pageIndexTaskSerialize(
  PageIndexTask object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.attempts);
  writer.writeDateTime(offsets[1], object.modifiedAt);
  writer.writeLong(offsets[2], object.pageId);
  writer.writeByte(offsets[3], object.state.index);
}

PageIndexTask _pageIndexTaskDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PageIndexTask();
  object.attempts = reader.readLong(offsets[0]);
  object.id = id;
  object.modifiedAt = reader.readDateTime(offsets[1]);
  object.pageId = reader.readLong(offsets[2]);
  object.state =
      _PageIndexTaskstateValueEnumMap[reader.readByteOrNull(offsets[3])] ??
      PageIndexState.ready;
  return object;
}

P _pageIndexTaskDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (_PageIndexTaskstateValueEnumMap[reader.readByteOrNull(offset)] ??
              PageIndexState.ready)
          as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _PageIndexTaskstateEnumValueMap = {'ready': 0, 'done': 1, 'failed': 2};
const _PageIndexTaskstateValueEnumMap = {
  0: PageIndexState.ready,
  1: PageIndexState.done,
  2: PageIndexState.failed,
};

Id _pageIndexTaskGetId(PageIndexTask object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _pageIndexTaskGetLinks(PageIndexTask object) {
  return [];
}

void _pageIndexTaskAttach(
  IsarCollection<dynamic> col,
  Id id,
  PageIndexTask object,
) {
  object.id = id;
}

extension PageIndexTaskQueryWhereSort
    on QueryBuilder<PageIndexTask, PageIndexTask, QWhere> {
  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhere> anyPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'pageId'),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhere> anyState() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'state'),
      );
    });
  }
}

extension PageIndexTaskQueryWhere
    on QueryBuilder<PageIndexTask, PageIndexTask, QWhereClause> {
  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
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

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhereClause> pageIdEqualTo(
    int pageId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'pageId', value: [pageId]),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhereClause>
  pageIdNotEqualTo(int pageId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'pageId',
                lower: [],
                upper: [pageId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'pageId',
                lower: [pageId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'pageId',
                lower: [pageId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'pageId',
                lower: [],
                upper: [pageId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhereClause>
  pageIdGreaterThan(int pageId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'pageId',
          lower: [pageId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhereClause> pageIdLessThan(
    int pageId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'pageId',
          lower: [],
          upper: [pageId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhereClause> pageIdBetween(
    int lowerPageId,
    int upperPageId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'pageId',
          lower: [lowerPageId],
          includeLower: includeLower,
          upper: [upperPageId],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhereClause> stateEqualTo(
    PageIndexState state,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'state', value: [state]),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhereClause> stateNotEqualTo(
    PageIndexState state,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [],
                upper: [state],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [state],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [state],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [],
                upper: [state],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhereClause>
  stateGreaterThan(PageIndexState state, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'state',
          lower: [state],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhereClause> stateLessThan(
    PageIndexState state, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'state',
          lower: [],
          upper: [state],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterWhereClause> stateBetween(
    PageIndexState lowerState,
    PageIndexState upperState, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'state',
          lower: [lowerState],
          includeLower: includeLower,
          upper: [upperState],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension PageIndexTaskQueryFilter
    on QueryBuilder<PageIndexTask, PageIndexTask, QFilterCondition> {
  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  attemptsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'attempts', value: value),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  attemptsGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'attempts',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  attemptsLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'attempts',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  attemptsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'attempts',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  modifiedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'modifiedAt', value: value),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  modifiedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'modifiedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  modifiedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'modifiedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  modifiedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'modifiedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  pageIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'pageId', value: value),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  pageIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'pageId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  pageIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'pageId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  pageIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'pageId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  stateEqualTo(PageIndexState value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'state', value: value),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  stateGreaterThan(PageIndexState value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'state',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  stateLessThan(PageIndexState value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'state',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterFilterCondition>
  stateBetween(
    PageIndexState lower,
    PageIndexState upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'state',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension PageIndexTaskQueryObject
    on QueryBuilder<PageIndexTask, PageIndexTask, QFilterCondition> {}

extension PageIndexTaskQueryLinks
    on QueryBuilder<PageIndexTask, PageIndexTask, QFilterCondition> {}

extension PageIndexTaskQuerySortBy
    on QueryBuilder<PageIndexTask, PageIndexTask, QSortBy> {
  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy> sortByAttempts() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attempts', Sort.asc);
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy>
  sortByAttemptsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attempts', Sort.desc);
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy> sortByModifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'modifiedAt', Sort.asc);
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy>
  sortByModifiedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'modifiedAt', Sort.desc);
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy> sortByPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageId', Sort.asc);
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy> sortByPageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageId', Sort.desc);
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy> sortByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy> sortByStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
    });
  }
}

extension PageIndexTaskQuerySortThenBy
    on QueryBuilder<PageIndexTask, PageIndexTask, QSortThenBy> {
  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy> thenByAttempts() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attempts', Sort.asc);
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy>
  thenByAttemptsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attempts', Sort.desc);
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy> thenByModifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'modifiedAt', Sort.asc);
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy>
  thenByModifiedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'modifiedAt', Sort.desc);
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy> thenByPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageId', Sort.asc);
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy> thenByPageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageId', Sort.desc);
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy> thenByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QAfterSortBy> thenByStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
    });
  }
}

extension PageIndexTaskQueryWhereDistinct
    on QueryBuilder<PageIndexTask, PageIndexTask, QDistinct> {
  QueryBuilder<PageIndexTask, PageIndexTask, QDistinct> distinctByAttempts() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attempts');
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QDistinct> distinctByModifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'modifiedAt');
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QDistinct> distinctByPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pageId');
    });
  }

  QueryBuilder<PageIndexTask, PageIndexTask, QDistinct> distinctByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'state');
    });
  }
}

extension PageIndexTaskQueryProperty
    on QueryBuilder<PageIndexTask, PageIndexTask, QQueryProperty> {
  QueryBuilder<PageIndexTask, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PageIndexTask, int, QQueryOperations> attemptsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attempts');
    });
  }

  QueryBuilder<PageIndexTask, DateTime, QQueryOperations> modifiedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'modifiedAt');
    });
  }

  QueryBuilder<PageIndexTask, int, QQueryOperations> pageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pageId');
    });
  }

  QueryBuilder<PageIndexTask, PageIndexState, QQueryOperations>
  stateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'state');
    });
  }
}
