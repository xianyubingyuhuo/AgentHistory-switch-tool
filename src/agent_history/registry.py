"""读取 agents.toml，校验配置，并把相对路径翻译成本机真实路径。"""

import os
import tomllib
from dataclasses import dataclass
from pathlib import Path, PureWindowsPath

AGENTS_FILE = Path(__file__).with_name("agents.toml")

_appdata = os.environ.get("APPDATA")
BASES: dict[str, Path | None] = {
    "home": Path.home(),
    "appdata": Path(_appdata) if _appdata else None,
}

REQUIRED_KEYS = ("label", "base", "markers", "index", "content")
PATH_KEYS = ("markers", "index", "content")


@dataclass(frozen=True)
class AgentEntry:
    agent_id: str
    label: str
    base_dir: Path
    markers: tuple[Path, ...]
    index: tuple[Path, ...]
    content_patterns: tuple[str, ...]


def _check_rel(where: str, rel: object) -> str:
    """配置是人手写的外部输入：只允许留在 base 目录内的相对路径。"""
    if not isinstance(rel, str) or not rel:
        raise ValueError(f"{where}: 路径必须是非空字符串，实际是 {rel!r}")
    win = PureWindowsPath(rel)
    if win.anchor:
        raise ValueError(f"{where}: 必须是相对路径，不能是 {rel!r}")
    if ".." in win.parts:
        raise ValueError(f"{where}: 路径不能包含 '..'：{rel!r}")
    return rel


def parse_agents(data: dict) -> dict[str, AgentEntry]:
    agents = data.get("agents")
    if not isinstance(agents, dict):
        raise ValueError("agents.toml: 缺少 [agents.<id>] 配置")

    result: dict[str, AgentEntry] = {}
    for agent_id, raw in agents.items():
        where = f"agents.{agent_id}"
        if not isinstance(raw, dict):
            raise ValueError(f"{where}: 必须是一个表")

        for key in REQUIRED_KEYS:
            if key not in raw:
                raise ValueError(f"{where}: 缺少 {key}")

        if raw["base"] not in BASES:
            raise ValueError(f"{where}: 未知的 base {raw['base']!r}，可选 {list(BASES)}")

        for key in PATH_KEYS:
            if not isinstance(raw[key], list):
                raise ValueError(f"{where}.{key}: 必须是列表")
            for rel in raw[key]:
                _check_rel(f"{where}.{key}", rel)

        # 本机没有这个 base 目录：不是错误，跳过这个 agent
        base_dir = BASES[raw["base"]]
        if base_dir is None:
            continue

        result[agent_id] = AgentEntry(
            agent_id=agent_id,
            label=raw["label"],
            base_dir=base_dir,
            markers=tuple(base_dir / rel for rel in raw["markers"]),
            index=tuple(base_dir / rel for rel in raw["index"]),
            content_patterns=tuple(raw["content"]),
        )
    return result


def load_agents(path: Path = AGENTS_FILE) -> dict[str, AgentEntry]:
    try:
        with path.open("rb") as f:
            data = tomllib.load(f)
    except tomllib.TOMLDecodeError as exc:
        raise ValueError(f"{path}: TOML 格式错误：{exc}") from exc
    return parse_agents(data)


if __name__ == "__main__":
    for entry in load_agents().values():
        print(f"{entry.agent_id}: {entry.label}")
        print(f"  base_dir: {entry.base_dir}")
        for p in entry.markers:
            print(f"  marker:   {p}")
        for p in entry.index:
            print(f"  index:    {p}")
        for pat in entry.content_patterns:
            print(f"  content:  {pat}")
