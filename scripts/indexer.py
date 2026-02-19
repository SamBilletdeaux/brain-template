#!/usr/bin/env python3
"""
indexer.py - Build and update the brain's SQLite search index.

Scans all markdown files in the brain directory, extracts entities and
relationships, and populates the SQLite database for fast search and
graph queries.

Incremental: only re-indexes files whose content hash has changed.

Usage:
    python3 scripts/indexer.py [brain-root]
    python3 scripts/indexer.py ~/brain --full    # force full re-index
"""

import hashlib
import json
import os
import re
import sqlite3
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

# --- Configuration ---

BRAIN_ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else Path.home() / "brain"
FULL_REINDEX = "--full" in sys.argv
DB_PATH = BRAIN_ROOT / ".brain.db"
SCHEMA_PATH = Path(__file__).parent / "schema.sql"

# File types to index and their classification
FILE_PATTERNS = {
    "threads": "thread",
    "people": "person",
    "archive/meetings": "meeting",
}
ROOT_FILES = {
    "handoff.md": "handoff",
    "commitments.md": "commitment",
    "config.md": "config",
    "health.md": "health",
    "preferences.md": "preferences",
}


def sha256(content: str) -> str:
    return hashlib.sha256(content.encode()).hexdigest()


def extract_title(content: str, path: str) -> str:
    """Extract the first # heading, or fall back to filename."""
    match = re.search(r"^#\s+(.+)$", content, re.MULTILINE)
    if match:
        return match.group(1).strip()
    return Path(path).stem.replace("-", " ").title()


def extract_wiki_links(content: str) -> List[str]:
    """Find all [[wiki-link]] references."""
    return re.findall(r"\[\[([^\]]+)\]\]", content)


def extract_status(content: str) -> Optional[str]:
    """Extract thread status like '🟢 Active' or '🔴 Resolved'."""
    match = re.search(r"\*\*Status\*\*:\s*(.+?)$", content, re.MULTILINE)
    if match:
        return match.group(1).strip()
    return None


def extract_dates(content: str) -> List[str]:
    """Find all YYYY-MM-DD dates in content."""
    return list(set(re.findall(r"\b(\d{4}-\d{2}-\d{2})\b", content)))


def extract_people_mentioned(content: str) -> List[str]:
    """Extract @mentions and names from people/ references."""
    mentions = re.findall(r"@(\w+)", content)
    return mentions


def extract_role(content: str) -> Optional[str]:
    """Extract role from a people file."""
    match = re.search(r"\*\*Role\*\*:\s*(.+?)$", content, re.MULTILINE)
    if match:
        return match.group(1).strip()
    return None


def extract_commitments(content: str) -> List[Dict]:
    """Extract commitment items from commitments.md."""
    items = []
    for match in re.finditer(r"^- \[([ x])\]\s+(.+?)$", content, re.MULTILINE):
        checked = match.group(1) == "x"
        text = match.group(2).strip()
        # Try to parse owner and date
        owner_match = re.search(r"@(\w+)", text)
        date_match = re.search(r"(\d{4}-\d{2}-\d{2})", text)
        items.append({
            "text": text,
            "completed": checked,
            "owner": owner_match.group(1) if owner_match else None,
            "date": date_match.group(1) if date_match else None,
        })
    return items


def classify_file(rel_path: str) -> Optional[str]:
    """Determine the document type from its path."""
    filename = os.path.basename(rel_path)

    # Check root files
    if filename in ROOT_FILES:
        return ROOT_FILES[filename]

    # Check directory-based classification
    for prefix, doc_type in FILE_PATTERNS.items():
        if rel_path.startswith(prefix + "/"):
            return doc_type

    return None


def find_markdown_files(brain_root: Path) -> List[Path]:
    """Find all indexable markdown files."""
    files = []

    # Root files
    for filename in ROOT_FILES:
        path = brain_root / filename
        if path.exists():
            files.append(path)

    # Directory-based files
    for dir_prefix in FILE_PATTERNS:
        dir_path = brain_root / dir_prefix
        if dir_path.exists():
            for md_file in dir_path.rglob("*.md"):
                if md_file.name != ".gitkeep":
                    files.append(md_file)

    return files


