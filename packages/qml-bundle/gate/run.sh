#!/usr/bin/env bash
# QML engine gate: build gate/suite.ts through the real QML pipeline, run it in
# Node and in Qt 6.9.2 + 6.11.1 (PySide6 via uv, .qt/), and diff the logs.
# Setup once: see .qt/ in the repo root (uv venv + PySide6-Essentials).
set -e
cd "$(dirname "$0")/.."
QT="${LK_QT_ENVS:-../../.qt}"
mkdir -p gate/out
node build.mjs gate/suite.ts gate/out/suite.js Suite
node gate/noderun.cjs gate/out/suite.js > gate/out/node.txt 2>&1
status=0
for q in q692 q611; do
  "$QT/$q/bin/python" gate/qmlrun.py gate/out/suite.js 60000 > "gate/out/$q.txt" 2>&1 || true
  if diff <(grep -v -e '^TIME' -e '^==' -e GLOBALCHECK gate/out/node.txt) \
          <(grep -v -e '^TIME' -e '^==' -e GLOBALCHECK -e '^\[qt\]' "gate/out/$q.txt") > "gate/out/$q.diff"; then
    echo "$q ($(head -1 gate/out/$q.txt | cut -c4-)) == node: IDENTICAL ($(grep -c ' = ' gate/out/node.txt) checks)"
  else
    echo "$q != node:"; head -30 "gate/out/$q.diff"; status=1
  fi
done
exit $status
