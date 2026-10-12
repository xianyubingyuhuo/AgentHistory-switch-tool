import os
from dataclasses import dataclass
from pathlib import Path

from agent_history.registry import load_agents

@dataclass(frozen=True)
class AgentLocation:
    """一个 Agent 在本机找到的数据位置。"""
    agent: str                        # agents.toml 里的 id，例如 "cline"
    label: str                        # 显示名，例如 "Cline"
    index_paths: tuple[Path, ...]     # 找到的会话索引，例如 sessions.db
    content_paths: tuple[Path, ...]   # 找到的对话内容文件
    found_by: str                     # "table" 或 "search"

def detect_agents(agents) -> list[str]: ... 
def locate(agent_id, entry) -> AgentLocation | None: ...
def main() -> None: ...

if __name__ == "__main__":
    main()
