"""Check speaker isolation in the laboratory schema; no database is opened here."""

from collections import defaultdict
import sqlite3

EVALUATION_SPLITS = frozenset({"train", "development", "test"})


def find_speaker_leaks(connection: sqlite3.Connection) -> dict[str, list[str]]:
    """Return speakers assigned to multiple evaluation splits across both tables.

    Quarantine and unassigned samples do not participate. Empty/whitespace-only
    speaker IDs fail closed; identifiers otherwise compare exactly, without
    guessing whether differently spelled IDs refer to the same person.
    """
    assignments: dict[str, set[str]] = defaultdict(set)
    for table in ("samples", "split_groups"):
        for speaker, split in connection.execute(
            f"SELECT speaker_id, split_name FROM {table}"
        ):
            if not isinstance(speaker, str) or not speaker.strip():
                raise ValueError(f"{table}: missing speaker_id")
            if split is None or split == "quarantine":
                continue
            if split not in EVALUATION_SPLITS:
                raise ValueError(f"{table}: unknown split_name")
            assignments[speaker].add(split)
    return {
        speaker: sorted(splits)
        for speaker, splits in sorted(assignments.items())
        if len(splits) > 1
    }


def require_speaker_isolation(connection: sqlite3.Connection) -> None:
    """Raise on leakage; avoid putting speaker IDs in exception messages."""
    if find_speaker_leaks(connection):
        raise ValueError("speaker isolation violated across evaluation splits")