def init_db(db_path: Path, schema_path: Path) -> sqlite3.Connection:
    """Initialize the database with schema."""
    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")

    with open(schema_path) as f:
        conn.executescript(f.read())

    return conn


def get_or_create_entity(conn: sqlite3.Connection, name: str, entity_type: str,
                         slug: str = None, document_id: int = None,
                         metadata: dict = None) -> int:
    """Find an existing entity or create a new one. Returns entity ID."""
    if slug is None:
        slug = re.sub(r"[^\w\s-]", "", name.lower())
        slug = re.sub(r"[\s]+", "-", slug).strip("-")

    row = conn.execute(
        "SELECT id FROM entities WHERE type = ? AND slug = ?",
        (entity_type, slug)
    ).fetchone()

    if row:
        # Update if we have new info
        if document_id is not None:
            conn.execute(
                "UPDATE entities SET document_id = ?, metadata = ? WHERE id = ?",
                (document_id, json.dumps(metadata) if metadata else None, row[0])
            )
        return row[0]

    cursor = conn.execute(
        "INSERT INTO entities (name, type, slug, document_id, metadata) VALUES (?, ?, ?, ?, ?)",
        (name, entity_type, slug, document_id, json.dumps(metadata) if metadata else None)
    )
    return cursor.lastrowid


def add_relationship(conn: sqlite3.Connection, source_id: int, target_id: int,
                     rel_type: str, context: str = None,
                     source_document_id: int = None):
    """Add a relationship between two entities."""
    conn.execute(
        "INSERT INTO relationships (source_id, target_id, type, context, source_document_id, created_at) "
        "VALUES (?, ?, ?, ?, ?, ?)",
        (source_id, target_id, rel_type, context, source_document_id,
         datetime.now().isoformat())
    )


def index_document(conn: sqlite3.Connection, brain_root: Path, file_path: Path):
    """Index a single markdown file."""
    rel_path = str(file_path.relative_to(brain_root))
    doc_type = classify_file(rel_path)
    if doc_type is None:
        return

    content = file_path.read_text(encoding="utf-8", errors="replace")
    content_hash = sha256(content)

    # Check if unchanged
    if not FULL_REINDEX:
        row = conn.execute(
            "SELECT id, content_hash FROM documents WHERE path = ?", (rel_path,)
        ).fetchone()
        if row and row[1] == content_hash:
            return  # unchanged

    title = extract_title(content, rel_path)
    now = datetime.now().isoformat()

    # Upsert document
    existing = conn.execute("SELECT id FROM documents WHERE path = ?", (rel_path,)).fetchone()
    if existing:
        doc_id = existing[0]
        conn.execute(
            "UPDATE documents SET type=?, title=?, content=?, content_hash=?, updated_at=? WHERE id=?",
            (doc_type, title, content, content_hash, now, doc_id)
        )
        # Clear old relationships from this document
        conn.execute("DELETE FROM relationships WHERE source_document_id = ?", (doc_id,))
        # Update FTS
        conn.execute("DELETE FROM search_index WHERE document_id = ?", (str(doc_id),))
    else:
        cursor = conn.execute(
            "INSERT INTO documents (path, type, title, content, content_hash, created_at, updated_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            (rel_path, doc_type, title, content, content_hash, now, now)
        )
        doc_id = cursor.lastrowid

    # Extract entities based on document type
    entity_names = []

    if doc_type == "thread":
        slug = file_path.stem
        status = extract_status(content)
        metadata = {"status": status} if status else {}
        dates = extract_dates(content)
        if dates:
            metadata["last_date"] = max(dates)
        entity_id = get_or_create_entity(conn, title, "thread", slug, doc_id, metadata)
        entity_names.append(title)

        # Wiki-link relationships
        for link in extract_wiki_links(content):
            link_slug = link.lower().replace(" ", "-")
            target_id = get_or_create_entity(conn, link, "thread", link_slug)
            add_relationship(conn, entity_id, target_id, "related_to",
                             source_document_id=doc_id)
            entity_names.append(link)

    elif doc_type == "person":
        slug = file_path.stem
        role = extract_role(content)
        metadata = {"role": role} if role else {}
        dates = extract_dates(content)
        if dates:
            metadata["last_contact"] = max(dates)
        entity_id = get_or_create_entity(conn, title, "person", slug, doc_id, metadata)
        entity_names.append(title)

        # Wiki-link relationships (threads this person is connected to)
        for link in extract_wiki_links(content):
            link_slug = link.lower().replace(" ", "-")
            target_id = get_or_create_entity(conn, link, "thread", link_slug)
            add_relationship(conn, entity_id, target_id, "discussed_at",
                             source_document_id=doc_id)

    elif doc_type == "meeting":
        slug = file_path.stem
        dates = extract_dates(content)
        metadata = {}
        if dates:
            metadata["date"] = min(dates)
        entity_id = get_or_create_entity(conn, title, "meeting", slug, doc_id, metadata)
        entity_names.append(title)

        # Wiki-link relationships
        for link in extract_wiki_links(content):
            link_slug = link.lower().replace(" ", "-")
            target_id = get_or_create_entity(conn, link, "thread", link_slug)
            add_relationship(conn, entity_id, target_id, "mentioned_in",
                             source_document_id=doc_id)

    elif doc_type == "commitment":
        for item in extract_commitments(content):
            item_slug = re.sub(r"[^\w\s-]", "", item["text"][:40].lower())
            item_slug = re.sub(r"[\s]+", "-", item_slug).strip("-")
            metadata = {
                "completed": item["completed"],
                "owner": item["owner"],
                "date": item["date"],
            }
            entity_id = get_or_create_entity(conn, item["text"][:80], "commitment",
                                             item_slug, doc_id, metadata)
            entity_names.append(item["text"][:80])

    elif doc_type == "handoff":
        # Extract thread references from handoff
        for link in extract_wiki_links(content):
            link_slug = link.lower().replace(" ", "-")
            entity_names.append(link)

    # Update FTS index
    conn.execute(
        "INSERT INTO search_index (title, content, entity_names, path, document_id, type) "
        "VALUES (?, ?, ?, ?, ?, ?)",
        (title, content, " ".join(entity_names), rel_path, str(doc_id), doc_type)
    )


