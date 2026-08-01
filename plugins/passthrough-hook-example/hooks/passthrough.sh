#!/bin/bash
set -euo pipefail

# Consume stdin so Claude Code doesn't block waiting for it, then allow the
# tool call to proceed unchanged.
cat >/dev/null

exit 0
