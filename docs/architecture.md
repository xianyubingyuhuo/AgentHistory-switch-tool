# Proposed Architecture

[English](architecture.md) | [简体中文](architecture.zh-CN.md)

## Goal

Provide a local Python application that preserves agent conversation and workflow records in an inspectable, portable form, then creates handoff material another agent can consume. The initial pair is GitHub Copilot Chat in VS Code and Cline.

This is an architecture proposal, not implemented behavior. The project must not depend on undocumented private storage formats as its only way to work.

## Storage choice

Use SQLite as the local database, accessed through Python's standard-library `sqlite3` module. SQLite is embedded: the database is one ordinary file and does not require a separate server or database installation. Keep schema migrations in the repository and enable foreign-key enforcement for every connection.

SQLite is the authoritative local archive. Markdown is not a replacement for the full history; it is an automatically generated handoff workflow document that tells the receiving agent the goal, current state, what to inspect first, and how to query the database through a read-only tool. The user should not have to write a handoff summary, and the entire history is not copied into the prompt.

Archive data in two layers: `source_artifacts` stores each user-provided export as a byte-for-byte BLOB with SHA-256, length, and media type; `events` and `event_parts` store a searchable structured view linked to its source artifact and, where available, source fragments. If a parser does not recognize content, the original artifact remains available. Local retention does not make raw history safe to share; review it separately before export.

## Initial exchange route

1. The user exports a Copilot Chat session using VS Code's `Chat: Export Chat...` command, or copies the session as Markdown.
2. The Copilot importer stores the selected JSON or Markdown file as a raw BLOB in SQLite without modifying VS Code data, and computes a hash to verify that the source bytes remain unchanged. VS Code documentation only promises that the JSON export contains prompts and responses; it does not promise tool calls or thinking blocks. To retain those documented details, also save a `Copy All` Markdown transcript, which is documented to include thinking steps and tool calls.
3. The parser maps recognized messages, content parts, and tool calls to canonical events. Each mapping links back to its source artifact and available source fragment. Unknown fields remain in the original artifact and should also be copied into JSON payloads where practical.
4. The importer assigns a stable Agent-History conversation ID and preserves source agent, source conversation ID, and workspace association.
5. The user reviews import status, parse coverage, file references, and detected sensitive content. Keeping raw data locally does not mean it is automatically safe to share.
6. When the user starts a handoff, the application renders `HANDOFF.md` directly, with no extra agent call by default. It fills in the destination agent, existing handoff intent, project/branch, verifiable current state, suggested history ranges to inspect, and next task. If the user has not provided a separate handoff intent, the current agent may optionally distill a one-sentence goal from the active task context; it does not generate a long history summary. Missing or unsupported facts are marked unknown or for the receiving agent to verify, never fabricated.
7. The receiving agent uses a read-only query tool to retrieve conversation summaries, event ranges, tool calls and results, related files, and source fragments as needed. It can follow relationships progressively; the full history stays in SQLite instead of being preloaded into Markdown.

The handoff document says what to do, where to start, and how to query; the query tool supplies the source records and relationship evidence. Default template rendering incurs no extra agent call or summarization cost. If the destination agent cannot call a local query tool, the application may generate a readable full Markdown transcript as a compatibility fallback, but should not silently degrade to a summary-only handoff.

## Adapter boundaries

### GitHub Copilot Chat in VS Code

The official VS Code documentation describes exporting a chat session to JSON with `Chat: Export Chat...` and says the JSON contains all prompts and responses. It does not promise that JSON includes tool calls, thinking blocks, attachments, edits, or a stable machine-readable schema. The separate `Copy All` Markdown feature is documented to include prompts, responses, thinking steps, and tool calls. These can be complementary inputs, but the importer must handle duplicates, and neither can restore source data that was not exported. The documentation does not describe importing exported JSON as a live session. The extension Chat Participant API builds chat participants; it is not an API for reading Copilot's persisted sessions or importing an old transcript.

Therefore, the first adapter should be a user-selected file importer, not a reader/writer for VS Code's private databases. A JSON export parser must be tested against real exports from supported VS Code versions. Treat the format as version-sensitive unless Microsoft documents a stable schema.

### Cline

Cline task history is a distinct application workflow. This project has not established a documented, stable native task import contract. The first release will provide Copilot history to a new Cline task through `HANDOFF.md` and the read-only query interface rather than recreating it in Cline's task-history list. If Cline history can later be read reliably, it will use the same archive and query interface. Do not edit Cline's internal task storage or replay recorded tool calls.

### Reverse route

