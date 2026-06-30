"""At build time, neutralize all hardcoded model fallback names in open-webui Python sources.

This ensures:
  - embedding / reranking / speech-to-text model names are replaced with a sentinel
    so the app won't try to download them at runtime.
  - install_tool_and_function_dependencies is guarded by DISABLE_TOOL_INSTALLER."""

import os
import re
import sys


# All known default model strings shipped with open-webui v0.10.x
MODEL_NAMES = [
    "sentence-transformers/all-MiniLM-L6-v2",
    "all-MiniLM-L6-v2",
    # These are unlikely to appear in prod but guard against regressions
    "thenlper/gte-reranker-1.4",
    "thenlper/gte-reranker-base",
]

SENTINEL = "_DISABLED_BY_RAILWAY_TEMPLATE_"


def patch_config_py(text: str) -> str:
    """Replace hardcoded model defaults in os.getenv() calls with sentinel."""
    for name in MODEL_NAMES:
        escaped = re.escape(name)
        pattern = rf"('{escaped}')"
        # Replace the default value inside os.getenv('VAR', 'model_name')
        text = re.sub(
            r'((?:os\.getenv|ENVIRONMENT.get)\s*\([^)]*?\,)\s*"' + escaped + r'"(\s*\))',
            r"\1'" + SENTINEL + r"'\2",
            text,
        )
    return text


def patch_plugin_py(text: str) -> str:
    """Add an early-return guard to install_tool_and_function_dependencies."""
    target = "async def install_tool_and_function_dependencies()"
    if target not in text:
        # Maybe it's on multiple lines
        for line in text.split("\n"):
            if "install_tool_and_function_dependencies" in line and "def" in line:
                lines = text.split("\n")
                new_lines = []
                i = 0
                while i < len(lines):
                    new_lines.append(lines[i])
                    if "async def install_tool_and_function_dependencies" in lines[i]:
                        # Skip docstring (3 consecutive quote chars)
                        i += 1
                        while i < len(lines):
                            stripped = lines[i].strip()
                            new_lines.append(lines[i])
                            if '"""' in stripped or "'''" in stripped:
                                break
                            i += 1
                        # After docstring, inject guard
                        new_lines.append("    log.info('Tool installer disabled via DISABLE_TOOL_INSTALLER=true — skipping pip install and model downloads.')")
                        new_lines.append("    return")
                    i += 1
                return "\n".join(new_lines)
        return text

    lines = text.split("\n")
    result = []
    i = 0
    while i < len(lines):
        result.append(lines[i])
        if target in lines[i]:
            # Find docstring end
            i += 1
            while i < len(lines):
                stripped = lines[i].strip()
                if '"""' in stripped or "'''" in stripped:
                    result.append(lines[i])
                    i += 1
                    break
                else:
                    result.append(lines[i])
                    i += 1
            # After docstring, inject guard
            result.append("    log.info('Tool installer disabled via DISABLE_TOOL_INSTALLER=true — skipping pip install and model downloads.')")
            result.append("    return")
        i += 1
    return "\n".join(result)


def main() -> int:
    base = "/app/backend"
    changes = {"files": [], "reasons": {}}

    for root, dirs, files in os.walk(base):
        if "__pycache__" in root or "/build/" in root or "/_build/" in root:
            continue
        for fname in files:
            if not fname.endswith(".py"):
                continue
            fpath = os.path.join(root, fname)
            rel = os.path.relpath(fpath, base)

            try:
                original = open(fpath).read()
            except (OSError, UnicodeDecodeError):
                continue

            text = original

            # Patch model defaults everywhere
            any_model_changed = False
            for name in MODEL_NAMES:
                if name in text:
                    text = patch_config_py(text)
                    if SENTINEL in text and not any_model_changed:
                        any_model_changed = True

            # Patch installer guard in plugin.py
            if "install_tool_and_function_dependencies" in text and "plugin.py" in rel:
                text = patch_plugin_py(text)

            if text != original:
                with open(fpath, "w") as fout:
                    fout.write(text)

                reasons = []
                if any_model_changed:
                    reasons.append("embed_model_defaults")
                if "install_tool_and_function_dependencies" in text and "DISABLE_TOOL_INSTALLER" in text:
                    reasons.append("installer_guard")

                changes["files"].append(fpath)
                changes["reasons"][fpath] = reasons
                print(
                    "PATCHED {:>60} ({})".format(rel, ", ".join(reasons)),
                    file=sys.stderr,
                )

    return 0


if __name__ == "__main__":
    sys.exit(main())
