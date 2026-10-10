# 拟议架构

[English](architecture.md) | [简体中文](architecture.zh-CN.md)

## 目标

构建一个本地 Python 应用，以可检查、可移植的形式保存 Agent 对话和工作流记录，并生成其他 Agent 可以使用的交接材料。首批目标是 VS Code 中的 GitHub Copilot Chat 与 Cline。

这是架构提案，不是已实现的功能。项目不能只依赖没有公开文档的私有存储格式。

## 存储选择

本地数据库采用 SQLite，通过 Python 标准库 `sqlite3` 访问。SQLite 是嵌入式数据库，数据保存在普通文件中，不需要单独安装或运行数据库服务。数据库结构变更通过仓库内的迁移脚本管理，并且每次连接都启用外键约束。

SQLite 是本地权威档案。Markdown 不是完整历史的替代品，而是每次交接自动生成的流程说明，告诉接收 Agent 交接目标、当前状态、优先阅读内容，以及如何通过只读查询工具访问数据库。它不要求用户手写摘要，也不把全部历史复制进提示词。

归档分为两层：`source_artifacts` 以 BLOB 原样保存用户提供的导出文件及其 SHA-256、长度和类型；`events` / `event_parts` 保存可搜索的结构化视图，并记录来源工件和原始片段。解析器未识别的内容仍留在原始工件中，不因转换失败而丢失。原始记录可能含密钥或私人内容，因此本地保存不等于适合分享；导出前必须单独审查。

## 首批交接流程

1. 用户通过 VS Code 的 `Chat: Export Chat...` 命令导出 Copilot Chat 会话，或将会话复制为 Markdown。
2. Copilot 导入器将用户选中的 JSON 或 Markdown 文件作为原始 BLOB 导入 SQLite，不修改 VS Code 数据，并计算哈希以便验证原始数据未被改写。VS Code 文档对 JSON 导出只承诺包含 prompts 和 responses，并未承诺包含工具调用或思考块；需要这些信息时，应优先另存一份 `Copy All` Markdown，它的文档明确说包含思考步骤和工具调用。
3. 解析器将识别出的消息、内容块、工具调用等映射为标准事件；每条映射都关联原始工件及可用的来源片段。未知字段保留在原始工件中，并尽可能复制到 JSON 负载。
4. 导入器为会话生成稳定的 Agent-History 会话 ID，并保留来源 Agent、源会话 ID 和项目工作区关联。
5. 用户检查导入状态、解析覆盖率、文件引用和可能的敏感内容。原始数据本地保存不代表自动适合分享。
6. 用户发起交接后，程序直接生成 `HANDOFF.md`，默认不额外调用 Agent：用已有的交接意图和可验证的归档字段填写目标 Agent、项目/分支、当前状态、建议先查阅的历史范围和下一步。如果用户没有单独提供交接意图，当前 Agent 可以选择从当前任务上下文提炼一句目标；不生成冗长历史摘要。缺少可靠依据的字段标为未知或待接收 Agent 核实，不编造。
7. 接收 Agent 使用只读查询工具按需读取会话概览、事件范围、工具调用及结果、关联文件和来源片段。它可以沿关联逐步扩展读取；完整历史保留在 SQLite，而不是预先塞进 Markdown。

交接文档负责“做什么、从哪里开始、如何查询”；查询工具负责“提供原始记录与关联证据”。默认模板渲染不产生额外 Agent 调用或摘要成本。如果目标 Agent 无法调用本地查询工具，程序可以另外生成可读的完整 Markdown 记录作为兼容回退，但不应默默退化成摘要交接。

## 适配器边界

### VS Code 中的 GitHub Copilot Chat

VS Code 官方文档说明，可以通过 `Chat: Export Chat...` 将聊天会话导出为 JSON，并称 JSON 包含所有 prompts 和 responses；文档没有承诺 JSON 一定包含工具调用、思考块、附件、编辑或稳定的机器可读 schema。另一个 `Copy All` Markdown 功能则明确包含 prompts、responses、思考步骤和工具调用。二者可作为互补的输入来源，但需处理重复记录，且都不能凭空恢复源端未导出的状态。官方文档没有描述将已导出的 JSON 重新导入为可继续会话的命令。扩展的 Chat Participant API 用于构建聊天参与者，并不是读取 Copilot 历史会话或导入旧 transcript 的接口。

因此，首个适配器应读取用户主动选择的导出文件，而不是读写 VS Code 私有数据库。JSON 解析器要用不同 VS Code 版本的真实导出样本测试。除非微软公布稳定结构，否则应把导出格式视为可能随版本变化。

### Cline

Cline 的任务历史属于独立的应用工作流。本项目尚未确认 Cline 有公开、稳定的原生任务导入协议。因此首版通过 `HANDOFF.md` 和只读查询接口把 Copilot 历史交给一个新的 Cline 任务读取，而不尝试恢复为 Cline 历史列表里的旧任务。后续若能稳定读取 Cline 历史，也使用同一数据库和查询接口。不要修改 Cline 内部任务存储，也不要重放其中记录的工具调用。

