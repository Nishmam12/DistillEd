// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_chunk_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetNoteChunkRecordCollection on Isar {
  IsarCollection<NoteChunkRecord> get noteChunkRecords => this.collection();
}

const NoteChunkRecordSchema = CollectionSchema(
  name: r'NoteChunkRecord',
  id: 4775907510623749022,
  properties: {
    r'contentSignature': PropertySchema(
      id: 0,
      name: r'contentSignature',
      type: IsarType.string,
    ),
    r'embeddedAt': PropertySchema(
      id: 1,
      name: r'embeddedAt',
      type: IsarType.dateTime,
    ),
    r'embedding': PropertySchema(
      id: 2,
      name: r'embedding',
      type: IsarType.floatList,
    ),
    r'embeddingModelId': PropertySchema(
      id: 3,
      name: r'embeddingModelId',
      type: IsarType.string,
    ),
    r'notebookId': PropertySchema(
      id: 4,
      name: r'notebookId',
      type: IsarType.long,
    ),
    r'ordinal': PropertySchema(
      id: 5,
      name: r'ordinal',
      type: IsarType.long,
    ),
    r'pageId': PropertySchema(
      id: 6,
      name: r'pageId',
      type: IsarType.long,
    ),
    r'text': PropertySchema(
      id: 7,
      name: r'text',
      type: IsarType.string,
    )
  },
  estimateSize: _noteChunkRecordEstimateSize,
  serialize: _noteChunkRecordSerialize,
  deserialize: _noteChunkRecordDeserialize,
  deserializeProp: _noteChunkRecordDeserializeProp,
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
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _noteChunkRecordGetId,
  getLinks: _noteChunkRecordGetLinks,
  attach: _noteChunkRecordAttach,
  version: '3.1.0+1',
);

int _noteChunkRecordEstimateSize(
  NoteChunkRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.contentSignature.length * 3;
  bytesCount += 3 + object.embedding.length * 4;
  bytesCount += 3 + object.embeddingModelId.length * 3;
  bytesCount += 3 + object.text.length * 3;
  return bytesCount;
}

void _noteChunkRecordSerialize(
  NoteChunkRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.contentSignature);
  writer.writeDateTime(offsets[1], object.embeddedAt);
  writer.writeFloatList(offsets[2], object.embedding);
  writer.writeString(offsets[3], object.embeddingModelId);
  writer.writeLong(offsets[4], object.notebookId);
  writer.writeLong(offsets[5], object.ordinal);
  writer.writeLong(offsets[6], object.pageId);
  writer.writeString(offsets[7], object.text);
}

NoteChunkRecord _noteChunkRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = NoteChunkRecord();
  object.contentSignature = reader.readString(offsets[0]);
  object.embeddedAt = reader.readDateTime(offsets[1]);
  object.embedding = reader.readFloatList(offsets[2]) ?? [];
  object.embeddingModelId = reader.readString(offsets[3]);
  object.id = id;
  object.notebookId = reader.readLong(offsets[4]);
  object.ordinal = reader.readLong(offsets[5]);
  object.pageId = reader.readLong(offsets[6]);
  object.text = reader.readString(offsets[7]);
  return object;
}

P _noteChunkRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readFloatList(offset) ?? []) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _noteChunkRecordGetId(NoteChunkRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _noteChunkRecordGetLinks(NoteChunkRecord object) {
  return [];
}

void _noteChunkRecordAttach(
    IsarCollection<dynamic> col, Id id, NoteChunkRecord object) {
  object.id = id;
}

extension NoteChunkRecordQueryWhereSort
    on QueryBuilder<NoteChunkRecord, NoteChunkRecord, QWhere> {
  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhere> anyNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'notebookId'),
      );
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhere> anyPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'pageId'),
      );
    });
  }
}

