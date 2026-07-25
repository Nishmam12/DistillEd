// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shape_element.dart';

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const ShapeElementSchema = Schema(
  name: r'ShapeElement',
  id: -8796284812730346482,
  properties: {
    r'color': PropertySchema(
      id: 0,
      name: r'color',
      type: IsarType.long,
    ),
    r'endBindingId': PropertySchema(
      id: 1,
      name: r'endBindingId',
      type: IsarType.string,
    ),
    r'fillColor': PropertySchema(
      id: 2,
      name: r'fillColor',
      type: IsarType.long,
    ),
    r'fontFamily': PropertySchema(
      id: 3,
      name: r'fontFamily',
      type: IsarType.string,
    ),
    r'fontSize': PropertySchema(
      id: 4,
      name: r'fontSize',
      type: IsarType.double,
    ),
    r'geometryData': PropertySchema(
      id: 5,
      name: r'geometryData',
      type: IsarType.doubleList,
    ),
    r'hasFill': PropertySchema(
      id: 6,
      name: r'hasFill',
      type: IsarType.bool,
    ),
    r'id': PropertySchema(
      id: 7,
      name: r'id',
      type: IsarType.string,
    ),
    r'isBold': PropertySchema(
      id: 8,
      name: r'isBold',
      type: IsarType.bool,
    ),
    r'isItalic': PropertySchema(
      id: 9,
      name: r'isItalic',
      type: IsarType.bool,
    ),
    r'opacity': PropertySchema(
      id: 10,
      name: r'opacity',
      type: IsarType.double,
    ),
    r'rotation': PropertySchema(
      id: 11,
      name: r'rotation',
      type: IsarType.double,
    ),
    r'roughness': PropertySchema(
      id: 12,
      name: r'roughness',
      type: IsarType.double,
    ),
    r'seed': PropertySchema(
      id: 13,
      name: r'seed',
      type: IsarType.long,
    ),
    r'startBindingId': PropertySchema(
      id: 14,
      name: r'startBindingId',
      type: IsarType.string,
    ),
    r'strokeWidth': PropertySchema(
      id: 15,
      name: r'strokeWidth',
      type: IsarType.double,
    ),
    r'svgRelativePath': PropertySchema(
      id: 16,
      name: r'svgRelativePath',
      type: IsarType.string,
    ),
    r'text': PropertySchema(
      id: 17,
      name: r'text',
      type: IsarType.string,
    ),
    r'type': PropertySchema(
      id: 18,
      name: r'type',
      type: IsarType.byte,
      enumMap: _ShapeElementtypeEnumValueMap,
    ),
    r'zOrder': PropertySchema(
      id: 19,
      name: r'zOrder',
      type: IsarType.long,
    )
  },
  estimateSize: _shapeElementEstimateSize,
  serialize: _shapeElementSerialize,
  deserialize: _shapeElementDeserialize,
  deserializeProp: _shapeElementDeserializeProp,
);

int _shapeElementEstimateSize(
  ShapeElement object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.endBindingId.length * 3;
  bytesCount += 3 + object.fontFamily.length * 3;
  bytesCount += 3 + object.geometryData.length * 8;
  bytesCount += 3 + object.id.length * 3;
  bytesCount += 3 + object.startBindingId.length * 3;
  bytesCount += 3 + object.svgRelativePath.length * 3;
  bytesCount += 3 + object.text.length * 3;
  return bytesCount;
}

void _shapeElementSerialize(
  ShapeElement object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.color);
  writer.writeString(offsets[1], object.endBindingId);
  writer.writeLong(offsets[2], object.fillColor);
  writer.writeString(offsets[3], object.fontFamily);
  writer.writeDouble(offsets[4], object.fontSize);
  writer.writeDoubleList(offsets[5], object.geometryData);
  writer.writeBool(offsets[6], object.hasFill);
  writer.writeString(offsets[7], object.id);
  writer.writeBool(offsets[8], object.isBold);
  writer.writeBool(offsets[9], object.isItalic);
  writer.writeDouble(offsets[10], object.opacity);
  writer.writeDouble(offsets[11], object.rotation);
  writer.writeDouble(offsets[12], object.roughness);
  writer.writeLong(offsets[13], object.seed);
  writer.writeString(offsets[14], object.startBindingId);
  writer.writeDouble(offsets[15], object.strokeWidth);
  writer.writeString(offsets[16], object.svgRelativePath);
  writer.writeString(offsets[17], object.text);
  writer.writeByte(offsets[18], object.type.index);
  writer.writeLong(offsets[19], object.zOrder);
}

