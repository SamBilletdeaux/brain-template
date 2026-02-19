"""Tests for scripts/generate-prep.py"""
import os
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

import importlib
gp = importlib.import_module('generate-prep')


class TestNameExpansion:
    """Test expand_name_variants for first/last name matching."""

    def test_full_name_variant(self):
        variants = gp.expand_name_variants(["Wei Zhang"])
        assert "wei zhang" in variants
        assert variants["wei zhang"] == "Wei Zhang"

    def test_first_name_variant(self):
        variants = gp.expand_name_variants(["Simone Cirillo"])
        assert "simone" in variants
        assert variants["simone"] == "Simone Cirillo"

    def test_last_name_variant(self):
        variants = gp.expand_name_variants(["Simone Cirillo"])
        assert "cirillo" in variants

    def test_single_name(self):
        variants = gp.expand_name_variants(["Alice"])
        assert "alice" in variants
        # Single name should not produce last name variant
        assert len(variants) == 1

    def test_empty_names_skipped(self):
        variants = gp.expand_name_variants(["", "  ", "Alice"])
        assert "alice" in variants
        assert len([k for k in variants if k.strip()]) == 1


class TestPeopleLookup:
    """Test people file matching."""

    def test_finds_people_by_slug(self, brain_dir, sample_people):
        lookup = gp.find_people_files(brain_dir)
        assert "wei-zhang" in lookup
        assert "simone-cirillo" in lookup

    def test_finds_people_by_first_name(self, brain_dir, sample_people):
        lookup = gp.find_people_files(brain_dir)
        assert "wei" in lookup
        assert "simone" in lookup

    def test_skips_short_fragments(self, brain_dir, sample_people):
        lookup = gp.find_people_files(brain_dir)
        # No 1-2 character keys
        for key in lookup:
            assert len(key) > 2

    def test_match_attendee_by_full_name(self, brain_dir, sample_people):
        lookup = gp.find_people_files(brain_dir)
        attendee = {"name": "Wei Zhang", "email": "wei@example.com"}
        result = gp.match_attendee_to_person(attendee, lookup)
        assert result is not None
        assert "wei-zhang.md" in result

    def test_match_attendee_by_first_name(self, brain_dir, sample_people):
        lookup = gp.find_people_files(brain_dir)
        attendee = {"name": "Wei", "email": "wei@example.com"}
        result = gp.match_attendee_to_person(attendee, lookup)
        assert result is not None


class TestThreadMatching:
    """Test finding threads relevant to attendees."""

    def test_finds_threads_by_first_name(self, brain_dir, sample_people, sample_threads):
        threads = gp.find_relevant_threads(brain_dir, ["Wei Zhang"])
        thread_names = [t['name'] for t in threads]
        assert "aisp-integration" in thread_names

    def test_finds_threads_by_multiple_attendees(self, brain_dir, sample_people, sample_threads):
        threads = gp.find_relevant_threads(brain_dir, ["Wei Zhang", "Simone Cirillo"])
        thread_names = [t['name'] for t in threads]
        assert "aisp-integration" in thread_names
        assert "deployment-planning" in thread_names

    def test_no_match_for_unknown_person(self, brain_dir, sample_people, sample_threads):
        threads = gp.find_relevant_threads(brain_dir, ["Nobody Known"])
        assert len(threads) == 0


class TestCommitmentMatching:
    """Test finding commitments relevant to attendees."""

    def test_finds_commitments_by_name(self, brain_dir, sample_commitments):
        commits = gp.find_relevant_commitments(brain_dir, ["Wei Zhang"])
        assert any("Wei" in c for c in commits)

    def test_finds_commitments_by_first_name(self, brain_dir, sample_commitments):
        commits = gp.find_relevant_commitments(brain_dir, ["Simone Cirillo"])
        assert any("Simone" in c for c in commits)


class TestInferAttendeesFromTitle:
    """Test attendee inference from meeting titles."""

    def test_infers_from_title(self, brain_dir, sample_people):
        lookup = gp.find_people_files(brain_dir)
        attendees = gp.infer_attendees_from_title("1:1 with Wei", lookup)
        assert len(attendees) >= 1
        assert any("Wei" in a['name'] for a in attendees)

    def test_no_match_returns_empty(self, brain_dir, sample_people):
        lookup = gp.find_people_files(brain_dir)
        attendees = gp.infer_attendees_from_title("Team standup", lookup)
        assert len(attendees) == 0

    def test_deduplicates_matches(self, brain_dir, sample_people):
        lookup = gp.find_people_files(brain_dir)
        # Both "wei" and "zhang" map to same person
        attendees = gp.infer_attendees_from_title("Chat with Wei Zhang", lookup)
        names = [a['name'] for a in attendees]
        # Should have exactly 1, not 2
        assert len(names) == 1


class TestPrepGeneration:
    """Test full prep packet generation."""

    def test_generates_valid_markdown(self, brain_dir, sample_people, sample_threads, sample_commitments):
        lookup = gp.find_people_files(brain_dir)
        meeting = {
            "title": "Weekly Sync with Wei",
            "start": "2026-01-20T10:00:00-08:00",
            "attendees": [{"name": "Wei Zhang", "email": "wei@example.com"}],
        }
        prep = gp.generate_prep(meeting, brain_dir, lookup)
        assert "# Meeting Prep:" in prep
        assert "Wei Zhang" in prep
        assert "Relevant Threads" in prep or "Attendee Context" in prep
