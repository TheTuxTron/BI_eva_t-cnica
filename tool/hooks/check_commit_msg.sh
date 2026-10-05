#!/usr/bin/env bash
# Conventional Commits: tipo(alcance opcional): descripción
msg="$1"
if [[ "$msg" =~ ^Merge ]]; then exit 0; fi
pattern='^(feat|fix|refactor|test|docs|chore|ci|perf|build|style)(\([a-z0-9-]+\))?!?: .{3,100}$'
if [[ ! "$msg" =~ $pattern ]]; then
  echo "✗ Commit inválido: \"$msg\""
  echo "  Usa: tipo(alcance): descripción   p. ej. feat(transfers): reintento seguro con idempotencia"
  exit 1
fi