ShapeElement _shapeElementDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ShapeElement();
  object.color = reader.readLong(offsets[0]);
  object.endBindingId = reader.readString(offsets[1]);
  object.fillColor = reader.readLong(offsets[2]);
  object.fontFamily = reader.readString(offsets[3]);
  object.fontSize = reader.readDouble(offsets[4]);
  object.geometryData = reader.readDoubleList(offsets[5]) ?? [];
  object.hasFill = reader.readBool(offsets[6]);
  object.id = reader.readString(offsets[7]);
  object.isBold = reader.readBool(offsets[8]);
  object.isItalic = reader.readBool(offsets[9]);
  object.opacity = reader.readDouble(offsets[10]);
  object.rotation = reader.readDouble(offsets[11]);
  object.roughness = reader.readDouble(offsets[12]);
  object.seed = reader.readLong(offsets[13]);
  object.startBindingId = reader.readString(offsets[14]);
  object.strokeWidth = reader.readDouble(offsets[15]);
  object.svgRelativePath = reader.readString(offsets[16]);
  object.text = reader.readString(offsets[17]);
  object.type =
      _ShapeElementtypeValueEnumMap[reader.readByteOrNull(offsets[18])] ??
          ShapeType.line;
  object.zOrder = reader.readLong(offsets[19]);
  return object;
}

P _shapeElementDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readDouble(offset)) as P;
    case 5:
      return (reader.readDoubleList(offset) ?? []) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readBool(offset)) as P;
    case 9:
      return (reader.readBool(offset)) as P;
    case 10:
      return (reader.readDouble(offset)) as P;
    case 11:
      return (reader.readDouble(offset)) as P;
    case 12:
      return (reader.readDouble(offset)) as P;
    case 13:
      return (reader.readLong(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    case 15:
      return (reader.readDouble(offset)) as P;
    case 16:
      return (reader.readString(offset)) as P;
    case 17:
      return (reader.readString(offset)) as P;
    case 18:
      return (_ShapeElementtypeValueEnumMap[reader.readByteOrNull(offset)] ??
          ShapeType.line) as P;
    case 19:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _ShapeElementtypeEnumValueMap = {
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
const _ShapeElementtypeValueEnumMap = {
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

extension ShapeElementQueryFilter
    on QueryBuilder<ShapeElement, ShapeElement, QFilterCondition> {
  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> colorEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'color',
        value: value,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> colorLessThan(
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> colorBetween(
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      endBindingIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'endBindingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      endBindingIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'endBindingId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      endBindingIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'endBindingId',
        value: '',
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      endBindingIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'endBindingId',
        value: '',
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      fillColorEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fillColor',
        value: value,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      fontFamilyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'fontFamily',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      fontFamilyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'fontFamily',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      fontFamilyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fontFamily',
        value: '',
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      fontFamilyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'fontFamily',
        value: '',
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      hasFillEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hasFill',
        value: value,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> idEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> idGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> idLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> idBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> idStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> idEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> idContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> idMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'id',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> isBoldEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isBold',
        value: value,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      isItalicEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isItalic',
        value: value,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> seedEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'seed',
        value: value,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> seedLessThan(
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> seedBetween(
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      startBindingIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'startBindingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      startBindingIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'startBindingId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      startBindingIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'startBindingId',
        value: '',
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      startBindingIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'startBindingId',
        value: '',
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      svgRelativePathEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'svgRelativePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      svgRelativePathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'svgRelativePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      svgRelativePathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'svgRelativePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      svgRelativePathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'svgRelativePath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      svgRelativePathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'svgRelativePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      svgRelativePathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'svgRelativePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      svgRelativePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'svgRelativePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      svgRelativePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'svgRelativePath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      svgRelativePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'svgRelativePath',
        value: '',
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      svgRelativePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'svgRelativePath',
        value: '',
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> textEqualTo(
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> textLessThan(
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> textBetween(
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> textEndsWith(
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> textContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> textMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'text',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      textIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'text',
        value: '',
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      textIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'text',
        value: '',
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> typeEqualTo(
      ShapeType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
      typeGreaterThan(
    ShapeType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> typeLessThan(
    ShapeType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> typeBetween(
    ShapeType lower,
    ShapeType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'type',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> zOrderEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'zOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition>
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

  QueryBuilder<ShapeElement, ShapeElement, QAfterFilterCondition> zOrderBetween(
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

extension ShapeElementQueryObject
    on QueryBuilder<ShapeElement, ShapeElement, QFilterCondition> {}
