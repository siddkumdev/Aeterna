"""Cross-platform launcher for the graphify-godot MCP stdio server.

Locates the installed `graphifyy` uv-tool Python (or current interpreter if
`graphify` is importable) and executes `python -m graphify.serve <graph.json>`.
"""

import importlib.util
import os
import subprocess
import sys
from pathlib import Path


def _find_python() -> str | None:
    if importlib.util.find_spec("graphify") is not None and importlib.util.find_spec("graphify.serve") is not None:
        return sys.executable
    candidates: list[Path] = []
    appdata = os.environ.get("APPDATA")
    if appdata:
        candidates.append(Path(appdata) / "uv" / "tools" / "graphifyy" / "Scripts" / "python.exe")
    xdg_data = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
    candidates.append(xdg_data / "uv" / "tools" / "graphifyy" / "bin" / "python")
    candidates.append(Path.home() / ".local" / "share" / "uv" / "tools" / "graphifyy" / "bin" / "python")
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)
    return None


def main() -> int:
    graph_path = sys.argv[1] if len(sys.argv) > 1 else "graphify-out/graph.json"
    py = _find_python()
    if py is None:
        sys.stderr.write(
            "graphifyy is not installed. Run:\n"
            "  uv tool install --with \"mcp<2\" \"git+https://github.com/hidalgob/graphify-godot.git\"\n"
        )
        return 1
    return subprocess.call([py, "-m", "graphify.serve", graph_path])


if __name__ == "__main__":
    raise SystemExit(main())
