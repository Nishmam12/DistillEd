// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_page.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetNotePageCollection on Isar {
  IsarCollection<NotePage> get notePages => this.collection();
}

const NotePageSchema = CollectionSchema(
  name: r'NotePage',
  id: 6257063127094562748,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'importGroupId': PropertySchema(
      id: 1,
      name: r'importGroupId',
      type: IsarType.string,
    ),
    r'importSourceName': PropertySchema(
      id: 2,
      name: r'importSourceName',
      type: IsarType.string,
    ),
    r'importedContents': PropertySchema(
      id: 3,
      name: r'importedContents',
      type: IsarType.objectList,
      target: r'ImportedContent',
    ),
    r'modifiedAt': PropertySchema(
      id: 4,
      name: r'modifiedAt',
      type: IsarType.dateTime,
    ),
    r'notebookId': PropertySchema(
      id: 5,
      name: r'notebookId',
      type: IsarType.long,
    ),
    r'pageIndex': PropertySchema(
      id: 6,
      name: r'pageIndex',
      type: IsarType.long,
    ),
    r'shapes': PropertySchema(
      id: 7,
      name: r'shapes',
      type: IsarType.objectList,
      target: r'ShapeElement',
    )
  },
  estimateSize: _notePageEstimateSize,
  serialize: _notePageSerialize,
  deserialize: _notePageDeserialize,
  deserializeProp: _notePageDeserializeProp,
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
    r'importGroupId': IndexSchema(
      id: 5197486995016734919,
      name: r'importGroupId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'importGroupId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {
    r'ImportedContent': ImportedContentSchema,
    r'ShapeElement': ShapeElementSchema
  },
  getId: _notePageGetId,
  getLinks: _notePageGetLinks,
  attach: _notePageAttach,
  version: '3.1.0+1',
);

int _notePageEstimateSize(
  NotePage object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.importGroupId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.importSourceName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.importedContents.length * 3;
  {
    final offsets = allOffsets[ImportedContent]!;
    for (var i = 0; i < object.importedContents.length; i++) {
      final value = object.importedContents[i];
      bytesCount +=
          ImportedContentSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  bytesCount += 3 + object.shapes.length * 3;
  {
    final offsets = allOffsets[ShapeElement]!;
    for (var i = 0; i < object.shapes.length; i++) {
      final value = object.shapes[i];
      bytesCount += ShapeElementSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  return bytesCount;
}

void _notePageSerialize(
  NotePage object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.importGroupId);
  writer.writeString(offsets[2], object.importSourceName);
  writer.writeObjectList<ImportedContent>(
    offsets[3],
    allOffsets,
    ImportedContentSchema.serialize,
    object.importedContents,
  );
  writer.writeDateTime(offsets[4], object.modifiedAt);
  writer.writeLong(offsets[5], object.notebookId);
  writer.writeLong(offsets[6], object.pageIndex);
  writer.writeObjectList<ShapeElement>(
    offsets[7],
    allOffsets,
    ShapeElementSchema.serialize,
    object.shapes,
  );
}

NotePage _notePageDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = NotePage();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.importGroupId = reader.readStringOrNull(offsets[1]);
  object.importSourceName = reader.readStringOrNull(offsets[2]);
  object.importedContents = reader.readObjectList<ImportedContent>(
        offsets[3],
        ImportedContentSchema.deserialize,
        allOffsets,
        ImportedContent(),
      ) ??
      [];
  object.modifiedAt = reader.readDateTime(offsets[4]);
  object.notebookId = reader.readLong(offsets[5]);
  object.pageIndex = reader.readLong(offsets[6]);
  object.shapes = reader.readObjectList<ShapeElement>(
        offsets[7],
        ShapeElementSchema.deserialize,
        allOffsets,
        ShapeElement(),
      ) ??
      [];
  return object;
}

P _notePageDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readObjectList<ImportedContent>(
            offset,
            ImportedContentSchema.deserialize,
            allOffsets,
            ImportedContent(),
          ) ??
          []) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readObjectList<ShapeElement>(
            offset,
            ShapeElementSchema.deserialize,
            allOffsets,
            ShapeElement(),
          ) ??
          []) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _notePageGetId(NotePage object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _notePageGetLinks(NotePage object) {
  return [];
}

void _notePageAttach(IsarCollection<dynamic> col, Id id, NotePage object) {
  object.id = id;
}

extension NotePageQueryWhereSort on QueryBuilder<NotePage, NotePage, QWhere> {
  QueryBuilder<NotePage, NotePage, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterWhere> anyNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'notebookId'),
      );
    });
  }
}

