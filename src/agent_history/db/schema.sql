PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS agents (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    product TEXT NOT NULL,
    adapter_id TEXT NOT NULL,
    adapter_version TEXT,
    created_at TEXT NOT NULL,
    metadata_json TEXT NOT NULL DEFAULT '{}'
        CHECK (json_valid(metadata_json))
);

CREATE TABLE IF NOT EXISTS conversations (
    id TEXT PRIMARY KEY,
    agent_id TEXT NOT NULL REFERENCES agents(id) ON DELETE RESTRICT,
    source_conversation_id TEXT,
    title TEXT,
    workspace_ref TEXT,
    started_at TEXT,
    ended_at TEXT,
    imported_at TEXT NOT NULL,
    source_format TEXT NOT NULL,
    source_format_version TEXT,
    source_file_name TEXT,
    source_sha256 TEXT,
    metadata_json TEXT NOT NULL DEFAULT '{}'
        CHECK (json_valid(metadata_json)),
    CHECK (ended_at IS NULL OR started_at IS NULL OR ended_at >= started_at)
);

CREATE TABLE IF NOT EXISTS source_artifacts (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    artifact_kind TEXT NOT NULL CHECK (artifact_kind IN (
        'conversation_export', 'attachment', 'workspace_snapshot', 'other'
    )),
    file_name TEXT,
    media_type TEXT,
    byte_length INTEGER NOT NULL CHECK (byte_length >= 0),
    sha256 TEXT NOT NULL,
    content BLOB NOT NULL,
    captured_at TEXT NOT NULL,
    metadata_json TEXT NOT NULL DEFAULT '{}'
        CHECK (json_valid(metadata_json)),
    CHECK (length(content) = byte_length)
);

CREATE TABLE IF NOT EXISTS events (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sequence INTEGER NOT NULL CHECK (sequence >= 0),
    parent_event_id TEXT REFERENCES events(id) ON DELETE SET NULL,
    source_event_id TEXT,
    event_type TEXT NOT NULL CHECK (event_type IN (
        'message', 'tool_call', 'tool_result', 'file_change',
        'approval', 'checkpoint', 'error', 'other'
    )),
    actor TEXT NOT NULL CHECK (actor IN (
        'user', 'assistant', 'tool', 'system', 'unknown'
    )),
    name TEXT,
    content TEXT,
    created_at TEXT,
    tool_name TEXT,
    call_id TEXT,
    status TEXT,
    payload_json TEXT NOT NULL DEFAULT '{}'
        CHECK (json_valid(payload_json)),
    source_artifact_id TEXT REFERENCES source_artifacts(id) ON DELETE SET NULL,
    source_fragment BLOB,
    UNIQUE (conversation_id, sequence)
);

CREATE TABLE IF NOT EXISTS event_parts (
    id TEXT PRIMARY KEY,
    event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    sequence INTEGER NOT NULL CHECK (sequence >= 0),
    part_type TEXT NOT NULL CHECK (part_type IN (
        'text', 'image', 'audio', 'video', 'file', 'tool_call',
        'tool_result', 'thinking', 'refusal', 'other'
    )),
    text_content TEXT,
    artifact_id TEXT REFERENCES source_artifacts(id) ON DELETE SET NULL,
    payload_json TEXT NOT NULL DEFAULT '{}'
        CHECK (json_valid(payload_json)),
    source_fragment BLOB,
    UNIQUE (event_id, sequence)
);

CREATE TABLE IF NOT EXISTS files (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    path TEXT NOT NULL,
    relation TEXT NOT NULL DEFAULT 'referenced' CHECK (relation IN (
        'created', 'modified', 'deleted', 'referenced', 'unknown'
    )),
    content_sha256 TEXT,
    content TEXT,
    media_type TEXT,
    is_snapshot INTEGER NOT NULL DEFAULT 0 CHECK (is_snapshot IN (0, 1)),
    sensitivity TEXT NOT NULL DEFAULT 'unknown' CHECK (sensitivity IN (
        'unknown', 'reviewed', 'redacted', 'sensitive'
    )),
    metadata_json TEXT NOT NULL DEFAULT '{}'
        CHECK (json_valid(metadata_json)),
    UNIQUE (conversation_id, path, relation, content_sha256)
);

CREATE TABLE IF NOT EXISTS event_files (
    event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    file_id TEXT NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    relation TEXT NOT NULL DEFAULT 'mentioned' CHECK (relation IN (
        'mentioned', 'created', 'modified', 'deleted', 'attached', 'unknown'
    )),
    PRIMARY KEY (event_id, file_id, relation)
);

CREATE INDEX IF NOT EXISTS idx_conversations_agent_started
    ON conversations(agent_id, started_at);
CREATE INDEX IF NOT EXISTS idx_events_conversation_sequence
    ON events(conversation_id, sequence);
CREATE INDEX IF NOT EXISTS idx_events_call_id
    ON events(conversation_id, call_id);
CREATE INDEX IF NOT EXISTS idx_event_parts_event_sequence
    ON event_parts(event_id, sequence);
CREATE INDEX IF NOT EXISTS idx_source_artifacts_conversation
    ON source_artifacts(conversation_id, artifact_kind);
CREATE INDEX IF NOT EXISTS idx_files_conversation_path
    ON files(conversation_id, path);