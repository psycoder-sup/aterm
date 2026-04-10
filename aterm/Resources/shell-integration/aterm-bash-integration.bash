# aterm shell integration for bash

# Install claude wrapper as a shell function so it takes priority
# over any PATH-resolved binary.
_ATERM_CLAUDE_WRAPPER=""
_aterm_install_claude_wrapper() {
    local resources_dir="${ATERM_RESOURCES_DIR:-}"
    [[ -n "$resources_dir" ]] || return 0

    local wrapper_path="$resources_dir/claude"
    [[ -x "$wrapper_path" ]] || return 0

    _ATERM_CLAUDE_WRAPPER="$wrapper_path"
    unalias claude >/dev/null 2>&1 || true
    eval 'claude() { "$_ATERM_CLAUDE_WRAPPER" "$@"; }'
}
_aterm_install_claude_wrapper

# Ensure Resources dir is at the front of PATH.
_aterm_fix_path() {
    if [[ -n "${ATERM_RESOURCES_DIR:-}" && -d "$ATERM_RESOURCES_DIR" ]]; then
        local new_path=":${PATH}:"
        new_path="${new_path//:${ATERM_RESOURCES_DIR}:/:}"
        new_path="${new_path#:}"
        new_path="${new_path%:}"
        PATH="${ATERM_RESOURCES_DIR}:${new_path}"
    fi
}
_aterm_fix_path
unset -f _aterm_fix_path
