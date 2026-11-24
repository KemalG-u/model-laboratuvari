# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| latest commit on `main` | yes |
| older | no |

## Reporting a vulnerability

Please do **not** open a public issue for a security problem.

Report it privately with GitHub's private vulnerability reporting: open the repository's **Security** tab and choose **Report a vulnerability** (https://github.com/KemalG-u/model-laboratuvari/security/advisories/new).

Include: affected version, a description, steps to reproduce, and the impact you see. Never include real secrets or personal data in a report; describe where they appear instead.

## What to expect

This is a one-person project maintained on a best-effort basis. The maintainer aims to send an initial response within 14 days of a report. A fix date is not promised; the maintainer will tell you what is planned.

## Scope

In scope: `speaker_split.py` and the SQL schema (for example a way to make the speaker-isolation check report a clean result for leaking data). Out of scope: weaknesses of Python or SQLite, and the documented limits of the check (it is not a SQL trigger and does not verify identity or consent).
