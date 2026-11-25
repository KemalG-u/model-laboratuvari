> 🚧 **Status: active development.** It works for the author; interfaces may change.

# Model Laboratory — SQL schema and speaker-leakage checker

This is a technical candidate for schema and speaker-isolation validation. It is not model training, audio processing, or a real dataset. Phase 0 research decisions are not measured performance or experimental results.

## Contents and rights

- `schema/laboratory.sql`: copy of the schema from the user's local Model Laboratory project.
- `speaker_split.py`: newly written candidate validator; `tests/test_speaker_split.py`: synthetic cases using the actual schema in memory.
- `README.md`: Turkish documentation; `MANIFEST.sha256`: complete file allowlist and SHA256 for all files except itself. The manifest lists itself without a self-hash.

The user authorized publication of their original source code and documentation; those contributions are covered by the [MIT License](LICENSE). `KemalG-u` is the owner's public pseudonym. This permission does not extend to third-party rights, whose scope has not been independently verified. Python and SQLite runtimes are distributed separately under their own licenses. References: [Python sqlite3](https://docs.python.org/3/library/sqlite3.html); [SQLite CREATE TABLE](https://www.sqlite.org/lang_createtable.html); [SQLite foreign keys](https://www.sqlite.org/foreignkeys.html). These are references, not bundled code. Research files, real audio/data, existing databases, secrets and session files are outside this candidate.

## Quick start

To try the validator on synthetic speakers, save the code below as `quick_start.py` in the repository folder and run `python quick_start.py` (standard library only). It builds the schema in memory, puts one speaker in two splits and prints the leak:

```python
import sqlite3
from speaker_split import find_speaker_leaks

db = sqlite3.connect(":memory:")
db.executescript(open("schema/laboratory.sql", encoding="utf-8").read())
db.executemany(
    "INSERT INTO split_groups (group_key, speaker_id, session_id, source_group_id, split_name,"
    " assignment_rule_version, assigned_at) VALUES (?, ?, ?, 'src', ?, 'v1', '2000-01-01T00:00:00Z')",
    [("g1", "spk-a", "s1", "train"), ("g2", "spk-a", "s2", "test"), ("g3", "spk-b", "s1", "train")],
)
print(find_speaker_leaks(db))  # {'spk-a': ['test', 'train']}
```

## Validation and limits

`find_speaker_leaks(connection)` reads both `samples` and `split_groups` and returns exact speaker IDs assigned to multiple train/development/test splits, with sorted splits. Its output may be sensitive; do not share it. `require_speaker_isolation(connection)` raises a `ValueError` without IDs for such leakage. Blank or whitespace-only IDs and unknown splits fail closed. Quarantined and NULL split rows are excluded. IDs are compared exactly without trimming or case folding; different IDs for the same person are not detected. An empty database passing does not mean a dataset is ready.

The SQL `uq_split_group_tuple` only makes the speaker/session/source tuple unique within `split_groups`; it does not prevent the same speaker crossing splits in different sessions. Triggers block UPDATE of sample identity fields and reference versions, but do not block reference DELETE. SQL constrains split names and enforces foreign keys when enabled on the connection; enable foreign keys on each new connection. `split_locked` alone does not enforce a lock. The schema does not guarantee agreement between the two tables, independent speaker/session/source isolation, duplicate-audio detection or real permission.

The validator is not a SQL trigger and protects nothing unless called. It does not independently check sessions, source groups, repeated audio under different IDs, permissions or human identity, nor prevent training on quarantined/unassigned records. The consuming pipeline must call it immediately before use on an authorized consistent read snapshot and separately prevent later changes invalidating the result. The caller opens the connection; the validator does not write.

## Tests and pending work

Twelve synthetic tests passed for this candidate. This result applies to that run; the number of tests and their results may change over time. To rerun from this directory using only the standard library:

```bash
PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s tests -v
```

In Windows PowerShell set `$env:PYTHONDONTWRITEBYTECODE='1'` instead. Tests open SQLite in memory only and use no audio. Real-data validation and performance tests have not been performed; synthetic tests do not substitute for them. 
