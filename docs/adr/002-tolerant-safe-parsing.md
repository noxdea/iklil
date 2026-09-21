# ADR 002: Tolerant parsing with diagnostics and fail-closed XML

- Status: Accepted
- Date: 2026-09-21
- Author: Yudai Takada

## Decision

Iklil repairs common feed damage, returns readable fields when possible, and
records warnings in `Feed#diagnostics`. DTDs and entity declarations are
removed before REXML parses untrusted input.

## Context

Public feeds frequently contain undeclared entities, invalid dates, truncated
downloads, or inconsistent encoding. A single bad item should not hide every
other item. XML external entities are not needed for feeds and create an
unacceptable local-file and network access risk.

## Consequences

Applications must inspect diagnostics when they need strict ingestion. Iklil
never resolves external entities and never performs network requests.
