#!/usr/bin/env python3
"""
query-graph.py - Query the brain's relationship graph.

Traverses entity relationships to answer questions like:
  - Who have I discussed X with?
  - What threads connect to this person?
  - What's the full context around a topic?

Usage:
    python3 scripts/query-graph.py [brain-root] connections <entity-name>
    python3 scripts/query-graph.py [brain-root] person <name>
    python3 scripts/query-graph.py [brain-root] thread <name>
    python3 scripts/query-graph.py [brain-root] timeline <entity-name>
    python3 scripts/query-graph.py [brain-root] stats
"""

import json
import os
import sqlite3
import sys
from pathlib import Path

BRAIN_ROOT = Path(sys.argv[1]) if len(sys.argv) > 2 and not sys.argv[1].startswith("--") else Path.home() / "brain"
DB_PATH = BRAIN_ROOT / ".brain.db"


def get_conn():
    if not DB_PATH.exists():
        print(f"Error: Database not found at {DB_PATH}", file=sys.stderr)
        print("Run: python3 scripts/indexer.py", file=sys.stderr)
        sys.exit(1)
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn


def cmd_connections(name):
    """Show all entities connected to the given entity."""
    conn = get_conn()

    # Find the entity
    entity = conn.execute(
        "SELECT * FROM entities WHERE name LIKE ? OR slug LIKE ?",
        (f"%{name}%", f"%{name}%")
    ).fetchone()

    if not entity:
        print(f"No entity found matching '{name}'")
        return

    print(f"=== {entity['name']} ({entity['type']}) ===")
    if entity['metadata']:
        meta = json.loads(entity['metadata'])
        for k, v in meta.items():
            print(f"  {k}: {v}")
    print()

    # Outgoing relationships
    outgoing = conn.execute("""
        SELECT e2.name, e2.type, r.type as rel_type, r.context
        FROM relationships r
        JOIN entities e2 ON r.target_id = e2.id
        WHERE r.source_id = ?
        ORDER BY e2.type, e2.name
    """, (entity['id'],)).fetchall()

    if outgoing:
        print("Connects to:")
        for row in outgoing:
            ctx = f" — {row['context']}" if row['context'] else ""
            print(f"  → {row['name']} ({row['type']}) [{row['rel_type']}]{ctx}")
        print()

    # Incoming relationships
    incoming = conn.execute("""
        SELECT e1.name, e1.type, r.type as rel_type, r.context
        FROM relationships r
        JOIN entities e1 ON r.source_id = e1.id
        WHERE r.target_id = ?
        ORDER BY e1.type, e1.name
    """, (entity['id'],)).fetchall()

    if incoming:
        print("Referenced by:")
        for row in incoming:
            ctx = f" — {row['context']}" if row['context'] else ""
            print(f"  ← {row['name']} ({row['type']}) [{row['rel_type']}]{ctx}")


def cmd_person(name):
    """Show full context for a person: their threads, meetings, connections."""
    conn = get_conn()

    person = conn.execute(
        "SELECT * FROM entities WHERE type = 'person' AND (name LIKE ? OR slug LIKE ?)",
        (f"%{name}%", f"%{name}%")
    ).fetchone()

    if not person:
        print(f"No person found matching '{name}'")
        return

    print(f"=== {person['name']} ===")
    if person['metadata']:
        meta = json.loads(person['metadata'])
        for k, v in meta.items():
            print(f"  {k}: {v}")
    print()

    # What threads are they connected to?
    threads = conn.execute("""
        SELECT DISTINCT e2.name, e2.metadata
        FROM relationships r
        JOIN entities e2 ON r.target_id = e2.id
        WHERE r.source_id = ? AND e2.type = 'thread'
        UNION
        SELECT DISTINCT e1.name, e1.metadata
        FROM relationships r
        JOIN entities e1 ON r.source_id = e1.id
        WHERE r.target_id = ? AND e1.type = 'thread'
    """, (person['id'], person['id'])).fetchall()

    if threads:
        print("Threads:")
        for t in threads:
            status = ""
            if t['metadata']:
                meta = json.loads(t['metadata'])
                status = f" [{meta.get('status', '')}]" if meta.get('status') else ""
            print(f"  • {t['name']}{status}")
        print()

    # What meetings reference them?
    meetings = conn.execute("""
        SELECT DISTINCT d.path, d.title
        FROM documents d
        WHERE d.type = 'meeting'
        AND d.content LIKE ?
        ORDER BY d.path DESC
    """, (f"%{person['name']}%",)).fetchall()

    if meetings:
        print("Meetings:")
        for m in meetings:
            print(f"  • {m['title']} ({m['path']})")


