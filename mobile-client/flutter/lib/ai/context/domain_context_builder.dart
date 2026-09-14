import '../../domain/model/domain_model.dart';

class DomainContextBuilder {
  const DomainContextBuilder();

  String build(DomainModel model) {
    final buffer = StringBuffer()
      ..writeln('Available entities for ${model.application}:');
    for (final entity in model.entities) {
      buffer.writeln('${entity.name} (${entity.endpoint}):');
      for (final field in entity.fields) {
        buffer.writeln(
          '- ${field.name}: ${field.type.wireName}'
          '${field.required ? ', required' : ', optional'}'
          '${field.generated ? ', generated' : ''}',
        );
      }
      for (final relationship in entity.relationships) {
        buffer.writeln(
          '- ${relationship.apiField}: ID${relationship.many ? '[]' : ''} '
          'of ${relationship.targetEntity}'
          '${relationship.required ? ', required' : ', optional'}'
          '${relationship.writable ? '' : ', read-only'}',
        );
      }
    }
    buffer.write(
      'Allowed operations: CREATE_ENTITY, GET_ENTITY, LIST_ENTITIES, '
      'UPDATE_ENTITY, DELETE_ENTITY, SEARCH_ENTITY.',
    );
    return buffer.toString();
  }
}
