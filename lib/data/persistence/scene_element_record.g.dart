// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scene_element_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSceneElementRecordCollection on Isar {
  IsarCollection<SceneElementRecord> get sceneElementRecords =>
      this.collection();
}

const SceneElementRecordSchema = CollectionSchema(
  name: r'SceneElementRecord',
  id: -8884794864107953035,
  properties: {
    r'audioOffsetMs': PropertySchema(
      id: 0,
      name: r'audioOffsetMs',
      type: IsarType.long,
    ),
    r'color': PropertySchema(
      id: 1,
      name: r'color',
      type: IsarType.long,
    ),
    r'containerId': PropertySchema(
      id: 2,
      name: r'containerId',
      type: IsarType.string,
    ),
    r'edges': PropertySchema(
      id: 3,
      name: r'edges',
      type: IsarType.byte,
      enumMap: _SceneElementRecordedgesEnumValueMap,
    ),
    r'elbowed': PropertySchema(
      id: 4,
      name: r'elbowed',
      type: IsarType.bool,
    ),
    r'elementId': PropertySchema(
      id: 5,
      name: r'elementId',
      type: IsarType.string,
    ),
    r'endArrowhead': PropertySchema(
      id: 6,
      name: r'endArrowhead',
      type: IsarType.byte,
      enumMap: _SceneElementRecordendArrowheadEnumValueMap,
    ),
    r'endBindingId': PropertySchema(
      id: 7,
      name: r'endBindingId',
      type: IsarType.string,
    ),
    r'fillColor': PropertySchema(
      id: 8,
      name: r'fillColor',
      type: IsarType.long,
    ),
    r'fillStyle': PropertySchema(
      id: 9,
      name: r'fillStyle',
      type: IsarType.byte,
      enumMap: _SceneElementRecordfillStyleEnumValueMap,
    ),
    r'fontFamily': PropertySchema(
      id: 10,
      name: r'fontFamily',
      type: IsarType.string,
    ),
    r'fontSize': PropertySchema(
      id: 11,
      name: r'fontSize',
      type: IsarType.double,
    ),
    r'geometryData': PropertySchema(
      id: 12,
      name: r'geometryData',
      type: IsarType.doubleList,
    ),
    r'groupId': PropertySchema(
      id: 13,
      name: r'groupId',
      type: IsarType.string,
    ),
    r'hasFill': PropertySchema(
      id: 14,
      name: r'hasFill',
      type: IsarType.bool,
    ),
    r'isBold': PropertySchema(
      id: 15,
      name: r'isBold',
      type: IsarType.bool,
    ),
    r'isEraser': PropertySchema(
      id: 16,
      name: r'isEraser',
      type: IsarType.bool,
    ),
    r'isItalic': PropertySchema(
      id: 17,
      name: r'isItalic',
      type: IsarType.bool,
    ),
    r'isLocked': PropertySchema(
      id: 18,
      name: r'isLocked',
      type: IsarType.bool,
    ),
    r'kind': PropertySchema(
      id: 19,
      name: r'kind',
      type: IsarType.byte,
      enumMap: _SceneElementRecordkindEnumValueMap,
    ),
    r'notebookId': PropertySchema(
      id: 20,
      name: r'notebookId',
      type: IsarType.long,
    ),
    r'opacity': PropertySchema(
      id: 21,
      name: r'opacity',
      type: IsarType.double,
    ),
    r'pageId': PropertySchema(
      id: 22,
      name: r'pageId',
      type: IsarType.long,
    ),
    r'pointSim': PropertySchema(
      id: 23,
      name: r'pointSim',
      type: IsarType.boolList,
    ),
    r'pointT': PropertySchema(
      id: 24,
      name: r'pointT',
      type: IsarType.longList,
    ),
    r'points': PropertySchema(
      id: 25,
      name: r'points',
      type: IsarType.doubleList,
    ),
    r'recordingId': PropertySchema(
      id: 26,
      name: r'recordingId',
      type: IsarType.long,
    ),
    r'relativeImagePath': PropertySchema(
      id: 27,
      name: r'relativeImagePath',
      type: IsarType.string,
    ),
    r'rotation': PropertySchema(
      id: 28,
      name: r'rotation',
      type: IsarType.double,
    ),
    r'roughness': PropertySchema(
      id: 29,
      name: r'roughness',
      type: IsarType.double,
    ),
    r'seed': PropertySchema(
      id: 30,
      name: r'seed',
      type: IsarType.long,
    ),
    r'shapeType': PropertySchema(
      id: 31,
      name: r'shapeType',
      type: IsarType.byte,
      enumMap: _SceneElementRecordshapeTypeEnumValueMap,
    ),
    r'sourceDescription': PropertySchema(
      id: 32,
      name: r'sourceDescription',
      type: IsarType.string,
    ),
    r'startArrowhead': PropertySchema(
      id: 33,
      name: r'startArrowhead',
      type: IsarType.byte,
      enumMap: _SceneElementRecordstartArrowheadEnumValueMap,
    ),
    r'startBindingId': PropertySchema(
      id: 34,
      name: r'startBindingId',
      type: IsarType.string,
    ),
    r'strokeStyle': PropertySchema(
      id: 35,
      name: r'strokeStyle',
      type: IsarType.byte,
      enumMap: _SceneElementRecordstrokeStyleEnumValueMap,
    ),
    r'strokeWidth': PropertySchema(
      id: 36,
      name: r'strokeWidth',
      type: IsarType.double,
    ),
    r'text': PropertySchema(
      id: 37,
      name: r'text',
      type: IsarType.string,
    ),
    r'textAlign': PropertySchema(
      id: 38,
      name: r'textAlign',
      type: IsarType.byte,
      enumMap: _SceneElementRecordtextAlignEnumValueMap,
    ),
    r'zOrder': PropertySchema(
      id: 39,
      name: r'zOrder',
      type: IsarType.long,
    )
  },
  estimateSize: _sceneElementRecordEstimateSize,
  serialize: _sceneElementRecordSerialize,
  deserialize: _sceneElementRecordDeserialize,
  deserializeProp: _sceneElementRecordDeserializeProp,
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
  embeddedSchemas: {},
  getId: _sceneElementRecordGetId,
  getLinks: _sceneElementRecordGetLinks,
  attach: _sceneElementRecordAttach,
  version: '3.1.0+1',
);

