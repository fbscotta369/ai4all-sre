---
description: Build and verify documentation autonomously
---

// turbo-all

1. Install documentation dependencies in the virtual environment
```bash
./.venv/bin/python -m pip install mkdocs-material mkdocstrings[python]
```

2. Build the documentation with strict path checking
```bash
./.venv/bin/python -m mkdocs build --strict
```
