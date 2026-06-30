"""Patch open-webui config files to neutralize hardcoded model fallback names.
      
At build time, scan uploaded .py files for hardcoded embedding/retrieval model names
like sentence-transformers/all-MiniLM-L6-v2 and similar, which are used as fallbacks
in or-chains that never get overridden by Docker ENV vars.  Replace them with a
sentinel value that will short-circuit the fallback.

This ensures memory stays under 512MB (no model downloads) and startup is fast."""

import glob
import os
import sys


MODELS_TO_REPLACE = [
    "sentence-transformers/all-MiniLM-L6-v2",
    "all-MiniLM-L6-v2",
    "thenlper/gte-reranker-1.4",
    "thenlper/gte-reranker-base",
]

SENTINEL = "DISABLED_BY_HERMES_PATCH"


def main() -> int:
    base = "/app/backend/src/open_webui"

    for root, dirs, files in os.walk(base):
        for fname in files:
            if not fname.endswith(".py") or "__pycache__" in root:
                continue
            
            fpath = os.path.join(root, fname)
            try:
                text = open(fpath).read()
            except (OSError, UnicodeDecodeError):
                continue

            original = text
            for model_name in MODELS_TO_REPLACE:
                text = text.replace(model_name, SENTINEL)

            if text != original:
                with open(fpath, "w") as fout:
                    fout.write(text)
                print(f"PATCHED {fpath}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