int _sceneElementRecordEstimateSize(
  SceneElementRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.containerId.length * 3;
  bytesCount += 3 + object.elementId.length * 3;
  bytesCount += 3 + object.endBindingId.length * 3;
  bytesCount += 3 + object.fontFamily.length * 3;
  bytesCount += 3 + object.geometryData.length * 8;
  bytesCount += 3 + object.groupId.length * 3;
  bytesCount += 3 + object.pointSim.length;
  bytesCount += 3 + object.pointT.length * 8;
  bytesCount += 3 + object.points.length * 8;
  bytesCount += 3 + object.relativeImagePath.length * 3;
  bytesCount += 3 + object.sourceDescription.length * 3;
  bytesCount += 3 + object.startBindingId.length * 3;
  bytesCount += 3 + object.text.length * 3;
  return bytesCount;
}

void _sceneElementRecordSerialize(
  SceneElementRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.audioOffsetMs);
  writer.writeLong(offsets[1], object.color);
  writer.writeString(offsets[2], object.containerId);
  writer.writeByte(offsets[3], object.edges.index);
  writer.writeBool(offsets[4], object.elbowed);
  writer.writeString(offsets[5], object.elementId);
  writer.writeByte(offsets[6], object.endArrowhead.index);
  writer.writeString(offsets[7], object.endBindingId);
  writer.writeLong(offsets[8], object.fillColor);
  writer.writeByte(offsets[9], object.fillStyle.index);
  writer.writeString(offsets[10], object.fontFamily);
  writer.writeDouble(offsets[11], object.fontSize);
  writer.writeDoubleList(offsets[12], object.geometryData);
  writer.writeString(offsets[13], object.groupId);
  writer.writeBool(offsets[14], object.hasFill);
  writer.writeBool(offsets[15], object.isBold);
  writer.writeBool(offsets[16], object.isEraser);
  writer.writeBool(offsets[17], object.isItalic);
  writer.writeBool(offsets[18], object.isLocked);
  writer.writeByte(offsets[19], object.kind.index);
  writer.writeLong(offsets[20], object.notebookId);
  writer.writeDouble(offsets[21], object.opacity);
  writer.writeLong(offsets[22], object.pageId);
  writer.writeBoolList(offsets[23], object.pointSim);
  writer.writeLongList(offsets[24], object.pointT);
  writer.writeDoubleList(offsets[25], object.points);
  writer.writeLong(offsets[26], object.recordingId);
  writer.writeString(offsets[27], object.relativeImagePath);
  writer.writeDouble(offsets[28], object.rotation);
  writer.writeDouble(offsets[29], object.roughness);
  writer.writeLong(offsets[30], object.seed);
  writer.writeByte(offsets[31], object.shapeType.index);
  writer.writeString(offsets[32], object.sourceDescription);
  writer.writeByte(offsets[33], object.startArrowhead.index);
  writer.writeString(offsets[34], object.startBindingId);
  writer.writeByte(offsets[35], object.strokeStyle.index);
  writer.writeDouble(offsets[36], object.strokeWidth);
  writer.writeString(offsets[37], object.text);
  writer.writeByte(offsets[38], object.textAlign.index);
  writer.writeLong(offsets[39], object.zOrder);
}

