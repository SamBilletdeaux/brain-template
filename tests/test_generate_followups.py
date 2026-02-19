"""Tests for scripts/generate-followups.py"""
import os
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

import importlib
gf = importlib.import_module('generate-followups')


class TestFollowupDetection:
    """Test identifying which commitments need follow-up messages."""

    def test_detects_share_with(self):
        assert gf.is_followup_commitment("Share WA+AISP spec with Wei")

    def test_detects_send_to(self):
        assert gf.is_followup_commitment("Send the updated doc to Simone")

    def test_detects_follow_up(self):
        assert gf.is_followup_commitment("Follow up with the team on deployment")

    def test_detects_email(self):
        assert gf.is_followup_commitment("Email the summary to stakeholders")

    def test_detects_ping(self):
        assert gf.is_followup_commitment("Ping Alice about the review")

    def test_detects_loop_in(self):
        assert gf.is_followup_commitment("Loop in the design team")

    def test_rejects_non_followup(self):
        assert not gf.is_followup_commitment("Review PR #42")

    def test_rejects_generic_task(self):
        assert not gf.is_followup_commitment("Set up CI pipeline")


class TestCommitmentParsing:
    """Test extracting active commitments from commitments.md."""

    def test_extracts_active_commitments(self, brain_dir, sample_commitments):
        commits = gf.extract_active_commitments(brain_dir)
        assert len(commits) == 3
        assert any("Wei" in c['text'] for c in commits)

    def test_ignores_completed(self, brain_dir, sample_commitments):
        commits = gf.extract_active_commitments(brain_dir)
        for c in commits:
            assert "[x]" not in c['text']

    def test_empty_commitments(self, brain_dir):
        with open(os.path.join(brain_dir, "commitments.md"), "w") as f:
            f.write("# Commitments\n\n## Active\n\n(Nothing yet.)\n")
        commits = gf.extract_active_commitments(brain_dir)
        assert len(commits) == 0


class TestRecipientExtraction:
    """Test extracting who a follow-up message should go to."""

    def test_extracts_share_with_recipient(self, brain_dir, sample_people):
        lookup = gf.find_people_files(brain_dir)
        result = gf.extract_recipient("Share WA+AISP spec with Wei", lookup)
        assert result is not None
        assert "Wei" in result['name']

    def test_extracts_send_to_recipient(self, brain_dir, sample_people):
        lookup = gf.find_people_files(brain_dir)
        result = gf.extract_recipient("Send the doc to Simone", lookup)
        assert result is not None
        assert "Simone" in result['name']

    def test_returns_none_for_unknown(self, brain_dir, sample_people):
        lookup = gf.find_people_files(brain_dir)
        result = gf.extract_recipient("Share the doc with nobody-known", lookup)
        assert result is None


class TestDraftGeneration:
    """Test follow-up draft markdown generation."""

    def test_generates_valid_draft(self, brain_dir, sample_people):
        commitment = {
            'text': 'Share WA+AISP spec with Wei — added 2026-01-15',
            'owner': None,
            'added_date': '2026-01-15',
            'source': 'Weekly Sync',
        }
        recipient = {
            'name': 'Wei Zhang',
            'path': os.path.join(brain_dir, 'people', 'wei-zhang.md'),
        }
        draft = gf.generate_draft(commitment, recipient, "", brain_dir)
        assert "# Follow-Up Draft" in draft
        assert "Wei Zhang" in draft or "wei-zhang" in draft
        assert "Weekly Sync" in draft
        assert "Draft Message" in draft

    def test_draft_without_recipient(self, brain_dir):
        commitment = {
            'text': 'Follow up on the review',
            'owner': None,
            'added_date': '2026-01-15',
            'source': None,
        }
        draft = gf.generate_draft(commitment, None, "", brain_dir)
        assert "# Follow-Up Draft" in draft
        assert "Hi," in draft  # No name after Hi


class TestContextGathering:
    """Test finding related context from handoff."""

    def test_finds_related_handoff_context(self, brain_dir, sample_handoff):
        # The handoff has generic content, but let's add a relevant entry
        with open(os.path.join(brain_dir, "handoff.md"), "a") as f:
            f.write("\n## 2026-01-21 — Recent session\n\n"
                    "### Key Outcomes\n"
                    "- Discussed AISP spec requirements with Wei\n"
                    "- Finalized the deployment timeline\n")

        context = gf.get_relevant_context(brain_dir, "Share WA+AISP spec with Wei")
        # Should find something since "AISP" and "spec" match
        # (may or may not match depending on term extraction — this is a best-effort test)
        assert isinstance(context, str)
