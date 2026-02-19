-- schema.sql - Brain system SQLite schema
--
-- This database sits alongside the markdown files as a fast lookup index.
-- Markdown files remain the source of truth. The DB is derived and rebuildable.
--
-- Location: ~/brain/.brain.db (gitignored)

-- All markdown files tracked by the system
CREATE TABLE IF NOT EXISTS documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT UNIQUE NOT NULL,           -- relative path from brain root (e.g., "threads/ai-topic-map.md")
    type TEXT NOT NULL,                  -- thread, person, handoff, commitment, meeting, config, health, preferences
    title TEXT,                          -- extracted title (first # heading or filename)
    content TEXT,                        -- full file content
    content_hash TEXT,                   -- SHA-256 of content for change detection
    created_at TEXT,                     -- first seen
    updated_at TEXT                      -- last modified
);

-- Named entities extracted from documents
CREATE TABLE IF NOT EXISTS entities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,                  -- display name (e.g., "Wei", "AI Topic Map", "Send AISP analysis")
    type TEXT NOT NULL,                  -- person, thread, meeting, commitment, term
    slug TEXT,                           -- filesystem slug (e.g., "wei", "ai-topic-map")
    document_id INTEGER,                -- source document (NULL for entities without their own file)
    metadata TEXT,                       -- JSON blob for type-specific data (status, role, dates, etc.)
    FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_entities_type_slug ON entities(type, slug);

-- Relationships between entities
CREATE TABLE IF NOT EXISTS relationships (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id INTEGER NOT NULL,          -- entity that references
    target_id INTEGER NOT NULL,          -- entity being referenced
    type TEXT NOT NULL,                  -- mentioned_in, discussed_at, committed_to, related_to, attended
    context TEXT,                        -- snippet showing the connection
    source_document_id INTEGER,          -- document where this relationship was found
    created_at TEXT,
    FOREIGN KEY (source_id) REFERENCES entities(id) ON DELETE CASCADE,
    FOREIGN KEY (target_id) REFERENCES entities(id) ON DELETE CASCADE,
    FOREIGN KEY (source_document_id) REFERENCES documents(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_rel_source ON relationships(source_id);
CREATE INDEX IF NOT EXISTS idx_rel_target ON relationships(target_id);
CREATE INDEX IF NOT EXISTS idx_rel_type ON relationships(type);

-- Full-text search index across all document content and entity names
CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
    title,
    content,
    entity_names,                        -- space-separated entity names mentioned in this doc
    path UNINDEXED,                      -- for linking back to source file
    document_id UNINDEXED,               -- for joining
    type UNINDEXED,                      -- for filtering results by type
    tokenize='porter unicode61'          -- stemming + unicode support
);

-- Metadata table for tracking indexer state
CREATE TABLE IF NOT EXISTS indexer_meta (
    key TEXT PRIMARY KEY,
    value TEXT
);
