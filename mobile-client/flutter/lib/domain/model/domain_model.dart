enum DomainFieldType {
  string('String'),
  integer('Integer'),
  long('Long'),
  doubleType('Double'),
  decimal('Decimal'),
  boolean('Boolean'),
  date('Date'),
  dateTime('DateTime'),
  uuid('UUID');

  const DomainFieldType(this.wireName);

  final String wireName;

  static DomainFieldType? tryParse(String value) {
    for (final type in values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}

enum DomainRelationshipKind {
  oneToOne('ONE_TO_ONE', many: false),
  oneToMany('ONE_TO_MANY', many: true),
  manyToOne('MANY_TO_ONE', many: false),
  manyToMany('MANY_TO_MANY', many: true);

  const DomainRelationshipKind(this.wireName, {required this.many});

  final String wireName;
  final bool many;

  static DomainRelationshipKind? tryParse(String value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

class DomainField {
  const DomainField({
    required this.name,
    required this.type,
    required this.required,
    required this.generated,
    required this.unique,
  });

  final String name;
  final DomainFieldType type;
  final bool required;
  final bool generated;
  final bool unique;
}

class DomainRelationship {
  const DomainRelationship({
    required this.name,
    required this.apiField,
    required this.targetEntity,
    required this.kind,
    required this.many,
    required this.required,
    required this.writable,
  });

  final String name;
  final String apiField;
  final String targetEntity;
  final DomainRelationshipKind kind;
  final bool many;
  final bool required;
  final bool writable;
}

class DomainEntity {
  DomainEntity({
    required this.name,
    required this.endpoint,
    required this.idField,
    required List<DomainField> fields,
    required List<DomainRelationship> relationships,
  }) : fields = List.unmodifiable(fields),
       relationships = List.unmodifiable(relationships);

  final String name;
  final String endpoint;
  final String idField;
  final List<DomainField> fields;
  final List<DomainRelationship> relationships;

  DomainField? fieldNamed(String name) {
    final requested = _normalized(name);
    for (final field in fields) {
      if (_normalized(field.name) == requested) return field;
    }
    return null;
  }

  DomainRelationship? relationshipNamed(String name) {
    final requested = _normalized(name);
    for (final relationship in relationships) {
      if (_normalized(relationship.name) == requested ||
          _normalized(relationship.apiField) == requested) {
        return relationship;
      }
    }
    return null;
  }
}

class DomainModel {
  DomainModel({
    required this.schemaVersion,
    required this.application,
    required this.artifactId,
    required this.basePath,
    required List<DomainEntity> entities,
  }) : entities = List.unmodifiable(entities);

  static const supportedSchemaVersion = '1.0.0';

  final String schemaVersion;
  final String application;
  final String artifactId;
  final String basePath;
  final List<DomainEntity> entities;

  DomainEntity? entityNamed(String name) {
    final requested = _normalized(name);
    for (final entity in entities) {
      if (_normalized(entity.name) == requested) return entity;
    }
    return null;
  }
}

String _normalized(String value) => value.trim().toLowerCase();
