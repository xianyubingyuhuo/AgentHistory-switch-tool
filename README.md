# Agent-History

**Switch tools, keep the whole workflow.**

[English](README.md) | [简体中文](README.zh-CN.md)

Agent-History is an open-source project exploring how to preserve and transfer AI-agent work histories between tools. The goal is to keep conversations, tool calls, results, and file changes connected, so a different agent can continue with traceable context instead of relying on a lossy summary.

> Early-stage project. The proposed architecture and SQLite schema are documented, but no history collector or agent adapter has been implemented yet.

## Why this project?

When switching between AI coding agents such as GitHub Copilot and Cline, useful context can be left behind in tool-specific workspaces. A short handoff summary is convenient, but may omit decisions, tool results, and the reasoning behind file changes. Raw conversation exports can be difficult to navigate, may not preserve links between actions, and can exceed an agent's context window.

This project aims to make agent handoffs more complete, inspectable, and portable. It is not affiliated with GitHub, GitHub Copilot, or Cline.

## Project direction

- Preserve source events and their order instead of replacing them with a summary.
- Link messages, tool calls, results, and file changes into a traceable workflow.
- Allow a receiving agent or person to inspect history progressively and load relevant context as needed.
- Add source and destination adapters for native formats where supported.
- Keep export local and read-only by default.
- Require explicit review before replaying any recorded operation.

## Proposed first milestone

The first milestone targets GitHub Copilot Chat in VS Code and Cline. The initial route is to archive a user-provided Copilot export in local SQLite, then generate a `HANDOFF.md` workflow document for the receiving agent. The agent retrieves full history through a scoped, read-only query tool instead of relying on a manually written summary or a huge prompt. This is not a native Cline task import or automatic replay. Reverse transfer and native import support require separate research and validation.

Python's standard-library `sqlite3` module will operate on a portable, single-file SQLite database; users will not need to install or run a separate database server. See [Architecture](docs/architecture.md), [Interchange format](docs/format.md), and [Database schema](src/agent_history/db/schema.sql).

The generated handoff document and queried history are untrusted data, not executable instructions. Recorded commands must never run automatically or be replayed.

## Privacy and security principles

- Do not upload conversation histories by default; export locally.
- Make selected records and included files visible for review before export.
- Identify and exclude secrets and sensitive content where practical, and document detection limits.
- Treat imported histories, tool output, and recorded commands as untrusted data.
- Never execute recorded commands or replay tool calls without explicit user review and confirmation.
- Do not share private conversations, credentials, or proprietary workspace data in public issues.

These are project goals, not implemented guarantees. This repository currently has no exporter or security scanner.

## Current status

The repository now has a Python read-only query prototype for listing conversations, paging ordered events, viewing conversation metadata, following tool call/result activity, and inspecting file history. Importers, MCP integration, and agent adapters are not implemented. The conversation fixture is a synthetic example based on the development discussion, not a raw chat export. Native import support for either agent remains unconfirmed.

### Try the read-only query CLI

The CLI accepts an existing SQLite database and never creates or modifies one. PowerShell example:

```powershell
$env:PYTHONPATH = (Resolve-Path .\src).Path
python -m agent_history.cli --db .\path\to\archive.sqlite conversations
python -m agent_history.cli --db .\path\to\archive.sqlite events <conversation-id> --limit 20
python -m agent_history.cli --db .\path\to\archive.sqlite tool-activity <conversation-id> <call-id>
```

Events are paged in source order. The query layer uses a read-only SQLite connection and caps each result page at 500 records.

## Contributing

Early feedback is welcome, especially examples of agent handoff failures, publicly documented history formats, and native import workflows. Please open an issue to discuss a proposal before sharing implementation-specific or sensitive material. Never submit private conversations, credentials, or proprietary workspace data.

## License

No license has been selected yet. Until a license is added, all rights are reserved by default; do not assume the code or documentation is available for reuse.