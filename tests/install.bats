#!/usr/bin/env bats

TOOLKIT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"

setup() {
  INSTALL_HOME="$(mktemp -d)"
  BIN_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$INSTALL_HOME" "$BIN_DIR"
}

# ---------------------------------------------------------------------------
# Symlink / binary resolution (common to both curl and npm installs)
# ---------------------------------------------------------------------------

@test "binary works when invoked via symlink from a different directory" {
  ln -sf "$TOOLKIT_ROOT/bin/git-shadow" "$BIN_DIR/git-shadow"
  run "$BIN_DIR/git-shadow" version
  [ "$status" -eq 0 ]
}

@test "TOOLKIT_ROOT resolves correctly through a symlink" {
  ln -sf "$TOOLKIT_ROOT/bin/git-shadow" "$BIN_DIR/git-shadow"
  # 'doctor' sources all lib/ files — fails if TOOLKIT_ROOT is wrong
  mkdir -p "$BIN_DIR/repo" && cd "$BIN_DIR/repo" && git init -q
  git config user.name "Test" && git config user.email "t@t.com"
  run "$BIN_DIR/git-shadow" doctor
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# curl-style install (install.sh)
# ---------------------------------------------------------------------------

@test "install.sh: creates binary symlink in BIN_DIR" {
  local bare_repo
  bare_repo="$(mktemp -d)"
  git clone --bare --quiet "$TOOLKIT_ROOT" "$bare_repo" 2>/dev/null

  # Pre-clone so install.sh takes the "update" path (fetch from local bare repo)
  git clone --quiet "file://$bare_repo" "$INSTALL_HOME" 2>/dev/null

  GIT_SHADOW_HOME="$INSTALL_HOME" GIT_SHADOW_BIN="$BIN_DIR" \
    bash "$TOOLKIT_ROOT/install.sh" >/dev/null 2>&1

  [ -f "$BIN_DIR/git-shadow" ]
  rm -rf "$bare_repo"
}

@test "install.sh: installed binary is executable" {
  local bare_repo
  bare_repo="$(mktemp -d)"
  git clone --bare --quiet "$TOOLKIT_ROOT" "$bare_repo" 2>/dev/null
  git clone --quiet "file://$bare_repo" "$INSTALL_HOME" 2>/dev/null

  GIT_SHADOW_HOME="$INSTALL_HOME" GIT_SHADOW_BIN="$BIN_DIR" \
    bash "$TOOLKIT_ROOT/install.sh" >/dev/null 2>&1

  [ -x "$BIN_DIR/git-shadow" ]
  rm -rf "$bare_repo"
}

@test "install.sh: installed binary runs correctly" {
  local bare_repo
  bare_repo="$(mktemp -d)"
  git clone --bare --quiet "$TOOLKIT_ROOT" "$bare_repo" 2>/dev/null
  git clone --quiet "file://$bare_repo" "$INSTALL_HOME" 2>/dev/null

  GIT_SHADOW_HOME="$INSTALL_HOME" GIT_SHADOW_BIN="$BIN_DIR" \
    bash "$TOOLKIT_ROOT/install.sh" >/dev/null 2>&1

  run "$BIN_DIR/git-shadow" version
  [ "$status" -eq 0 ]
  rm -rf "$bare_repo"
}

@test "install.sh: re-run on existing install exits 0 (idempotent)" {
  local bare_repo
  bare_repo="$(mktemp -d)"
  git clone --bare --quiet "$TOOLKIT_ROOT" "$bare_repo" 2>/dev/null
  git clone --quiet "file://$bare_repo" "$INSTALL_HOME" 2>/dev/null

  GIT_SHADOW_HOME="$INSTALL_HOME" GIT_SHADOW_BIN="$BIN_DIR" \
    bash "$TOOLKIT_ROOT/install.sh" >/dev/null 2>&1
  run env GIT_SHADOW_HOME="$INSTALL_HOME" GIT_SHADOW_BIN="$BIN_DIR" \
    bash "$TOOLKIT_ROOT/install.sh"
  [ "$status" -eq 0 ]
  rm -rf "$bare_repo"
}

# ---------------------------------------------------------------------------
# npm install (postinstall script)
# ---------------------------------------------------------------------------

@test "npm postinstall: makes bin/git-shadow executable" {
  local npm_dir
  npm_dir="$(mktemp -d)"
  cp -r "$TOOLKIT_ROOT/." "$npm_dir/"
  (cd "$npm_dir" && npm run postinstall 2>/dev/null)
  [ -x "$npm_dir/bin/git-shadow" ]
  rm -rf "$npm_dir"
}

@test "npm postinstall: makes lib/*.sh scripts executable" {
  local npm_dir
  npm_dir="$(mktemp -d)"
  cp -r "$TOOLKIT_ROOT/." "$npm_dir/"
  chmod -x "$npm_dir"/lib/*.sh
  (cd "$npm_dir" && npm run postinstall 2>/dev/null)
  for f in "$npm_dir"/lib/*.sh; do
    [ -x "$f" ]
  done
  rm -rf "$npm_dir"
}

@test "npm install: binary works after postinstall" {
  local npm_dir
  npm_dir="$(mktemp -d)"
  cp -r "$TOOLKIT_ROOT/." "$npm_dir/"
  (cd "$npm_dir" && npm run postinstall 2>/dev/null)
  run "$npm_dir/bin/git-shadow" version
  [ "$status" -eq 0 ]
  rm -rf "$npm_dir"
}