SceneElementRecord _sceneElementRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SceneElementRecord();
  object.audioOffsetMs = reader.readLongOrNull(offsets[0]);
  object.color = reader.readLong(offsets[1]);
  object.containerId = reader.readString(offsets[2]);
  object.edges =
      _SceneElementRecordedgesValueEnumMap[reader.readByteOrNull(offsets[3])] ??
          EdgeStyle.sharp;
  object.elbowed = reader.readBool(offsets[4]);
  object.elementId = reader.readString(offsets[5]);
  object.endArrowhead = _SceneElementRecordendArrowheadValueEnumMap[
          reader.readByteOrNull(offsets[6])] ??
      Arrowhead.none;
  object.endBindingId = reader.readString(offsets[7]);
  object.fillColor = reader.readLong(offsets[8]);
  object.fillStyle = _SceneElementRecordfillStyleValueEnumMap[
          reader.readByteOrNull(offsets[9])] ??
      FillStyle.hachure;
  object.fontFamily = reader.readString(offsets[10]);
  object.fontSize = reader.readDouble(offsets[11]);
  object.geometryData = reader.readDoubleList(offsets[12]) ?? [];
  object.groupId = reader.readString(offsets[13]);
  object.hasFill = reader.readBool(offsets[14]);
  object.id = id;
  object.isBold = reader.readBool(offsets[15]);
  object.isEraser = reader.readBool(offsets[16]);
  object.isItalic = reader.readBool(offsets[17]);
  object.isLocked = reader.readBool(offsets[18]);
  object.kind =
      _SceneElementRecordkindValueEnumMap[reader.readByteOrNull(offsets[19])] ??
          SceneElementKind.freehand;
  object.notebookId = reader.readLong(offsets[20]);
  object.opacity = reader.readDouble(offsets[21]);
  object.pageId = reader.readLong(offsets[22]);
  object.pointSim = reader.readBoolList(offsets[23]) ?? [];
  object.pointT = reader.readLongList(offsets[24]) ?? [];
  object.points = reader.readDoubleList(offsets[25]) ?? [];
  object.recordingId = reader.readLongOrNull(offsets[26]);
  object.relativeImagePath = reader.readString(offsets[27]);
  object.rotation = reader.readDouble(offsets[28]);
  object.roughness = reader.readDouble(offsets[29]);
  object.seed = reader.readLong(offsets[30]);
  object.shapeType = _SceneElementRecordshapeTypeValueEnumMap[
          reader.readByteOrNull(offsets[31])] ??
      ShapeType.line;
  object.sourceDescription = reader.readString(offsets[32]);
  object.startArrowhead = _SceneElementRecordstartArrowheadValueEnumMap[
          reader.readByteOrNull(offsets[33])] ??
      Arrowhead.none;
  object.startBindingId = reader.readString(offsets[34]);
  object.strokeStyle = _SceneElementRecordstrokeStyleValueEnumMap[
          reader.readByteOrNull(offsets[35])] ??
      StrokeStyle.solid;
  object.strokeWidth = reader.readDouble(offsets[36]);
  object.text = reader.readString(offsets[37]);
  object.textAlign = _SceneElementRecordtextAlignValueEnumMap[
          reader.readByteOrNull(offsets[38])] ??
      TextAlignKind.left;
  object.zOrder = reader.readLong(offsets[39]);
  return object;
}

P _sceneElementRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (_SceneElementRecordedgesValueEnumMap[
              reader.readByteOrNull(offset)] ??
          EdgeStyle.sharp) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (_SceneElementRecordendArrowheadValueEnumMap[
              reader.readByteOrNull(offset)] ??
          Arrowhead.none) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    case 9:
      return (_SceneElementRecordfillStyleValueEnumMap[
              reader.readByteOrNull(offset)] ??
          FillStyle.hachure) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readDouble(offset)) as P;
    case 12:
      return (reader.readDoubleList(offset) ?? []) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readBool(offset)) as P;
    case 15:
      return (reader.readBool(offset)) as P;
    case 16:
      return (reader.readBool(offset)) as P;
    case 17:
      return (reader.readBool(offset)) as P;
    case 18:
      return (reader.readBool(offset)) as P;
    case 19:
      return (_SceneElementRecordkindValueEnumMap[
              reader.readByteOrNull(offset)] ??
          SceneElementKind.freehand) as P;
    case 20:
      return (reader.readLong(offset)) as P;
    case 21:
      return (reader.readDouble(offset)) as P;
    case 22:
      return (reader.readLong(offset)) as P;
    case 23:
      return (reader.readBoolList(offset) ?? []) as P;
    case 24:
      return (reader.readLongList(offset) ?? []) as P;
    case 25:
      return (reader.readDoubleList(offset) ?? []) as P;
    case 26:
      return (reader.readLongOrNull(offset)) as P;
    case 27:
      return (reader.readString(offset)) as P;
    case 28:
      return (reader.readDouble(offset)) as P;
    case 29:
      return (reader.readDouble(offset)) as P;
    case 30:
      return (reader.readLong(offset)) as P;
    case 31:
      return (_SceneElementRecordshapeTypeValueEnumMap[
              reader.readByteOrNull(offset)] ??
          ShapeType.line) as P;
    case 32:
      return (reader.readString(offset)) as P;
    case 33:
      return (_SceneElementRecordstartArrowheadValueEnumMap[
              reader.readByteOrNull(offset)] ??
          Arrowhead.none) as P;
    case 34:
      return (reader.readString(offset)) as P;
    case 35:
      return (_SceneElementRecordstrokeStyleValueEnumMap[
              reader.readByteOrNull(offset)] ??
          StrokeStyle.solid) as P;
    case 36:
      return (reader.readDouble(offset)) as P;
    case 37:
      return (reader.readString(offset)) as P;
    case 38:
      return (_SceneElementRecordtextAlignValueEnumMap[
              reader.readByteOrNull(offset)] ??
          TextAlignKind.left) as P;
    case 39:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _SceneElementRecordedgesEnumValueMap = {
  'sharp': 0,
  'round': 1,
};
const _SceneElementRecordedgesValueEnumMap = {
  0: EdgeStyle.sharp,
  1: EdgeStyle.round,
};
const _SceneElementRecordendArrowheadEnumValueMap = {
  'none': 0,
  'triangle': 1,
  'dot': 2,
  'bar': 3,
};
const _SceneElementRecordendArrowheadValueEnumMap = {
  0: Arrowhead.none,
  1: Arrowhead.triangle,
  2: Arrowhead.dot,
  3: Arrowhead.bar,
};
const _SceneElementRecordfillStyleEnumValueMap = {
  'hachure': 0,
  'crossHatch': 1,
  'solid': 2,
};
const _SceneElementRecordfillStyleValueEnumMap = {
  0: FillStyle.hachure,
  1: FillStyle.crossHatch,
  2: FillStyle.solid,
};
const _SceneElementRecordkindEnumValueMap = {
  'freehand': 0,
  'shape': 1,
  'text': 2,
  'image': 3,
  'frame': 4,
};
const _SceneElementRecordkindValueEnumMap = {
  0: SceneElementKind.freehand,
  1: SceneElementKind.shape,
  2: SceneElementKind.text,
  3: SceneElementKind.image,
  4: SceneElementKind.frame,
};
const _SceneElementRecordshapeTypeEnumValueMap = {
  'line': 0,
  'arrow': 1,
  'circle': 2,
  'rectangle': 3,
  'triangle': 4,
  'polygon': 5,
  'textBox': 6,
  'svgImage': 7,
  'diamond': 8,
};
const _SceneElementRecordshapeTypeValueEnumMap = {
  0: ShapeType.line,
  1: ShapeType.arrow,
  2: ShapeType.circle,
  3: ShapeType.rectangle,
  4: ShapeType.triangle,
  5: ShapeType.polygon,
  6: ShapeType.textBox,
  7: ShapeType.svgImage,
  8: ShapeType.diamond,
};
const _SceneElementRecordstartArrowheadEnumValueMap = {
  'none': 0,
  'triangle': 1,
  'dot': 2,
  'bar': 3,
};
const _SceneElementRecordstartArrowheadValueEnumMap = {
  0: Arrowhead.none,
  1: Arrowhead.triangle,
  2: Arrowhead.dot,
  3: Arrowhead.bar,
};
const _SceneElementRecordstrokeStyleEnumValueMap = {
  'solid': 0,
  'dashed': 1,
  'dotted': 2,
};
const _SceneElementRecordstrokeStyleValueEnumMap = {
  0: StrokeStyle.solid,
  1: StrokeStyle.dashed,
  2: StrokeStyle.dotted,
};
const _SceneElementRecordtextAlignEnumValueMap = {
  'left': 0,
  'center': 1,
  'right': 2,
};
const _SceneElementRecordtextAlignValueEnumMap = {
  0: TextAlignKind.left,
  1: TextAlignKind.center,
  2: TextAlignKind.right,
};

