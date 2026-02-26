"""Shared fixtures for brain-template tests."""
import json
import os
import shutil
import tempfile

import pytest


@pytest.fixture
def brain_dir():
    """Create a temporary brain directory with standard structure."""
    d = tempfile.mkdtemp(prefix="brain-test-")
    # Create standard dirs
    for subdir in [
        "threads", "people", "archive", "archive/handoffs",
        "archive/commitments", "inbox", "inbox/granola",
        "inbox/prep", "inbox/.processed",
    ]:
        os.makedirs(os.path.join(d, subdir), exist_ok=True)

    # Minimal config.md
    with open(os.path.join(d, "config.md"), "w") as f:
        f.write("# Config\n## Identity\nName: Test User\n")

    # Minimal preferences.md
    with open(os.path.join(d, "preferences.md"), "w") as f:
        f.write("# Preferences\n- Rule one\n- Rule two\n")

    yield d
    shutil.rmtree(d, ignore_errors=True)


@pytest.fixture
def sample_handoff(brain_dir):
    """Create a handoff.md with multiple entries."""
    entries = []
    for i in range(20):
        day = 20 - i
        entries.append(
            f"## 2026-01-{day:02d} — Day {day} session\n\n"
            f"### Key Outcomes\n- Did thing {day}\n\n"
            f"### For Tomorrow\n- Do thing {day + 1}\n"
        )

    content = "# Handoff\n\n---\n\n" + "\n".join(entries)
    path = os.path.join(brain_dir, "handoff.md")
    with open(path, "w") as f:
        f.write(content)
    return path


@pytest.fixture
def sample_health(brain_dir):
    """Create a health.md with many history rows."""
    header = """# System Health

## Latest Run
<!-- Updated automatically by /wind-down Phase 6 -->

- **Date**: 2026-01-20
- **Meetings processed**: 3

## History

| Date | Meetings | Words | Mode | Decisions | Corrections | Threads | People | Rules |
|------|----------|-------|------|-----------|-------------|---------|--------|-------|
"""
    rows = []
    for i in range(40):
        day = 40 - i
        rows.append(
            f"| 2025-12-{day:02d} | 2 | 1000 | full | 5 (3/1/1) | 0 | 4/1 | 3 | 5 |"
            if day <= 31
            else f"| 2026-01-{day - 31:02d} | 2 | 1000 | full | 5 (3/1/1) | 0 | 4/1 | 3 | 5 |"
        )

    content = header + "\n".join(rows) + "\n"
    path = os.path.join(brain_dir, "health.md")
    with open(path, "w") as f:
        f.write(content)
    return path


@pytest.fixture
def sample_commitments(brain_dir):
    """Create a commitments.md with active and completed items."""
    content = """# Commitments

## Active

- [ ] Share WA+AISP spec with Wei — added 2026-01-15
- [ ] Follow up with Simone about deployment — added 2026-01-18
- [ ] Review PR #42 — added 2026-01-19

## Completed

- [x] Set up CI pipeline — completed 2025-11-01
- [x] Write design doc — completed 2025-11-15
- [x] Old task from ages ago — completed 2025-10-01
- [x] Recent completion — completed 2026-01-18
"""
    path = os.path.join(brain_dir, "commitments.md")
    with open(path, "w") as f:
        f.write(content)
    return path


@pytest.fixture
def sample_people(brain_dir):
    """Create sample people files."""
    people = {
        "wei-zhang.md": "# Wei Zhang\n\n**Role**: Engineering Lead\n**Focus**: Platform architecture\n\n- Working on AISP integration\n",
        "simone-cirillo.md": "# Simone Cirillo\n\n**Role**: Product Manager\n**Focus**: User onboarding\n\n- Leading deployment planning\n",
    }
    for fname, content in people.items():
        with open(os.path.join(brain_dir, "people", fname), "w") as f:
            f.write(content)
    return os.path.join(brain_dir, "people")


@pytest.fixture
def sample_threads(brain_dir):
    """Create sample thread files."""
    threads = {
        "aisp-integration.md": "# AISP Integration\n\n**Status**: Active\n\n## Updates\n- 2026-01-15: Wei presented initial spec\n- 2026-01-18: Simone reviewed scope\n",
        "deployment-planning.md": "# Deployment Planning\n\n**Status**: Active\n\n## Updates\n- 2026-01-17: Simone outlined timeline\n",
        "old-project.md": "# Old Project\n\n**Status**: Dormant\n\n## Updates\n- 2025-06-01: Wrapped up phase 1\n",
    }
    for fname, content in threads.items():
        with open(os.path.join(brain_dir, "threads", fname), "w") as f:
            f.write(content)
    return os.path.join(brain_dir, "threads")


@pytest.fixture
def sample_transcript(brain_dir):
    """Create a sample Granola transcript snapshot."""
    snapshot = {
        "id": "test-meeting-1",
        "title": "Weekly Sync with Wei",
        "created_at": "2026-01-20T10:00:00Z",
        "google_calendar_event": {
            "summary": "Weekly Sync",
            "start": {"dateTime": "2026-01-20T10:00:00-08:00"},
            "attendees": [
                {"email": "wei@example.com", "displayName": "Wei Zhang"},
                {"email": "me@example.com", "displayName": "Test User", "self": True},
            ],
        },
        "transcript": [
            {"text": "So the AISP integration is going well and we are making good progress on the overall platform."},
            {"text": "Wei mentioned that we need to finalize the API contract before we can move forward with the implementation phase."},
            {"text": "We decided to use REST instead of GraphQL for the initial version because it will be simpler to maintain and debug."},
            {"text": "Simone will review the deployment timeline next week and provide feedback on the resource allocation plan."},
            {"text": "Action item: Wei will share the updated spec by Friday so the team can review it before the next sprint planning."},
            {"text": "We also discussed the testing strategy and agreed that we should have integration tests for all API endpoints."},
            {"text": "The team is aligned on the overall direction and everyone seems excited about the new architecture approach."},
            {"text": "Let's follow up on the deployment planning in our next meeting to make sure we are on track for the deadline."},
        ],
    }
    date_dir = os.path.join(brain_dir, "inbox", "granola", "2026-01-20")
    os.makedirs(date_dir, exist_ok=True)
    path = os.path.join(date_dir, "weekly-sync-with-wei.json")
    with open(path, "w") as f:
        json.dump(snapshot, f)
    return path
