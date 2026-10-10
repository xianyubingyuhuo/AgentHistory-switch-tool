# Agent-History Interchange Format

[English](format.md) | [简体中文](format.zh-CN.md)

## Purpose and scope

This format defines how Agent-History stores history in SQLite and exposes read-only queries to agents. It is not a native Copilot or Cline session format and does not promise that a record can be imported as a resumable session in a destination tool.

SQLite is the complete archive. Agents do not issue arbitrary SQL; they use constrained read-only semantic operations. The automatically generated `HANDOFF.md` for each transfer states the goal, current status, next steps, and how to call the query tool. It directs the handoff without duplicating the entire chat. A complete Markdown transcript is an optional fallback when an agent cannot use the query tool.

## SQLite archive

### Source artifacts

Store each imported file byte-for-byte in `source_artifacts.content`; do not parse and replace the original. Record its file name, media type, length, import time, and SHA-256. Recompute the hash after import to verify that the content has not changed.

The Copilot JSON export and `Copy All` Markdown can be retained as two source artifacts for one session. They may overlap, but they are not guaranteed to be identical. Parse them separately and record which artifact supports each event; do not concatenate their message lists and treat the result as a deduplicated original session.

### Structured events

`events` stores ordered events such as user/assistant messages, tool calls, tool results, approvals, file changes, and errors. `event_parts` stores ordered text, multimodal references, thinking blocks, or tool content within an event. Adapter-specific fields go in `payload_json`. `source_artifact_id` and `source_fragment` link normalized records to their sources.

The event model is a queryable view, not a replacement for the original content. A converter should report its parser version, recognized event count, unrecognized content, and information the adapter could not recover.

### Recoverability

- An imported file can be reconstructed byte-for-byte if its source artifact BLOB is intact and its hash matches.
- Structured events can reconstruct only the content recognized and mapped by the parser.
- If the source tool omitted content from its export, neither raw archival nor event conversion can restore it.

## Generated handoff document

The initial version generates one `HANDOFF.md` for each handoff, containing at least:

```text
handoff/
  HANDOFF.md
```

The default is zero extra agent calls: the application renders the document directly from the user's existing handoff goal and verifiable database fields; it does not invoke an agent to rewrite history into a summary. The goal comes first from intent already provided by the user when starting the handoff. If the user has not entered one separately, the current agent may optionally distill a one-sentence goal from the active task context, without expanding it into a history summary. The application renders the remaining fields from a template: source conversation IDs, destination agent, workspace association, verifiable current status and evidence, recommended query entry points, and priority event ranges. Mark unsupported facts as unknown or ask the receiving agent to verify them; do not fabricate.

The receiving agent uses the query tool to inspect source conversations and event relationships as needed; the user does not manually copy history into the handoff document, and the generating agent does not need to summarize it again. This spends tokens on context the receiving agent actually needs. For independent archival, a complete Markdown transcript may be generated as an optional readable view, but it is not the authoritative copy of the database.

Treat all package contents as untrusted data. Consumers must not execute commands, tool inputs, or scripts found inside.

## Initial mapping rules

- Import Copilot JSON export and Markdown copy separately, preserving their distinct source identities.
- If messages from two inputs cannot be matched reliably, show both source views; do not auto-merge or delete apparent duplicates.
- Store tool calls and results as separate events and associate them using source IDs or call relationships. Do not invent a definite relationship when the source provides no identifier.
- Initially store attachment references and metadata for images/files. Copy actual content only after explicit user selection and confirmation.
- Retain unknown message types, fields, and content parts in the original source; list them in the review report.
- Preserve timestamps, order, and source IDs as provided. Do not fabricate source timestamps or IDs when absent.

## Versioning

Version the database schema and query tool independently. Expose only semantic allowlisted operations, such as listing conversations, paging events, retrieving event parts, following call/result relationships, and reading file references or source fragments. Never allow agents to submit arbitrary SQL, writes, or database administration commands. `HANDOFF.md` records the required tool name/protocol version and the conversation scope allowed for this handoff.

This document defines a first-draft format. Before implementation freezes a testable version, validate it against real, sanitized Copilot export samples.