Id _sceneElementRecordGetId(SceneElementRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _sceneElementRecordGetLinks(
    SceneElementRecord object) {
  return [];
}

void _sceneElementRecordAttach(
    IsarCollection<dynamic> col, Id id, SceneElementRecord object) {
  object.id = id;
}

extension SceneElementRecordQueryWhereSort
    on QueryBuilder<SceneElementRecord, SceneElementRecord, QWhere> {
  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhere>
      anyPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'pageId'),
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhere>
      anyNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'notebookId'),
      );
    });
  }
}

extension SceneElementRecordQueryWhere
    on QueryBuilder<SceneElementRecord, SceneElementRecord, QWhereClause> {
  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhereClause>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhereClause>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhereClause>
      pageIdEqualTo(int pageId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'pageId',
        value: [pageId],
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhereClause>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhereClause>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhereClause>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhereClause>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhereClause>
      notebookIdEqualTo(int notebookId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'notebookId',
        value: [notebookId],
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhereClause>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhereClause>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhereClause>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterWhereClause>
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

extension SceneElementRecordQueryFilter
    on QueryBuilder<SceneElementRecord, SceneElementRecord, QFilterCondition> {
  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      audioOffsetMsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'audioOffsetMs',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      audioOffsetMsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'audioOffsetMs',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      audioOffsetMsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'audioOffsetMs',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      audioOffsetMsGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'audioOffsetMs',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      audioOffsetMsLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'audioOffsetMs',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      audioOffsetMsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'audioOffsetMs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      colorEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'color',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      colorGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'color',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      colorLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'color',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      colorBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'color',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      containerIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'containerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      containerIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'containerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      containerIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'containerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      containerIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'containerId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      containerIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'containerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      containerIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'containerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      containerIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'containerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      containerIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'containerId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      containerIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'containerId',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      containerIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'containerId',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      edgesEqualTo(EdgeStyle value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'edges',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      edgesGreaterThan(
    EdgeStyle value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'edges',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      edgesLessThan(
    EdgeStyle value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'edges',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      edgesBetween(
    EdgeStyle lower,
    EdgeStyle upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'edges',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      elbowedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'elbowed',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      elementIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'elementId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      elementIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'elementId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      elementIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'elementId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      elementIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'elementId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      elementIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'elementId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      elementIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'elementId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      elementIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'elementId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      elementIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'elementId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      elementIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'elementId',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      elementIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'elementId',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      endArrowheadEqualTo(Arrowhead value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'endArrowhead',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      endArrowheadGreaterThan(
    Arrowhead value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'endArrowhead',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      endArrowheadLessThan(
    Arrowhead value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'endArrowhead',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      endArrowheadBetween(
    Arrowhead lower,
    Arrowhead upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'endArrowhead',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      endBindingIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'endBindingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      endBindingIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'endBindingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      endBindingIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'endBindingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      endBindingIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'endBindingId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      endBindingIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'endBindingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      endBindingIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'endBindingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      endBindingIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'endBindingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      endBindingIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'endBindingId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      endBindingIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'endBindingId',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      endBindingIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'endBindingId',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fillColorEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fillColor',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fillColorGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fillColor',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fillColorLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fillColor',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fillColorBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fillColor',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fillStyleEqualTo(FillStyle value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fillStyle',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fillStyleGreaterThan(
    FillStyle value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fillStyle',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fillStyleLessThan(
    FillStyle value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fillStyle',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fillStyleBetween(
    FillStyle lower,
    FillStyle upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fillStyle',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fontFamilyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fontFamily',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fontFamilyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fontFamily',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fontFamilyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fontFamily',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fontFamilyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fontFamily',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fontFamilyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'fontFamily',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fontFamilyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'fontFamily',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fontFamilyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'fontFamily',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fontFamilyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'fontFamily',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fontFamilyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fontFamily',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fontFamilyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'fontFamily',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fontSizeEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fontSize',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fontSizeGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fontSize',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fontSizeLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fontSize',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      fontSizeBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fontSize',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      geometryDataElementEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'geometryData',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      geometryDataElementGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'geometryData',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      geometryDataElementLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'geometryData',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      geometryDataElementBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'geometryData',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      geometryDataLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'geometryData',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      geometryDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'geometryData',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      geometryDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'geometryData',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      geometryDataLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'geometryData',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      geometryDataLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'geometryData',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      geometryDataLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'geometryData',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      groupIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      groupIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      groupIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      groupIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'groupId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      groupIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      groupIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      groupIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      groupIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'groupId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      groupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupId',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      groupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'groupId',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      hasFillEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hasFill',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      isBoldEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isBold',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      isEraserEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isEraser',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      isItalicEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isItalic',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      isLockedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isLocked',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      kindEqualTo(SceneElementKind value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'kind',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      kindGreaterThan(
    SceneElementKind value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'kind',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      kindLessThan(
    SceneElementKind value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'kind',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      kindBetween(
    SceneElementKind lower,
    SceneElementKind upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'kind',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      notebookIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notebookId',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      opacityEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'opacity',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      opacityGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'opacity',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      opacityLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'opacity',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      opacityBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'opacity',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pageIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pageId',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointSimElementEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pointSim',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointSimLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'pointSim',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointSimIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'pointSim',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointSimIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'pointSim',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointSimLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'pointSim',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointSimLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'pointSim',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointSimLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'pointSim',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointTElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pointT',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointTElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pointT',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointTElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pointT',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointTElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pointT',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointTLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'pointT',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointTIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'pointT',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointTIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'pointT',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointTLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'pointT',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointTLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'pointT',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointTLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'pointT',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointsElementEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'points',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointsElementGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'points',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointsElementLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'points',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointsElementBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'points',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'points',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'points',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'points',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'points',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'points',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      pointsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'points',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      recordingIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'recordingId',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      recordingIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'recordingId',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      recordingIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recordingId',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      recordingIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'recordingId',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      recordingIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'recordingId',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      recordingIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'recordingId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      relativeImagePathEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'relativeImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      relativeImagePathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'relativeImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      relativeImagePathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'relativeImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      relativeImagePathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'relativeImagePath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      relativeImagePathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'relativeImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      relativeImagePathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'relativeImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      relativeImagePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'relativeImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      relativeImagePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'relativeImagePath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      relativeImagePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'relativeImagePath',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      relativeImagePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'relativeImagePath',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      rotationEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rotation',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      rotationGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rotation',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      rotationLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rotation',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      rotationBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rotation',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      roughnessEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'roughness',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      roughnessGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'roughness',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      roughnessLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'roughness',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      roughnessBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'roughness',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      seedEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'seed',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      seedGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'seed',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      seedLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'seed',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      seedBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'seed',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      shapeTypeEqualTo(ShapeType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'shapeType',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      shapeTypeGreaterThan(
    ShapeType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'shapeType',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      shapeTypeLessThan(
    ShapeType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'shapeType',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      shapeTypeBetween(
    ShapeType lower,
    ShapeType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'shapeType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      sourceDescriptionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      sourceDescriptionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      sourceDescriptionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      sourceDescriptionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceDescription',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      sourceDescriptionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourceDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      sourceDescriptionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourceDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      sourceDescriptionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourceDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      sourceDescriptionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourceDescription',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      sourceDescriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceDescription',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      sourceDescriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourceDescription',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      startArrowheadEqualTo(Arrowhead value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'startArrowhead',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      startArrowheadGreaterThan(
    Arrowhead value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'startArrowhead',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      startArrowheadLessThan(
    Arrowhead value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'startArrowhead',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      startArrowheadBetween(
    Arrowhead lower,
    Arrowhead upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'startArrowhead',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      startBindingIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'startBindingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      startBindingIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'startBindingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      startBindingIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'startBindingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      startBindingIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'startBindingId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      startBindingIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'startBindingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      startBindingIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'startBindingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      startBindingIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'startBindingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      startBindingIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'startBindingId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      startBindingIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'startBindingId',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      startBindingIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'startBindingId',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      strokeStyleEqualTo(StrokeStyle value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'strokeStyle',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      strokeStyleGreaterThan(
    StrokeStyle value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'strokeStyle',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      strokeStyleLessThan(
    StrokeStyle value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'strokeStyle',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      strokeStyleBetween(
    StrokeStyle lower,
    StrokeStyle upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'strokeStyle',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      strokeWidthEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'strokeWidth',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      strokeWidthGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'strokeWidth',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      strokeWidthLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'strokeWidth',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      strokeWidthBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'strokeWidth',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
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

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      textContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      textMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'text',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      textIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'text',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      textIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'text',
        value: '',
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      textAlignEqualTo(TextAlignKind value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'textAlign',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      textAlignGreaterThan(
    TextAlignKind value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'textAlign',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      textAlignLessThan(
    TextAlignKind value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'textAlign',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      textAlignBetween(
    TextAlignKind lower,
    TextAlignKind upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'textAlign',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      zOrderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'zOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      zOrderGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'zOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      zOrderLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'zOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterFilterCondition>
      zOrderBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'zOrder',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SceneElementRecordQueryObject
    on QueryBuilder<SceneElementRecord, SceneElementRecord, QFilterCondition> {}

extension SceneElementRecordQueryLinks
    on QueryBuilder<SceneElementRecord, SceneElementRecord, QFilterCondition> {}

extension SceneElementRecordQuerySortBy
    on QueryBuilder<SceneElementRecord, SceneElementRecord, QSortBy> {
  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByAudioOffsetMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioOffsetMs', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByAudioOffsetMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioOffsetMs', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByColor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'color', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByColorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'color', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByContainerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'containerId', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByContainerIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'containerId', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByEdges() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'edges', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByEdgesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'edges', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByElbowed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'elbowed', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByElbowedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'elbowed', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByElementId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'elementId', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByElementIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'elementId', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByEndArrowhead() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endArrowhead', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByEndArrowheadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endArrowhead', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByEndBindingId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endBindingId', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByEndBindingIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endBindingId', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByFillColor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fillColor', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByFillColorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fillColor', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByFillStyle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fillStyle', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByFillStyleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fillStyle', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByFontFamily() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontFamily', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByFontFamilyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontFamily', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByFontSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontSize', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByFontSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontSize', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByHasFill() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasFill', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByHasFillDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasFill', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByIsBold() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBold', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByIsBoldDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBold', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByIsEraser() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isEraser', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByIsEraserDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isEraser', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByIsItalic() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isItalic', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByIsItalicDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isItalic', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByIsLocked() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLocked', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByIsLockedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLocked', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByNotebookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByOpacity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'opacity', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByOpacityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'opacity', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageId', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByPageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageId', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByRecordingId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordingId', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByRecordingIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordingId', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByRelativeImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relativeImagePath', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByRelativeImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relativeImagePath', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByRotation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rotation', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByRotationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rotation', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByRoughness() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roughness', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByRoughnessDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roughness', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortBySeed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'seed', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortBySeedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'seed', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByShapeType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shapeType', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByShapeTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shapeType', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortBySourceDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceDescription', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortBySourceDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceDescription', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByStartArrowhead() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startArrowhead', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByStartArrowheadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startArrowhead', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByStartBindingId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startBindingId', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByStartBindingIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startBindingId', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByStrokeStyle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'strokeStyle', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByStrokeStyleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'strokeStyle', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByStrokeWidth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'strokeWidth', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByStrokeWidthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'strokeWidth', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'text', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'text', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByTextAlign() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'textAlign', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByTextAlignDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'textAlign', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByZOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'zOrder', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      sortByZOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'zOrder', Sort.desc);
    });
  }
}

extension SceneElementRecordQuerySortThenBy
    on QueryBuilder<SceneElementRecord, SceneElementRecord, QSortThenBy> {
  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByAudioOffsetMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioOffsetMs', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByAudioOffsetMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioOffsetMs', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByColor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'color', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByColorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'color', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByContainerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'containerId', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByContainerIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'containerId', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByEdges() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'edges', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByEdgesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'edges', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByElbowed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'elbowed', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByElbowedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'elbowed', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByElementId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'elementId', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByElementIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'elementId', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByEndArrowhead() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endArrowhead', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByEndArrowheadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endArrowhead', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByEndBindingId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endBindingId', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByEndBindingIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endBindingId', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByFillColor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fillColor', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByFillColorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fillColor', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByFillStyle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fillStyle', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByFillStyleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fillStyle', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByFontFamily() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontFamily', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByFontFamilyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontFamily', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByFontSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontSize', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByFontSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontSize', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByHasFill() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasFill', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByHasFillDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasFill', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByIsBold() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBold', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByIsBoldDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBold', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByIsEraser() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isEraser', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByIsEraserDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isEraser', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByIsItalic() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isItalic', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByIsItalicDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isItalic', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByIsLocked() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLocked', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByIsLockedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLocked', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByNotebookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notebookId', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByOpacity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'opacity', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByOpacityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'opacity', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageId', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByPageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageId', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByRecordingId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordingId', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByRecordingIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordingId', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByRelativeImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relativeImagePath', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByRelativeImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relativeImagePath', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByRotation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rotation', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByRotationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rotation', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByRoughness() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roughness', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByRoughnessDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roughness', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenBySeed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'seed', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenBySeedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'seed', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByShapeType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shapeType', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByShapeTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shapeType', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenBySourceDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceDescription', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenBySourceDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceDescription', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByStartArrowhead() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startArrowhead', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByStartArrowheadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startArrowhead', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByStartBindingId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startBindingId', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByStartBindingIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startBindingId', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByStrokeStyle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'strokeStyle', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByStrokeStyleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'strokeStyle', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByStrokeWidth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'strokeWidth', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByStrokeWidthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'strokeWidth', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'text', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'text', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByTextAlign() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'textAlign', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByTextAlignDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'textAlign', Sort.desc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByZOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'zOrder', Sort.asc);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QAfterSortBy>
      thenByZOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'zOrder', Sort.desc);
    });
  }
}

extension SceneElementRecordQueryWhereDistinct
    on QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct> {
  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByAudioOffsetMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'audioOffsetMs');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByColor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'color');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByContainerId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'containerId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByEdges() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'edges');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByElbowed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'elbowed');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByElementId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'elementId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByEndArrowhead() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'endArrowhead');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByEndBindingId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'endBindingId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByFillColor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fillColor');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByFillStyle() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fillStyle');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByFontFamily({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fontFamily', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByFontSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fontSize');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByGeometryData() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'geometryData');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByGroupId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'groupId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByHasFill() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hasFill');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByIsBold() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isBold');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByIsEraser() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isEraser');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByIsItalic() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isItalic');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByIsLocked() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isLocked');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByNotebookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notebookId');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByOpacity() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'opacity');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByPageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pageId');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByPointSim() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pointSim');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByPointT() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pointT');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByPoints() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'points');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByRecordingId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recordingId');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByRelativeImagePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'relativeImagePath',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByRotation() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rotation');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByRoughness() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'roughness');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctBySeed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'seed');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByShapeType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'shapeType');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctBySourceDescription({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceDescription',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByStartArrowhead() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startArrowhead');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByStartBindingId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startBindingId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByStrokeStyle() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'strokeStyle');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByStrokeWidth() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'strokeWidth');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByText({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'text', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByTextAlign() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'textAlign');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementRecord, QDistinct>
      distinctByZOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'zOrder');
    });
  }
}

extension SceneElementRecordQueryProperty
    on QueryBuilder<SceneElementRecord, SceneElementRecord, QQueryProperty> {
  QueryBuilder<SceneElementRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SceneElementRecord, int?, QQueryOperations>
      audioOffsetMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'audioOffsetMs');
    });
  }

  QueryBuilder<SceneElementRecord, int, QQueryOperations> colorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'color');
    });
  }

  QueryBuilder<SceneElementRecord, String, QQueryOperations>
      containerIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'containerId');
    });
  }

  QueryBuilder<SceneElementRecord, EdgeStyle, QQueryOperations>
      edgesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'edges');
    });
  }

  QueryBuilder<SceneElementRecord, bool, QQueryOperations> elbowedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'elbowed');
    });
  }

  QueryBuilder<SceneElementRecord, String, QQueryOperations>
      elementIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'elementId');
    });
  }

  QueryBuilder<SceneElementRecord, Arrowhead, QQueryOperations>
      endArrowheadProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'endArrowhead');
    });
  }

  QueryBuilder<SceneElementRecord, String, QQueryOperations>
      endBindingIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'endBindingId');
    });
  }

  QueryBuilder<SceneElementRecord, int, QQueryOperations> fillColorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fillColor');
    });
  }

  QueryBuilder<SceneElementRecord, FillStyle, QQueryOperations>
      fillStyleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fillStyle');
    });
  }

  QueryBuilder<SceneElementRecord, String, QQueryOperations>
      fontFamilyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fontFamily');
    });
  }

  QueryBuilder<SceneElementRecord, double, QQueryOperations>
      fontSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fontSize');
    });
  }

  QueryBuilder<SceneElementRecord, List<double>, QQueryOperations>
      geometryDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'geometryData');
    });
  }

  QueryBuilder<SceneElementRecord, String, QQueryOperations> groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'groupId');
    });
  }

  QueryBuilder<SceneElementRecord, bool, QQueryOperations> hasFillProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hasFill');
    });
  }

  QueryBuilder<SceneElementRecord, bool, QQueryOperations> isBoldProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isBold');
    });
  }

  QueryBuilder<SceneElementRecord, bool, QQueryOperations> isEraserProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isEraser');
    });
  }

  QueryBuilder<SceneElementRecord, bool, QQueryOperations> isItalicProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isItalic');
    });
  }

  QueryBuilder<SceneElementRecord, bool, QQueryOperations> isLockedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isLocked');
    });
  }

  QueryBuilder<SceneElementRecord, SceneElementKind, QQueryOperations>
      kindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
    });
  }

  QueryBuilder<SceneElementRecord, int, QQueryOperations> notebookIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notebookId');
    });
  }

  QueryBuilder<SceneElementRecord, double, QQueryOperations> opacityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'opacity');
    });
  }

  QueryBuilder<SceneElementRecord, int, QQueryOperations> pageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pageId');
    });
  }

  QueryBuilder<SceneElementRecord, List<bool>, QQueryOperations>
      pointSimProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pointSim');
    });
  }

  QueryBuilder<SceneElementRecord, List<int>, QQueryOperations>
      pointTProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pointT');
    });
  }

  QueryBuilder<SceneElementRecord, List<double>, QQueryOperations>
      pointsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'points');
    });
  }

  QueryBuilder<SceneElementRecord, int?, QQueryOperations>
      recordingIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recordingId');
    });
  }

  QueryBuilder<SceneElementRecord, String, QQueryOperations>
      relativeImagePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'relativeImagePath');
    });
  }

  QueryBuilder<SceneElementRecord, double, QQueryOperations>
      rotationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rotation');
    });
  }

  QueryBuilder<SceneElementRecord, double, QQueryOperations>
      roughnessProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'roughness');
    });
  }

  QueryBuilder<SceneElementRecord, int, QQueryOperations> seedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'seed');
    });
  }

  QueryBuilder<SceneElementRecord, ShapeType, QQueryOperations>
      shapeTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'shapeType');
    });
  }

  QueryBuilder<SceneElementRecord, String, QQueryOperations>
      sourceDescriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceDescription');
    });
  }

  QueryBuilder<SceneElementRecord, Arrowhead, QQueryOperations>
      startArrowheadProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startArrowhead');
    });
  }

  QueryBuilder<SceneElementRecord, String, QQueryOperations>
      startBindingIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startBindingId');
    });
  }

  QueryBuilder<SceneElementRecord, StrokeStyle, QQueryOperations>
      strokeStyleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'strokeStyle');
    });
  }

  QueryBuilder<SceneElementRecord, double, QQueryOperations>
      strokeWidthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'strokeWidth');
    });
  }

  QueryBuilder<SceneElementRecord, String, QQueryOperations> textProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'text');
    });
  }

  QueryBuilder<SceneElementRecord, TextAlignKind, QQueryOperations>
      textAlignProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'textAlign');
    });
  }

  QueryBuilder<SceneElementRecord, int, QQueryOperations> zOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'zOrder');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAppMetaCollection on Isar {
  IsarCollection<AppMeta> get appMetas => this.collection();
}