extension NotePageQueryWhere on QueryBuilder<NotePage, NotePage, QWhereClause> {
  QueryBuilder<NotePage, NotePage, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<NotePage, NotePage, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterWhereClause> idBetween(
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

  QueryBuilder<NotePage, NotePage, QAfterWhereClause> notebookIdEqualTo(
      int notebookId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'notebookId',
        value: [notebookId],
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterWhereClause> notebookIdNotEqualTo(
      int notebookId) {
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

  QueryBuilder<NotePage, NotePage, QAfterWhereClause> notebookIdGreaterThan(
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

  QueryBuilder<NotePage, NotePage, QAfterWhereClause> notebookIdLessThan(
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

  QueryBuilder<NotePage, NotePage, QAfterWhereClause> notebookIdBetween(
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

  QueryBuilder<NotePage, NotePage, QAfterWhereClause> importGroupIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'importGroupId',
        value: [null],
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterWhereClause> importGroupIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'importGroupId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterWhereClause> importGroupIdEqualTo(
      String? importGroupId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'importGroupId',
        value: [importGroupId],
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterWhereClause> importGroupIdNotEqualTo(
      String? importGroupId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'importGroupId',
              lower: [],
              upper: [importGroupId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'importGroupId',
              lower: [importGroupId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'importGroupId',
              lower: [importGroupId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'importGroupId',
              lower: [],
              upper: [importGroupId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension NotePageQueryFilter
    on QueryBuilder<NotePage, NotePage, QFilterCondition> {
  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> createdAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> createdAtGreaterThan(
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

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> createdAtLessThan(
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

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> createdAtBetween(
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

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> idBetween(
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

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importGroupIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'importGroupId',
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importGroupIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'importGroupId',
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> importGroupIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'importGroupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importGroupIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'importGroupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> importGroupIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'importGroupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> importGroupIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'importGroupId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importGroupIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'importGroupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> importGroupIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'importGroupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> importGroupIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'importGroupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> importGroupIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'importGroupId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importGroupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'importGroupId',
        value: '',
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importGroupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'importGroupId',
        value: '',
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importSourceNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'importSourceName',
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importSourceNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'importSourceName',
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importSourceNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'importSourceName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importSourceNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'importSourceName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importSourceNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'importSourceName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importSourceNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'importSourceName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importSourceNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'importSourceName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importSourceNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'importSourceName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importSourceNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'importSourceName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importSourceNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'importSourceName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importSourceNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'importSourceName',
        value: '',
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importSourceNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'importSourceName',
        value: '',
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importedContentsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'importedContents',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importedContentsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'importedContents',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importedContentsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'importedContents',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importedContentsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'importedContents',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importedContentsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'importedContents',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importedContentsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'importedContents',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> modifiedAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'modifiedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> modifiedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'modifiedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> modifiedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'modifiedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> modifiedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'modifiedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> notebookIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notebookId',
        value: value,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> notebookIdGreaterThan(
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

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> notebookIdLessThan(
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

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> notebookIdBetween(
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

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> pageIndexEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pageIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> pageIndexGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pageIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> pageIndexLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pageIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> pageIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pageIndex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> shapesLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'shapes',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> shapesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'shapes',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> shapesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'shapes',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> shapesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'shapes',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      shapesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'shapes',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> shapesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'shapes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension NotePageQueryObject
    on QueryBuilder<NotePage, NotePage, QFilterCondition> {
  QueryBuilder<NotePage, NotePage, QAfterFilterCondition>
      importedContentsElement(FilterQuery<ImportedContent> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'importedContents');
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterFilterCondition> shapesElement(
      FilterQuery<ShapeElement> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'shapes');
    });
  }
}

extension NotePageQueryLinks
    on QueryBuilder<NotePage, NotePage, QFilterCondition> {}

extension NotePageQuerySortBy on QueryBuilder<NotePage, NotePage, QSortBy> {
  QueryBuilder<NotePage, NotePage, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> sortByImportGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'importGroupId', Sort.asc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> sortByImportGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'importGroupId', Sort.desc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> sortByImportSourceName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'importSourceName', Sort.asc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> sortByImportSourceNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'importSourceName', Sort.desc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> sortByModifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'modifiedAt', Sort.asc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> sortByModifiedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'modifiedAt', Sort.desc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> sortByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.asc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> sortByNotebookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.desc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> sortByPageIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageIndex', Sort.asc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> sortByPageIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageIndex', Sort.desc);
    });
  }
}

extension NotePageQuerySortThenBy
    on QueryBuilder<NotePage, NotePage, QSortThenBy> {
  QueryBuilder<NotePage, NotePage, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> thenByImportGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'importGroupId', Sort.asc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> thenByImportGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'importGroupId', Sort.desc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> thenByImportSourceName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'importSourceName', Sort.asc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> thenByImportSourceNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'importSourceName', Sort.desc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> thenByModifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'modifiedAt', Sort.asc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> thenByModifiedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'modifiedAt', Sort.desc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> thenByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.asc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> thenByNotebookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.desc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> thenByPageIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageIndex', Sort.asc);
    });
  }

  QueryBuilder<NotePage, NotePage, QAfterSortBy> thenByPageIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageIndex', Sort.desc);
    });
  }
}

extension NotePageQueryWhereDistinct
    on QueryBuilder<NotePage, NotePage, QDistinct> {
  QueryBuilder<NotePage, NotePage, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<NotePage, NotePage, QDistinct> distinctByImportGroupId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'importGroupId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NotePage, NotePage, QDistinct> distinctByImportSourceName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'importSourceName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NotePage, NotePage, QDistinct> distinctByModifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'modifiedAt');
    });
  }

  QueryBuilder<NotePage, NotePage, QDistinct> distinctByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notebookId');
    });
  }

  QueryBuilder<NotePage, NotePage, QDistinct> distinctByPageIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pageIndex');
    });
  }
}

extension NotePageQueryProperty
    on QueryBuilder<NotePage, NotePage, QQueryProperty> {
  QueryBuilder<NotePage, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<NotePage, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<NotePage, String?, QQueryOperations> importGroupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'importGroupId');
    });
  }

  QueryBuilder<NotePage, String?, QQueryOperations> importSourceNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'importSourceName');
    });
  }

  QueryBuilder<NotePage, List<ImportedContent>, QQueryOperations>
      importedContentsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'importedContents');
    });
  }

  QueryBuilder<NotePage, DateTime, QQueryOperations> modifiedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'modifiedAt');
    });
  }

  QueryBuilder<NotePage, int, QQueryOperations> notebookIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notebookId');
    });
  }

  QueryBuilder<NotePage, int, QQueryOperations> pageIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pageIndex');
    });
  }

  QueryBuilder<NotePage, List<ShapeElement>, QQueryOperations>
      shapesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'shapes');
    });
  }
}
