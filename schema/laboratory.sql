PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS source_registry (
  source_id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  url TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL,
  checked_at TEXT NOT NULL,
  local_evidence TEXT,
  supports TEXT NOT NULL,
  status TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS candidate_models (
  candidate_id TEXT PRIMARY KEY,
  family TEXT NOT NULL,
  model TEXT NOT NULL,
  revision TEXT NOT NULL,
  parameters INTEGER NOT NULL,
  architecture TEXT NOT NULL,
  purpose TEXT NOT NULL,
  license TEXT NOT NULL,
  decision TEXT NOT NULL,
  confidence TEXT NOT NULL,
  record_json TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS metric_catalog (
  metric_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  stage TEXT NOT NULL,
  direction TEXT NOT NULL CHECK(direction IN ('lower','higher')),
  rule TEXT NOT NULL,
  uncertainty TEXT NOT NULL,
  record_json TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS tracking_tools (
  tool TEXT PRIMARY KEY,
  default_rank INTEGER NOT NULL,
  decision TEXT NOT NULL,
  record_json TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS evidence_gates (
  gate_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  pass_rule TEXT NOT NULL,
  failure_action TEXT NOT NULL,
  status TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS decision_log (
  decision_id TEXT PRIMARY KEY,
  decided_at TEXT NOT NULL,
  question TEXT NOT NULL,
  decision TEXT NOT NULL,
  confidence TEXT NOT NULL,
  record_json TEXT NOT NULL
);

-- Aşağıdaki tablolar gelecekteki deney verisi içindir; Faz 0 bunları boş bırakır.
CREATE TABLE IF NOT EXISTS samples (
  sample_id TEXT PRIMARY KEY,
  sample_version INTEGER NOT NULL DEFAULT 1,
  provenance_uri TEXT NOT NULL,
  provenance_kind TEXT NOT NULL,
  speaker_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  source_group_id TEXT NOT NULL,
  audio_sha256 TEXT NOT NULL CHECK(length(audio_sha256)=64),
  duration_ms INTEGER NOT NULL CHECK(duration_ms>=0),
  sample_rate_hz INTEGER NOT NULL,
  channels INTEGER NOT NULL CHECK(channels>=1),
  noise_state_json TEXT NOT NULL DEFAULT '[]',
  reference_state TEXT NOT NULL CHECK(reference_state IN ('none','silver','gold')),
  permission_class TEXT NOT NULL CHECK(permission_class IN ('research_only','development','evaluation','training','distribution')),
  permission_record_id TEXT NOT NULL,
  retention_until TEXT,
  split_name TEXT CHECK(split_name IN ('train','development','test','quarantine')),
  split_locked INTEGER NOT NULL DEFAULT 0 CHECK(split_locked IN (0,1)),
  created_at TEXT NOT NULL,
  withdrawn_at TEXT
);

CREATE TABLE IF NOT EXISTS reference_versions (
  reference_version_id TEXT PRIMARY KEY,
  sample_id TEXT NOT NULL REFERENCES samples(sample_id),
  reference_text TEXT NOT NULL,
  reference_sha256 TEXT NOT NULL CHECK(length(reference_sha256)=64),
  grade TEXT NOT NULL CHECK(grade IN ('silver','gold')),
  verifier_id TEXT NOT NULL,
  verification_method TEXT NOT NULL,
  based_on_engine_output INTEGER NOT NULL DEFAULT 0 CHECK(based_on_engine_output IN (0,1)),
  supersedes_id TEXT REFERENCES reference_versions(reference_version_id),
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sample_tags (
  sample_id TEXT NOT NULL REFERENCES samples(sample_id),
  tag_type TEXT NOT NULL CHECK(tag_type IN ('proper_name','number','unit','question','negation','punctuation','code_switch','long_speech','noise','silence','literal')),
  tag_value TEXT NOT NULL,
  span_start INTEGER,
  span_end INTEGER,
  PRIMARY KEY(sample_id, tag_type, tag_value, span_start, span_end)
);

CREATE TABLE IF NOT EXISTS split_groups (
  group_key TEXT PRIMARY KEY,
  speaker_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  source_group_id TEXT NOT NULL,
  split_name TEXT NOT NULL CHECK(split_name IN ('train','development','test','quarantine')),
  assignment_rule_version TEXT NOT NULL,
  assigned_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS runs (
  run_id TEXT PRIMARY KEY,
  experiment_id TEXT NOT NULL,
  candidate_id TEXT NOT NULL REFERENCES candidate_models(candidate_id),
  parent_run_id TEXT REFERENCES runs(run_id),
  run_kind TEXT NOT NULL CHECK(run_kind IN ('baseline','control','train','evaluation','export','shadow')),
  code_sha256 TEXT NOT NULL,
  data_manifest_sha256 TEXT NOT NULL,
  model_input_sha256 TEXT NOT NULL,
  config_sha256 TEXT NOT NULL,
  hardware_json TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('planned','running','completed','failed','blocked')),
  started_at TEXT,
  ended_at TEXT,
  cost_json TEXT NOT NULL DEFAULT '{}',
  notes TEXT
);

CREATE TABLE IF NOT EXISTS stage_outputs (
  run_id TEXT NOT NULL REFERENCES runs(run_id),
  sample_id TEXT NOT NULL REFERENCES samples(sample_id),
  stage TEXT NOT NULL CHECK(stage IN ('capture','vad','raw_asr','candidate_correction','accepted_correction','delivered_text','human_reference')),
  output_text TEXT,
  output_sha256 TEXT,
  start_ms INTEGER,
  end_ms INTEGER,
  confidence_json TEXT,
  artifact_uri TEXT,
  PRIMARY KEY(run_id, sample_id, stage)
);

CREATE TABLE IF NOT EXISTS metric_values (
  run_id TEXT NOT NULL REFERENCES runs(run_id),
  metric_id TEXT NOT NULL REFERENCES metric_catalog(metric_id),
  scope TEXT NOT NULL,
  value REAL,
  numerator REAL,
  denominator REAL,
  n_samples INTEGER NOT NULL,
  ci_low REAL,
  ci_high REAL,
  method TEXT,
  PRIMARY KEY(run_id, metric_id, scope)
);

CREATE TABLE IF NOT EXISTS correction_events (
  correction_event_id TEXT PRIMARY KEY,
  sample_id TEXT NOT NULL REFERENCES samples(sample_id),
  from_stage TEXT NOT NULL,
  to_stage TEXT NOT NULL,
  old_text TEXT NOT NULL,
  new_text TEXT NOT NULL,
  reason_code TEXT NOT NULL,
  actor_type TEXT NOT NULL CHECK(actor_type IN ('human','rule','model','system')),
  rule_or_model_revision TEXT,
  accepted INTEGER CHECK(accepted IN (0,1)),
  created_at TEXT NOT NULL
);

CREATE TRIGGER IF NOT EXISTS prevent_sample_identity_update
BEFORE UPDATE OF sample_id, audio_sha256, speaker_id, session_id, source_group_id ON samples
BEGIN
  SELECT RAISE(ABORT, 'immutable sample identity');
END;

CREATE TRIGGER IF NOT EXISTS prevent_reference_overwrite
BEFORE UPDATE ON reference_versions
BEGIN
  SELECT RAISE(ABORT, 'reference versions are append-only');
END;

CREATE UNIQUE INDEX IF NOT EXISTS uq_split_group_tuple
ON split_groups(speaker_id, session_id, source_group_id);
CREATE INDEX IF NOT EXISTS ix_samples_split ON samples(split_name);
CREATE INDEX IF NOT EXISTS ix_samples_group ON samples(speaker_id,session_id,source_group_id);
CREATE INDEX IF NOT EXISTS ix_stage_outputs_sample ON stage_outputs(sample_id,stage);