const AppMetaSchema = CollectionSchema(
  name: r'AppMeta',
  id: 7451756037581955749,
  properties: {
    r'schemaVersion': PropertySchema(
      id: 0,
      name: r'schemaVersion',
      type: IsarType.long,
    )
  },
  estimateSize: _appMetaEstimateSize,
  serialize: _appMetaSerialize,
  deserialize: _appMetaDeserialize,
  deserializeProp: _appMetaDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _appMetaGetId,
  getLinks: _appMetaGetLinks,
  attach: _appMetaAttach,
  version: '3.1.0+1',
);

int _appMetaEstimateSize(
  AppMeta object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _appMetaSerialize(
  AppMeta object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.schemaVersion);
}

AppMeta _appMetaDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AppMeta();
  object.id = id;
  object.schemaVersion = reader.readLong(offsets[0]);
  return object;
}

P _appMetaDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _appMetaGetId(AppMeta object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _appMetaGetLinks(AppMeta object) {
  return [];
}

void _appMetaAttach(IsarCollection<dynamic> col, Id id, AppMeta object) {
  object.id = id;
}

extension AppMetaQueryWhereSort on QueryBuilder<AppMeta, AppMeta, QWhere> {
  QueryBuilder<AppMeta, AppMeta, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AppMetaQueryWhere on QueryBuilder<AppMeta, AppMeta, QWhereClause> {
  QueryBuilder<AppMeta, AppMeta, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AppMeta, AppMeta, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<AppMeta, AppMeta, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AppMeta, AppMeta, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AppMeta, AppMeta, QAfterWhereClause> idBetween(
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

extension AppMetaQueryFilter
    on QueryBuilder<AppMeta, AppMeta, QFilterCondition> {
  QueryBuilder<AppMeta, AppMeta, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AppMeta, AppMeta, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<AppMeta, AppMeta, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<AppMeta, AppMeta, QAfterFilterCondition> idBetween(
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

  QueryBuilder<AppMeta, AppMeta, QAfterFilterCondition> schemaVersionEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<AppMeta, AppMeta, QAfterFilterCondition>
      schemaVersionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<AppMeta, AppMeta, QAfterFilterCondition> schemaVersionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<AppMeta, AppMeta, QAfterFilterCondition> schemaVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'schemaVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension AppMetaQueryObject
    on QueryBuilder<AppMeta, AppMeta, QFilterCondition> {}

extension AppMetaQueryLinks
    on QueryBuilder<AppMeta, AppMeta, QFilterCondition> {}

extension AppMetaQuerySortBy on QueryBuilder<AppMeta, AppMeta, QSortBy> {
  QueryBuilder<AppMeta, AppMeta, QAfterSortBy> sortBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.asc);
    });
  }

  QueryBuilder<AppMeta, AppMeta, QAfterSortBy> sortBySchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.desc);
    });
  }
}

extension AppMetaQuerySortThenBy
    on QueryBuilder<AppMeta, AppMeta, QSortThenBy> {
  QueryBuilder<AppMeta, AppMeta, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AppMeta, AppMeta, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AppMeta, AppMeta, QAfterSortBy> thenBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.asc);
    });
  }

  QueryBuilder<AppMeta, AppMeta, QAfterSortBy> thenBySchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.desc);
    });
  }
}

extension AppMetaQueryWhereDistinct
    on QueryBuilder<AppMeta, AppMeta, QDistinct> {
  QueryBuilder<AppMeta, AppMeta, QDistinct> distinctBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'schemaVersion');
    });
  }
}

extension AppMetaQueryProperty
    on QueryBuilder<AppMeta, AppMeta, QQueryProperty> {
  QueryBuilder<AppMeta, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AppMeta, int, QQueryOperations> schemaVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'schemaVersion');
    });
  }
}