def cmd_thread(name):
    """Show full context for a thread: people involved, meetings, status."""
    conn = get_conn()

    thread = conn.execute(
        "SELECT * FROM entities WHERE type = 'thread' AND (name LIKE ? OR slug LIKE ?)",
        (f"%{name}%", f"%{name}%")
    ).fetchone()

    if not thread:
        print(f"No thread found matching '{name}'")
        return

    print(f"=== {thread['name']} ===")
    if thread['metadata']:
        meta = json.loads(thread['metadata'])
        for k, v in meta.items():
            print(f"  {k}: {v}")
    print()

    # Related threads
    related = conn.execute("""
        SELECT DISTINCT e2.name, e2.metadata
        FROM relationships r
        JOIN entities e2 ON r.target_id = e2.id
        WHERE r.source_id = ? AND e2.type = 'thread'
    """, (thread['id'],)).fetchall()

    if related:
        print("Related threads:")
        for t in related:
            print(f"  • {t['name']}")
        print()

    # Meetings that mention this thread
    meetings = conn.execute("""
        SELECT DISTINCT e1.name, e1.metadata
        FROM relationships r
        JOIN entities e1 ON r.source_id = e1.id
        WHERE r.target_id = ? AND e1.type = 'meeting'
    """, (thread['id'],)).fetchall()

    if meetings:
        print("Discussed in:")
        for m in meetings:
            date = ""
            if m['metadata']:
                meta = json.loads(m['metadata'])
                date = f" ({meta.get('date', '')})" if meta.get('date') else ""
            print(f"  • {m['name']}{date}")
        print()

    # People connected to this thread
    people = conn.execute("""
        SELECT DISTINCT e1.name
        FROM relationships r
        JOIN entities e1 ON r.source_id = e1.id
        WHERE r.target_id = ? AND e1.type = 'person'
        UNION
        SELECT DISTINCT e2.name
        FROM relationships r
        JOIN entities e2 ON r.target_id = e2.id
        WHERE r.source_id = ? AND e2.type = 'person'
    """, (thread['id'], thread['id'])).fetchall()

    if people:
        print("People involved:")
        for p in people:
            print(f"  • {p['name']}")


def cmd_timeline(name):
    """Show chronological mentions of an entity across all documents."""
    conn = get_conn()

    # Search across all documents for mentions
    results = conn.execute("""
        SELECT type, path, title, snippet(search_index, 1, '>>>', '<<<', '...', 40) as snippet
        FROM search_index
        WHERE search_index MATCH ?
        ORDER BY path
        LIMIT 20
    """, (name,)).fetchall()

    if not results:
        print(f"No mentions found for '{name}'")
        return

    print(f"=== Timeline: {name} ===\n")
    for row in results:
        print(f"[{row['type']}] {row['title']}")
        print(f"  {row['path']}")
        print(f"  {row['snippet']}")
        print()


def cmd_stats():
    """Show overall graph statistics."""
    conn = get_conn()

    doc_count = conn.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
    entity_count = conn.execute("SELECT COUNT(*) FROM entities").fetchone()[0]
    rel_count = conn.execute("SELECT COUNT(*) FROM relationships").fetchone()[0]

    print(f"=== Brain Graph Stats ===")
    print(f"  Documents: {doc_count}")
    print(f"  Entities:  {entity_count}")
    print(f"  Relations: {rel_count}")
    print()

    # Breakdown by type
    print("Documents by type:")
    for row in conn.execute("SELECT type, COUNT(*) as n FROM documents GROUP BY type ORDER BY n DESC"):
        print(f"  {row['type']}: {row['n']}")
    print()

    print("Entities by type:")
    for row in conn.execute("SELECT type, COUNT(*) as n FROM entities GROUP BY type ORDER BY n DESC"):
        print(f"  {row['type']}: {row['n']}")
    print()

    # Most connected entities
    print("Most connected entities:")
    for row in conn.execute("""
        SELECT e.name, e.type,
            (SELECT COUNT(*) FROM relationships WHERE source_id = e.id) +
            (SELECT COUNT(*) FROM relationships WHERE target_id = e.id) as connections
        FROM entities e
        ORDER BY connections DESC
        LIMIT 10
    """):
        print(f"  {row['name']} ({row['type']}): {row['connections']} connections")

    # Last indexed
    meta = conn.execute("SELECT value FROM indexer_meta WHERE key = 'last_indexed'").fetchone()
    if meta:
        print(f"\nLast indexed: {meta[0]}")


def main():
    args = sys.argv[1:]
    # Skip brain root arg if it's a path
    if args and not args[0].startswith("--") and os.path.isdir(args[0]):
        args = args[1:]

    if not args:
        print(__doc__)
        sys.exit(0)

    command = args[0]
    query = " ".join(args[1:]) if len(args) > 1 else ""

    if command == "connections":
        cmd_connections(query)
    elif command == "person":
        cmd_person(query)
    elif command == "thread":
        cmd_thread(query)
    elif command == "timeline":
        cmd_timeline(query)
    elif command == "stats":
        cmd_stats()
    else:
        print(f"Unknown command: {command}")
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
