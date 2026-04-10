# aterm shell integration for zsh
# Loaded by .zshenv for interactive shells.

# Install claude wrapper as a shell function so it takes priority
# over any PATH-resolved binary. The wrapper injects --settings
# to enable aterm's Claude Code hooks.
typeset -g _ATERM_CLAUDE_WRAPPER=""
_aterm_install_claude_wrapper() {
    local resources_dir="${ATERM_RESOURCES_DIR:-}"
    [[ -n "$resources_dir" ]] || return 0

    local wrapper_path="$resources_dir/claude"
    [[ -x "$wrapper_path" ]] || return 0

    _ATERM_CLAUDE_WRAPPER="$wrapper_path"
    builtin unalias claude >/dev/null 2>&1 || true
    eval 'claude() { "$_ATERM_CLAUDE_WRAPPER" "$@"; }'
}
_aterm_install_claude_wrapper

# Ensure Resources dir is at the front of PATH after all rc files
# have finished loading. Runs once on first prompt, then removes itself.
_aterm_fix_path() {
    if [[ -n "${ATERM_RESOURCES_DIR:-}" && -d "$ATERM_RESOURCES_DIR" ]]; then
        local -a parts=("${(@s/:/)PATH}")
        parts=("${(@)parts:#$ATERM_RESOURCES_DIR}")
        PATH="${ATERM_RESOURCES_DIR}:${(j/:/)parts}"
    fi
    add-zsh-hook -d precmd _aterm_fix_path
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _aterm_fix_path
