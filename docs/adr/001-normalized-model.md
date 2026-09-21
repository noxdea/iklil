# ADR 001: Normalize feed formats into one model

- Status: Accepted
- Date: 2026-09-21
- Author: Yudai Takada

## Decision

RSS, Atom, and JSON Feed are parsed into immutable `Feed`, `Entry`, and
`Enclosure` values. Format-specific fields remain in `Entry#extensions`.

## Context

The reader needs to display and sort entries without knowing which wire format
produced them. Keeping format branches in the application would duplicate URL,
date, and content handling.

## Consequences

Consumers get one stable API. New namespace fields are not lost, but consumers
must explicitly opt into them. The parser does not perform HTML sanitization.