def main():
    if not BRAIN_ROOT.exists():
        print(f"Error: Brain root not found at {BRAIN_ROOT}", file=sys.stderr)
        sys.exit(1)

    if not SCHEMA_PATH.exists():
        print(f"Error: Schema not found at {SCHEMA_PATH}", file=sys.stderr)
        sys.exit(1)

    print(f"Indexing brain at {BRAIN_ROOT}...")
    if FULL_REINDEX:
        print("Mode: full re-index")
        if DB_PATH.exists():
            DB_PATH.unlink()

    conn = init_db(DB_PATH, SCHEMA_PATH)
    files = find_markdown_files(BRAIN_ROOT)
    indexed = 0
    skipped = 0

    for file_path in files:
        try:
            before = conn.total_changes
            index_document(conn, BRAIN_ROOT, file_path)
            if conn.total_changes > before:
                indexed += 1
            else:
                skipped += 1
        except Exception as e:
            print(f"  Error indexing {file_path}: {e}", file=sys.stderr)

    # Update indexer metadata
    conn.execute(
        "INSERT OR REPLACE INTO indexer_meta (key, value) VALUES (?, ?)",
        ("last_indexed", datetime.now().isoformat())
    )
    conn.execute(
        "INSERT OR REPLACE INTO indexer_meta (key, value) VALUES (?, ?)",
        ("document_count", str(len(files)))
    )

    conn.commit()

    # Report stats
    doc_count = conn.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
    entity_count = conn.execute("SELECT COUNT(*) FROM entities").fetchone()[0]
    rel_count = conn.execute("SELECT COUNT(*) FROM relationships").fetchone()[0]

    print(f"Done. Indexed {indexed}, skipped {skipped} unchanged.")
    print(f"  Documents: {doc_count}")
    print(f"  Entities:  {entity_count}")
    print(f"  Relations: {rel_count}")
    print(f"  DB size:   {DB_PATH.stat().st_size / 1024:.1f} KB")

    conn.close()


if __name__ == "__main__":
    main()