Reading Cline history and converting it into a Copilot session that can be reopened as a live session is out of the first milestone. It needs a documented export format or a user-selected Cline export, plus evidence of a supported Copilot import API. Cline history can still be archived in the same SQLite database and exposed to Copilot through `HANDOFF.md` and the query tool; this must not be claimed as native Copilot session import.

## Proposed repository layout

```text
Agent-History/
  README.md
  README.zh-CN.md
  docs/
    architecture.md
    architecture.zh-CN.md
    format.md
    format.zh-CN.md
  src/
    agent_history/
      __init__.py
      cli.py
      db/
        __init__.py
        schema.sql
        migrations/
      query/
        __init__.py
        service.py
        mcp_server.py
      adapters/
        copilot_vscode/
        cline/
      handoff/
        renderer.py
        templates/
      privacy/
  tests/
    fixtures/
    unit/
    integration/
```

Keep agent-specific parsing in `adapters`, database lifecycle and migrations in `db`, read-only retrieval logic in `query` (its MCP or other agent-protocol adapter must not expose writes or command execution), handoff-document rendering in `handoff`, and redaction/review helpers in `privacy`. MCP is a candidate connection method, not a mandatory dependency until support is verified in the target agents. Tests should use synthetic or explicitly sanitized fixtures, never private user histories.

## Canonical data model

- `agents`: source/destination product and adapter identity.
- `conversations`: one imported or created task/session, with provenance and metadata.
- `source_artifacts`: byte-for-byte copies of imported JSON, Markdown, and attachments with hash, length, media type, and provenance.
- `events`: ordered messages and workflow events, including tool calls and results, linked to source artifacts.
- `event_parts`: ordered message parts such as text, images, tool calls, tool results, and thinking blocks.
- `files`: file references or explicitly selected snapshots, identified by path and content hash where applicable.
- `event_files`: links events to files they mention or change.
- `handoffs` (schema addition pending): records generation time, source conversation, destination agent, template version, and content hash for audit. Query access must be scoped to stable conversation IDs.

The initial SQL proposal is [schema.sql](../src/agent_history/db/schema.sql). Normalized fields support querying; raw artifacts and source fragments preserve the source for fidelity; JSON payloads preserve source-specific details without prematurely forcing every agent into identical semantics.

Distinguish three outcomes: (1) raw source artifacts can be reconstructed byte-for-byte; (2) structured events in the database can be queried and traced to their originals; (3) a target agent's native session can only be guaranteed when that tool exposes a supported import mechanism. The project can implement the first two; it must not guess private JSON fields for the third.

## Read-only query tool

Prefer semantic operations over arbitrary SQL submitted by the agent: list accessible conversations; read conversation metadata; page through ordered events; retrieve an event and its parts; find tool calls and results; inspect related files; read source-artifact metadata; and inspect import-coverage reports. Raw BLOB access should be on demand, size-limited, and optionally return fragments; never load the whole database or huge tool output into context by default.

Use a read-only SQLite connection and `query_only`; expose only allowlisted queries, with no arbitrary SQL, writes, deletes, command execution, or tool replay. Scope each handoff to its conversation IDs so unrelated projects or sessions are not exposed. If using MCP, its local server should connect only to a database explicitly selected by the user and expose read-only tools/resources by default.

## Safety requirements

- Import and export are local by default.
- Parse input as untrusted data; never execute commands or tool calls found in history.
- Do not silently claim complete conversion. Record adapter and format versions and surface unsupported event types.
- Require user review before including snapshots, secrets, or sensitive content in an export.
- Never write to an agent's private history store in the first milestone.

## Open questions

- Which VS Code versions and Copilot chat export variants should be supported first?
- Does Cline expose a documented user-facing export suitable for this workflow, and what task artifacts can it preserve?
- Which tool-call details exist in Copilot JSON exports versus Markdown copy?
- Which destination agents can invoke a local read-only query tool through a supported interface?
- How should a full Markdown fallback be paginated while preserving relationships when a destination agent cannot use the query tool?
- What deterministic redaction and file-inclusion review should the first usable release provide?

## References

- [VS Code: Manage sessions in VS Code AI agents](https://code.visualstudio.com/docs/copilot/chat/chat-sessions) documents session management, JSON export, and Markdown copy options.
- [VS Code: Chat Participant API](https://code.visualstudio.com/api/extension-guides/ai/chat) documents the extension API for adding chat participants.
- [Cline documentation](https://docs.cline.bot/) and its [documentation index](https://docs.cline.bot/llms.txt) are starting points for verifying Cline workflows and supported user-facing interfaces.