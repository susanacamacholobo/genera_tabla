import 'package:software1_mobile/domain/model/domain_model.dart';

DomainModel buildDomainModelFixture() => DomainModel(
  schemaVersion: DomainModel.supportedSchemaVersion,
  application: 'Veterinaria',
  artifactId: 'veterinaria-api',
  basePath: '/api',
  entities: [
    DomainEntity(
      name: 'Cliente',
      endpoint: '/clientes',
      idField: 'id',
      fields: const [
        DomainField(
          name: 'id',
          type: DomainFieldType.long,
          required: true,
          generated: true,
          unique: true,
        ),
        DomainField(
          name: 'nombre',
          type: DomainFieldType.string,
          required: true,
          generated: false,
          unique: false,
        ),
        DomainField(
          name: 'saldo',
          type: DomainFieldType.decimal,
          required: false,
          generated: false,
          unique: false,
        ),
        DomainField(
          name: 'fechaRegistro',
          type: DomainFieldType.dateTime,
          required: true,
          generated: false,
          unique: false,
        ),
      ],
      relationships: const [
        DomainRelationship(
          name: 'mascotas',
          apiField: 'mascotasIds',
          targetEntity: 'Mascota',
          kind: DomainRelationshipKind.oneToMany,
          many: true,
          required: false,
          writable: false,
        ),
      ],
    ),
    DomainEntity(
      name: 'Mascota',
      endpoint: '/mascotas',
      idField: 'id',
      fields: const [
        DomainField(
          name: 'id',
          type: DomainFieldType.long,
          required: true,
          generated: true,
          unique: true,
        ),
        DomainField(
          name: 'nombre',
          type: DomainFieldType.string,
          required: true,
          generated: false,
          unique: false,
        ),
      ],
      relationships: const [
        DomainRelationship(
          name: 'cliente',
          apiField: 'clienteId',
          targetEntity: 'Cliente',
          kind: DomainRelationshipKind.manyToOne,
          many: false,
          required: true,
          writable: true,
        ),
      ],
    ),
  ],
);
