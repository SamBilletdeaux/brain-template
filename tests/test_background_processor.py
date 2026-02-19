"""Tests for scripts/background-processor.py"""
import json
import os
import sys

import pytest

# Add scripts/ to path so we can import the module
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

import importlib
bp = importlib.import_module('background-processor')


class TestEntityExtraction:
    """Test rule-based entity extraction from transcripts."""

    def test_finds_known_people(self, brain_dir, sample_people):
        known_people = bp.load_people_names(brain_dir)
        transcript = "Wei mentioned the timeline. Simone agreed with the approach."
        summary = bp.rule_based_summary("Test", transcript, [], known_people, [])
        names = summary['mentioned_people']
        assert "Wei Zhang" in names
        assert "Simone Cirillo" in names

    def test_skips_short_name_fragments(self, brain_dir, sample_people):
        known_people = bp.load_people_names(brain_dir)
        # "we" is a 2-char fragment — should be skipped
        transcript = "We discussed the plan."
        summary = bp.rule_based_summary("Test", transcript, [], known_people, [])
        # Should not match anyone from the word "we"
        assert len(summary['mentioned_people']) == 0

    def test_finds_known_threads(self, brain_dir, sample_threads):
        known_threads = bp.load_thread_names(brain_dir)
        transcript = "The aisp integration is progressing. Deployment planning is on track."
        summary = bp.rule_based_summary("Test", transcript, [], {}, known_threads)
        assert "aisp-integration" in summary['mentioned_threads']
        assert "deployment-planning" in summary['mentioned_threads']

    def test_extracts_action_patterns(self):
        transcript = "We need to finalize the contract. I'll send the updated spec. Should review the PR."
        summary = bp.rule_based_summary("Test", transcript, [], {}, [])
        assert len(summary['potential_actions']) > 0

    def test_extracts_decision_patterns(self):
        transcript = "We decided to use REST. The team agreed on the timeline."
        summary = bp.rule_based_summary("Test", transcript, [], {}, [])
        assert len(summary['potential_decisions']) > 0

    def test_deduplicates_people(self, brain_dir, sample_people):
        known_people = bp.load_people_names(brain_dir)
        # "wei" and "zhang" both map to "Wei Zhang" — should appear once
        transcript = "Wei Zhang presented the update. Wei's approach was solid."
        summary = bp.rule_based_summary("Test", transcript, [], known_people, [])
        wei_count = summary['mentioned_people'].count("Wei Zhang")
        assert wei_count == 1


class TestProcessedMarkers:
    """Test the idempotency marker system."""

    def test_not_processed_initially(self, brain_dir):
        assert not bp.is_processed(brain_dir, "/some/file.json")

    def test_mark_then_check(self, brain_dir):
        bp.mark_processed(brain_dir, "/some/file.json")
        assert bp.is_processed(brain_dir, "/some/file.json")

    def test_different_files_are_independent(self, brain_dir):
        bp.mark_processed(brain_dir, "/file-a.json")
        assert not bp.is_processed(brain_dir, "/file-b.json")


class TestDraftGeneration:
    """Test draft markdown file generation."""

    def test_basic_draft_structure(self):
        summary = {
            'title': 'Test Meeting',
            'word_count': 500,
            'attendees': ['Alice', 'Bob'],
            'mentioned_people': ['Alice'],
            'mentioned_threads': ['my-thread'],
            'potential_actions': ['need to review the doc.'],
            'potential_decisions': ['decided to proceed.'],
            'method': 'rule-based',
        }
        draft = bp.generate_draft_file(summary, "test.json", "/brain")
        assert "# Draft: Test Meeting" in draft
        assert "Alice, Bob" in draft
        assert "Alice" in draft
        assert "[[my-thread]]" in draft
        assert "need to review the doc." in draft
        assert "decided to proceed." in draft
        assert "rule-based" in draft

    def test_empty_sections_omitted(self):
        summary = {
            'title': 'Empty Meeting',
            'word_count': 100,
            'attendees': [],
            'mentioned_people': [],
            'mentioned_threads': [],
            'potential_actions': [],
            'potential_decisions': [],
            'method': 'rule-based',
        }
        draft = bp.generate_draft_file(summary, "test.json", "/brain")
        assert "People Mentioned" not in draft
        assert "Related Threads" not in draft
        assert "Potential Action Items" not in draft
        assert "Potential Decisions" not in draft


class TestEndToEnd:
    """Test full snapshot processing pipeline."""

    def test_processes_transcript(self, brain_dir, sample_people, sample_threads, sample_transcript):
        known_people = bp.load_people_names(brain_dir)
        known_threads = bp.load_thread_names(brain_dir)
        result = bp.process_snapshot(
            sample_transcript, brain_dir, known_people, known_threads
        )
        assert result is not None
        assert result.endswith('.md')
        # Check draft was written
        draft_path = os.path.join(brain_dir, 'inbox', 'drafts', result)
        assert os.path.exists(draft_path)
        content = open(draft_path).read()
        assert "Weekly Sync with Wei" in content

    def test_skips_short_transcripts(self, brain_dir):
        # Create a transcript with very few words
        short_snapshot = {
            "title": "Quick Chat",
            "created_at": "2026-01-20T10:00:00Z",
            "transcript": [{"text": "Hi. Bye."}],
        }
        path = os.path.join(brain_dir, "inbox", "granola", "short.json")
        with open(path, 'w') as f:
            json.dump(short_snapshot, f)

        result = bp.process_snapshot(path, brain_dir, {}, [])
        assert result is None

    def test_scan_processes_all(self, brain_dir, sample_people, sample_threads, sample_transcript):
        count = bp.scan_and_process(brain_dir)
        assert count == 1
        # Running again should process 0 (idempotent)
        count2 = bp.scan_and_process(brain_dir)
        assert count2 == 0

    def test_scan_empty_inbox(self, brain_dir):
        count = bp.scan_and_process(brain_dir)
        assert count == 0
