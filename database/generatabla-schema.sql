-- GeneraTabla CASE - esquema PostgreSQL
-- Fuente: migraciones Alembic 20260912_01 y 20260912_02.
-- Ejecutar sobre una base de datos vacia llamada "generatabla".
-- No contiene usuarios, contrasenas ni datos de proyectos.

BEGIN;

CREATE TABLE alembic_version (
    version_num VARCHAR(32) NOT NULL,
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);

CREATE TABLE projects (
    id VARCHAR(36) NOT NULL,
    name VARCHAR(200) NOT NULL,
    revision INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT pk_projects PRIMARY KEY (id)
);

CREATE INDEX ix_projects_name ON projects (name);

CREATE TABLE project_snapshots (
    id VARCHAR(36) NOT NULL,
    project_id VARCHAR(36) NOT NULL,
    revision INTEGER NOT NULL,
    model_json JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT pk_project_snapshots PRIMARY KEY (id),
    CONSTRAINT fk_project_snapshots_project_id_projects
        FOREIGN KEY (project_id)
        REFERENCES projects (id)
        ON DELETE CASCADE,
    CONSTRAINT uq_project_snapshots_revision
        UNIQUE (project_id, revision)
);

CREATE INDEX ix_project_snapshots_project_id
    ON project_snapshots (project_id);

CREATE TABLE change_events (
    id VARCHAR(36) NOT NULL,
    project_id VARCHAR(36) NOT NULL,
    command_id VARCHAR(200) NOT NULL,
    base_revision INTEGER NOT NULL,
    revision INTEGER NOT NULL,
    command_json JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT pk_change_events PRIMARY KEY (id),
    CONSTRAINT fk_change_events_project_id_projects
        FOREIGN KEY (project_id)
        REFERENCES projects (id)
        ON DELETE CASCADE,
    CONSTRAINT uq_change_events_command
        UNIQUE (project_id, command_id),
    CONSTRAINT uq_change_events_revision
        UNIQUE (project_id, revision)
);

CREATE INDEX ix_change_events_project_id
    ON change_events (project_id);

-- Informa a Alembic que el esquema incluye todas las migraciones actuales.
INSERT INTO alembic_version (version_num) VALUES ('20260912_02');

COMMIT;
