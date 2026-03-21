#!/usr/bin/env bash
# git-shadow bash completion
#
# Installation:
#   Add to your ~/.bashrc or ~/.bash_profile:
#     source /path/to/git-shadow/completions/git-shadow.bash
#
#   Or for npm/curl installs:
#     source ~/.local/share/git-shadow/completions/git-shadow.bash

_git_shadow() {
  local cur
  cur="${COMP_WORDS[COMP_CWORD]}"

  # Support both "git-shadow <cmd>" and "git shadow <cmd>" invocations.
  # Determine the offset of the first subcommand in COMP_WORDS.
  local offset=1
  [[ "${COMP_WORDS[0]}" == "git" ]] && offset=2

  local cmd="${COMP_WORDS[$offset]:-}"
  local subcmd="${COMP_WORDS[$((offset + 1))]:-}"
  local pos=$(( COMP_CWORD - offset ))

  # Complete top-level command
  if [[ $pos -le 0 ]]; then
    COMPREPLY=($(compgen -W "version install-hooks doctor status commit check-local-comments feature config completion" -- "$cur"))
    return
  fi

  case "$cmd" in
    feature)
      if [[ $pos -eq 1 ]]; then
        COMPREPLY=($(compgen -W "start publish finish" -- "$cur"))
      else
        case "$subcmd" in
          publish) COMPREPLY=($(compgen -W "--commit -m" -- "$cur")) ;;
          finish)  COMPREPLY=($(compgen -W "--keep-branches --no-pull --force" -- "$cur")) ;;
        esac
      fi
      ;;
    config)
      if [[ $pos -eq 1 ]]; then
        COMPREPLY=($(compgen -W "list show get set unset" -- "$cur"))
      elif [[ $pos -eq 2 ]]; then
        case "$subcmd" in
          get|set|unset)
            local keys
            keys="$(git-shadow config list 2>/dev/null | awk '{print $1}')"
            COMPREPLY=($(compgen -W "$keys" -- "$cur"))
            ;;
          show|list) COMPREPLY=($(compgen -W "--json" -- "$cur")) ;;
        esac
      else
        case "$subcmd" in
          show|get|list) COMPREPLY=($(compgen -W "--json" -- "$cur")) ;;
          set|unset)     COMPREPLY=($(compgen -W "--project-config --user-config" -- "$cur")) ;;
        esac
      fi
      ;;
    status)
      COMPREPLY=($(compgen -W "--json" -- "$cur"))
      ;;
    commit)
      COMPREPLY=($(compgen -W "-m" -- "$cur"))
      ;;
    completion)
      if [[ $pos -eq 1 ]]; then
        COMPREPLY=($(compgen -W "install" -- "$cur"))
      fi
      ;;
  esac
}

# Register for direct git-shadow invocation
complete -F _git_shadow git-shadow

# Register for "git shadow" invocation via git's completion framework (if available)
if declare -f __git_complete &>/dev/null; then
  __git_complete git-shadow _git_shadow
fi
