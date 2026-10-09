# Agent-History

**Switch tools, keep the whole workflow.**

Agent-History is an open-source project exploring how to preserve and transfer complete AI-agent work histories between tools. It aims to keep conversations, tool calls, results, and file changes linked so another agent can continue work with traceable context instead of relying on a lossy summary.

> Early-stage project. The format and supported agent sources are not finalized yet.

## Problem

When switching AI coding agents, useful context is often trapped in tool-specific workspaces. A short handoff summary is easy to read, but can omit decisions, execution details, and why a change was made. Replaying raw history without structure is difficult to search and may exceed an agent's context window.

## Direction

- Preserve source events and their order instead of replacing them with a summary.
- Link messages, tool calls, results, and file changes into a traceable workflow.
- Let a receiving agent inspect the history progressively, loading relevant context as needed.
- Add source and destination adapters for native formats where supported.
- Keep export local and read-only by default.
- Require explicit review before replaying any recorded operation.

## Initial Scope

The first milestone is a local, read-only exporter for one agent source. It should discover candidate history locations, let the user select records, and export a portable handoff package containing a manifest and structured event stream. Source discovery, event schemas, and native import targets will be documented before adding more adapters.

The exported package is data, not an executable. Recorded commands must never run automatically when a package is opened.

## Design Questions

- Which agent history source should be supported first?
- Which event fields are needed to preserve provenance and links between actions?
- Which target agents can import a native conversation, and which can only read a workspace handoff file?
- How should secrets, private messages, and file snapshots be detected and excluded?
- How can large histories be navigated without silently discarding details?

## Status

Project setup and requirements discovery. No history collector or export format is implemented yet.

## Contributing

Early feedback is welcome, especially real examples of agent handoff failures, history formats, and native import workflows. Do not submit private conversations, credentials, or proprietary workspace data in issues.

## License

No license has been selected yet. Until a license is added, all rights are reserved by default; do not assume the code is available for reuse.