### 反向交接

从 Cline 读取历史，再转换成可在 Copilot 中重新打开的实时会话，不属于首个里程碑。它需要 Cline 提供有文档支持的导出格式或由用户选择的导出文件，同时也需要有证据证明 Copilot 存在受支持的导入接口。即使条件尚不具备，Cline 历史仍可保存到同一 SQLite 档案，并通过 `HANDOFF.md` 和查询工具提供给 Copilot；不能宣称这是 Copilot 原生会话导入。

## 拟议仓库结构

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

Agent 专属解析逻辑放在 `adapters`；数据库连接和迁移放在 `db`；只读检索逻辑放在 `query`，其 MCP 等 Agent 工具协议适配层不得包含写数据库或执行历史命令的能力；交接文档生成放在 `handoff`；脱敏与用户检查辅助逻辑放在 `privacy`。MCP 可作为接入方式候选，但应以目标 Agent 实际支持情况验证后再确定为必需依赖。测试应使用合成或明确脱敏的样本，不能使用用户的私人历史记录。

## 标准数据模型

- `agents`：来源或目标产品及适配器身份。
- `conversations`：导入或创建的一段会话/任务，记录来源信息和元数据。
- `source_artifacts`：以 BLOB 原样保存导入的 JSON、Markdown 或附件，并记录哈希、长度、媒体类型和来源。
- `events`：有序保存消息和工作流事件，包括工具调用及结果；关联来源工件。
- `event_parts`：保留消息内部有序的文本、图像、工具调用、工具结果、思考块等内容片段。
- `files`：文件引用或用户明确选择的快照；适用时记录路径和内容哈希。
- `event_files`：将事件与其提及或变更的文件关联起来。
- `handoffs`（待加入 schema）：记录交接文档生成时间、来源会话、目标 Agent、模板版本和内容哈希，便于审计；接收 Agent 查询时应使用稳定的会话授权范围。

首版 SQL 提案见 [schema.sql](../src/agent_history/db/schema.sql)。结构化列便于查询；原始工件和原始片段用于保真留档；JSON 负载保留来源工具的特有信息，避免过早假设所有 Agent 的语义完全相同。

因此需要区分三种结果：①原始来源工件可按字节还原；②数据库中的结构化事件可供查询并链接回原件；③目标工具原生会话只有在该工具提供受支持的导入机制时才能保证生成。前两种由本项目设计实现，第三种不能仅靠猜测其内部 JSON 字段实现。

## 只读查询工具

查询接口应优先提供语义化操作，而不是让 Agent 自由提交 SQL：列出可访问会话、读取会话元数据、按顺序分页读取事件、读取指定事件及其内容块、查询工具调用与结果、查看事件关联文件、读取来源工件元数据和导入覆盖报告。原始 BLOB 的读取应按需、带大小限制，并可只返回片段；不能把整个数据库文件或巨大工具输出默认塞进上下文。

查询连接使用只读模式和 SQLite `query_only`；工具层只暴露白名单查询，不提供任意 SQL、写入、删除、命令执行或工具重放操作。对每次交接限定会话 ID 范围，避免把其他项目或会话意外暴露给接收 Agent。若使用 MCP，MCP server 应以本地进程方式连接用户明确选择的数据库，并默认只暴露只读 tools/resources。

## 安全要求

- 默认在本地导入和导出。
- 将输入解析为不可信数据；绝不执行历史记录中的命令或工具调用。
- 不得静默宣称转换完整。记录适配器版本和格式版本，并标明无法支持的事件类型。
- 导出快照、密钥或敏感内容前，必须由用户检查确认。
- 首个里程碑绝不写入 Agent 的私有历史存储。

## 待讨论问题

- 首批支持哪些 VS Code 版本和 Copilot 聊天导出格式？
- Cline 是否提供适用于此流程的、面向用户且有文档支持的导出能力？能保留哪些任务材料？
- Copilot JSON 导出和 Markdown 复制分别包含哪些工具调用细节？
- 哪些目标 Agent 能以何种受支持的方式调用本地只读查询工具？
- 若目标 Agent 不支持查询工具，完整 Markdown 回退如何分页并保持关联？
- 首个可用版本应提供怎样的确定性脱敏和文件纳入检查？

## 参考资料

- [VS Code：在 VS Code AI Agent 中管理会话](https://code.visualstudio.com/docs/copilot/chat/chat-sessions)：说明会话管理、JSON 导出和 Markdown 复制功能。
- [VS Code：Chat Participant API](https://code.visualstudio.com/api/extension-guides/ai/chat)：说明用于添加聊天参与者的扩展 API。
- [Cline 文档](https://docs.cline.bot/)及其[文档索引](https://docs.cline.bot/llms.txt)：用于后续核对 Cline 工作流和面向用户的受支持接口。