extension NoteChunkRecordQueryWhere
    on QueryBuilder<NoteChunkRecord, NoteChunkRecord, QWhereClause> {
  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhereClause>
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

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhereClause> idBetween(
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

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhereClause>
      notebookIdEqualTo(int notebookId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'notebookId',
        value: [notebookId],
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhereClause>
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

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhereClause>
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

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhereClause>
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

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhereClause>
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

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhereClause>
      pageIdEqualTo(int pageId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'pageId',
        value: [pageId],
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhereClause>
      pageIdNotEqualTo(int pageId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pageId',
              lower: [],
              upper: [pageId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pageId',
              lower: [pageId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pageId',
              lower: [pageId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pageId',
              lower: [],
              upper: [pageId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhereClause>
      pageIdGreaterThan(
    int pageId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'pageId',
        lower: [pageId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhereClause>
      pageIdLessThan(
    int pageId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'pageId',
        lower: [],
        upper: [pageId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterWhereClause>
      pageIdBetween(
    int lowerPageId,
    int upperPageId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'pageId',
        lower: [lowerPageId],
        includeLower: includeLower,
        upper: [upperPageId],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension NoteChunkRecordQueryFilter
    on QueryBuilder<NoteChunkRecord, NoteChunkRecord, QFilterCondition> {
  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      contentSignatureEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'contentSignature',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      contentSignatureGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'contentSignature',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      contentSignatureLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'contentSignature',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      contentSignatureBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'contentSignature',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      contentSignatureStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'contentSignature',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      contentSignatureEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'contentSignature',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      contentSignatureContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'contentSignature',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      contentSignatureMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'contentSignature',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      contentSignatureIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'contentSignature',
        value: '',
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      contentSignatureIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'contentSignature',
        value: '',
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'embeddedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'embeddedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'embeddedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'embeddedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingElementEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'embedding',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingElementGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'embedding',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingElementLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'embedding',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingElementBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'embedding',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingModelIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'embeddingModelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingModelIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'embeddingModelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingModelIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'embeddingModelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingModelIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'embeddingModelId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingModelIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'embeddingModelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingModelIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'embeddingModelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingModelIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'embeddingModelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingModelIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'embeddingModelId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingModelIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'embeddingModelId',
        value: '',
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      embeddingModelIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'embeddingModelId',
        value: '',
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
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

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
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

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
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

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      notebookIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notebookId',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
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

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
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

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
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

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      ordinalEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ordinal',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      ordinalGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ordinal',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      ordinalLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ordinal',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      ordinalBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ordinal',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      pageIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pageId',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
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

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
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

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
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

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      textEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      textGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      textLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      textBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'text',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      textStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      textEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      textContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      textMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'text',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      textIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'text',
        value: '',
      ));
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterFilterCondition>
      textIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'text',
        value: '',
      ));
    });
  }
}

extension NoteChunkRecordQueryObject
    on QueryBuilder<NoteChunkRecord, NoteChunkRecord, QFilterCondition> {}

extension NoteChunkRecordQueryLinks
    on QueryBuilder<NoteChunkRecord, NoteChunkRecord, QFilterCondition> {}

extension NoteChunkRecordQuerySortBy
    on QueryBuilder<NoteChunkRecord, NoteChunkRecord, QSortBy> {
  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      sortByContentSignature() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentSignature', Sort.asc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      sortByContentSignatureDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentSignature', Sort.desc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      sortByEmbeddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'embeddedAt', Sort.asc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      sortByEmbeddedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'embeddedAt', Sort.desc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      sortByEmbeddingModelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'embeddingModelId', Sort.asc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      sortByEmbeddingModelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'embeddingModelId', Sort.desc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      sortByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.asc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      sortByNotebookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.desc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy> sortByOrdinal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ordinal', Sort.asc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      sortByOrdinalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ordinal', Sort.desc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy> sortByPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageId', Sort.asc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      sortByPageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageId', Sort.desc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy> sortByText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'text', Sort.asc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      sortByTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'text', Sort.desc);
    });
  }
}

extension NoteChunkRecordQuerySortThenBy
    on QueryBuilder<NoteChunkRecord, NoteChunkRecord, QSortThenBy> {
  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      thenByContentSignature() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentSignature', Sort.asc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      thenByContentSignatureDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentSignature', Sort.desc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      thenByEmbeddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'embeddedAt', Sort.asc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      thenByEmbeddedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'embeddedAt', Sort.desc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      thenByEmbeddingModelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'embeddingModelId', Sort.asc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      thenByEmbeddingModelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'embeddingModelId', Sort.desc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      thenByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.asc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      thenByNotebookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.desc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy> thenByOrdinal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ordinal', Sort.asc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      thenByOrdinalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ordinal', Sort.desc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy> thenByPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageId', Sort.asc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      thenByPageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageId', Sort.desc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy> thenByText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'text', Sort.asc);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QAfterSortBy>
      thenByTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'text', Sort.desc);
    });
  }
}

extension NoteChunkRecordQueryWhereDistinct
    on QueryBuilder<NoteChunkRecord, NoteChunkRecord, QDistinct> {
  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QDistinct>
      distinctByContentSignature({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'contentSignature',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QDistinct>
      distinctByEmbeddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'embeddedAt');
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QDistinct>
      distinctByEmbedding() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'embedding');
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QDistinct>
      distinctByEmbeddingModelId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'embeddingModelId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QDistinct>
      distinctByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notebookId');
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QDistinct>
      distinctByOrdinal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ordinal');
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QDistinct> distinctByPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pageId');
    });
  }

  QueryBuilder<NoteChunkRecord, NoteChunkRecord, QDistinct> distinctByText(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'text', caseSensitive: caseSensitive);
    });
  }
}

extension NoteChunkRecordQueryProperty
    on QueryBuilder<NoteChunkRecord, NoteChunkRecord, QQueryProperty> {
  QueryBuilder<NoteChunkRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<NoteChunkRecord, String, QQueryOperations>
      contentSignatureProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'contentSignature');
    });
  }

  QueryBuilder<NoteChunkRecord, DateTime, QQueryOperations>
      embeddedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'embeddedAt');
    });
  }

  QueryBuilder<NoteChunkRecord, List<double>, QQueryOperations>
      embeddingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'embedding');
    });
  }

  QueryBuilder<NoteChunkRecord, String, QQueryOperations>
      embeddingModelIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'embeddingModelId');
    });
  }

  QueryBuilder<NoteChunkRecord, int, QQueryOperations> notebookIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notebookId');
    });
  }

  QueryBuilder<NoteChunkRecord, int, QQueryOperations> ordinalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ordinal');
    });
  }

  QueryBuilder<NoteChunkRecord, int, QQueryOperations> pageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pageId');
    });
  }

  QueryBuilder<NoteChunkRecord, String, QQueryOperations> textProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'text');
    });
  }
}
