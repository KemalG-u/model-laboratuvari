"""Synthetic examples only. Never opens an existing database or any audio."""

from pathlib import Path
import sqlite3
import unittest

from speaker_split import find_speaker_leaks, require_speaker_isolation

SCHEMA = Path(__file__).resolve().parents[1] / "schema" / "laboratory.sql"


class SpeakerIsolationTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.addCleanup(self.db.close)
        self.db.executescript(SCHEMA.read_text(encoding="utf-8"))

    def sample(self, sample_id, speaker, session, split):
        self.db.execute(
            """INSERT INTO samples
               (sample_id, provenance_uri, provenance_kind, speaker_id, session_id,
                source_group_id, audio_sha256, duration_ms, sample_rate_hz, channels,
                reference_state, permission_class, permission_record_id, split_name,
                created_at)
               VALUES (?, 'synthetic:none', 'synthetic', ?, ?, 'synthetic-source',
                       ?, 0, 16000, 1, 'none', 'research_only', 'synthetic-permission',
                       ?, '2000-01-01T00:00:00Z')""",
            (sample_id, speaker, session, "0" * 64, split),
        )

    def group(self, key, speaker, session, split):
        self.db.execute(
            """INSERT INTO split_groups
               (group_key, speaker_id, session_id, source_group_id, split_name,
                assignment_rule_version, assigned_at)
               VALUES (?, ?, ?, 'synthetic-source', ?, 'synthetic-v1',
                       '2000-01-01T00:00:00Z')""",
            (key, speaker, session, split),
        )

    def test_different_speakers_and_same_speaker_same_split_are_allowed(self):
        self.sample('a', 'speaker-a', 'session-a', 'train')
        self.sample('b', 'speaker-a', 'session-b', 'train')
        self.sample('c', 'speaker-b', 'session-c', 'test')
        self.group('g-a', 'speaker-a', 'session-a', 'train')
        self.assertEqual(find_speaker_leaks(self.db), {})
        require_speaker_isolation(self.db)

    def test_schema_accepts_different_sessions_but_validator_detects_leak(self):
        self.group('g-a', 'speaker-a', 'session-a', 'train')
        self.group('g-b', 'speaker-a', 'session-b', 'test')
        self.assertEqual(find_speaker_leaks(self.db), {'speaker-a': ['test', 'train']})
        with self.assertRaisesRegex(ValueError, 'speaker isolation violated'):
            require_speaker_isolation(self.db)

    def test_sample_and_group_conflict_is_detected(self):
        self.sample('a', 'speaker-a', 'session-a', 'development')
        self.group('g-b', 'speaker-a', 'session-b', 'test')
        self.assertEqual(find_speaker_leaks(self.db), {'speaker-a': ['development', 'test']})

    def test_quarantine_and_unassigned_are_excluded(self):
        self.sample('a', 'speaker-a', 'session-a', 'train')
        self.sample('b', 'speaker-a', 'session-b', None)
        self.group('g-c', 'speaker-a', 'session-c', 'quarantine')
        self.assertEqual(find_speaker_leaks(self.db), {})

    def test_blank_speaker_fails_closed_even_when_quarantined(self):
        self.group('g-a', '  ', 'session-a', 'quarantine')
        with self.assertRaisesRegex(ValueError, 'missing speaker_id'):
            require_speaker_isolation(self.db)


    def test_samples_alone_can_leak_and_error_hides_identifier(self):
        self.sample('a', 'sensitive-id', 'one', 'train')
        self.sample('b', 'sensitive-id', 'two', 'test')
        with self.assertRaises(ValueError) as error:
            require_speaker_isolation(self.db)
        self.assertNotIn('sensitive-id', str(error.exception))
        self.assertEqual(find_speaker_leaks(self.db), {'sensitive-id': ['test', 'train']})

    def test_all_three_splits_are_reported_in_sorted_order(self):
        for i, split in enumerate(('train', 'test', 'development')):
            self.sample(str(i), 'speaker-a', str(i), split)
        self.assertEqual(find_speaker_leaks(self.db),
                         {'speaker-a': ['development', 'test', 'train']})

    def test_ids_are_exact_not_casefolded_or_trimmed(self):
        self.sample('a', 'speaker-a', 'one', 'train')
        self.sample('b', 'Speaker-a', 'two', 'test')
        self.sample('c', 'speaker-a ', 'three', 'test')
        self.assertEqual(find_speaker_leaks(self.db), {})

    def test_unknown_split_fails_closed_if_constraints_were_bypassed(self):
        self.db.execute('PRAGMA ignore_check_constraints = ON')
        self.sample('a', 'speaker-a', 'one', 'invalid')
        with self.assertRaisesRegex(ValueError, 'unknown split_name'):
            find_speaker_leaks(self.db)

    def test_missing_table_is_not_silently_accepted(self):
        self.db.execute('DROP TABLE split_groups')
        with self.assertRaises(sqlite3.OperationalError):
            require_speaker_isolation(self.db)

    def test_schema_unique_tuple_and_sample_identity_update(self):
        self.group('one', 'speaker-a', 'session-a', 'train')
        with self.assertRaises(sqlite3.IntegrityError):
            self.group('two', 'speaker-a', 'session-a', 'test')
        self.sample('a', 'speaker-a', 'session-a', 'train')
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE samples SET speaker_id = 'other' WHERE sample_id = 'a'")

    def test_empty_database_passes_but_is_not_a_readiness_check(self):
        self.assertEqual(find_speaker_leaks(self.db), {})
        require_speaker_isolation(self.db)

if __name__ == '__main__':
    unittest.main()
