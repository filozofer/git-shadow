#compdef git-shadow
# git-shadow zsh completion
#
# Installation:
#   Add to your ~/.zshrc:
#     source /path/to/git-shadow/completions/git-shadow.zsh
#
#   Or place this file in a directory on your $fpath and run:
#     compinit

_git_shadow() {
  local context state line
  typeset -A opt_args

  _arguments -C \
    '1: :_git_shadow_commands' \
    '*:: :->args'

  case $state in
    args)
      case $line[1] in
        feature)    _git_shadow_feature ;;
        config)     _git_shadow_config ;;
        status)     _arguments '--json[output as JSON]' ;;
        commit)     _arguments '-m[commit message]:message:' ;;
        completion) _arguments '1: :_git_shadow_completion_subcommands' ;;
      esac
      ;;
  esac
}

_git_shadow_commands() {
  local commands
  commands=(
    'version:show the current git-shadow version'
    'install-hooks:install pre-commit and pre-push git hooks'
    'doctor:run diagnostic checks on the environment and repository'
    'status:show the current shadow/public branch state'
    'commit:create a shadow-aware commit (separates code from local comments)'
    'promote:promote a local @local commit to the public branch'
    'check-local-comments:check staged files for local comment markers'
    'feature:manage the feature branch lifecycle (start / publish / finish)'
    'config:manage git-shadow configuration'
    'completion:manage shell completion'
  )
  _describe 'command' commands
}

_git_shadow_feature() {
  local context state line

  _arguments -C \
    '1: :_git_shadow_feature_subcommands' \
    '*:: :->args'

  case $state in
    args)
      case $line[1] in
        publish)
          _arguments \
            '--commit[commit staged changes before publishing]' \
            '-m[commit message]:message:'
          ;;
        finish)
          _arguments \
            '--keep-branches[do not delete branches after finishing]' \
            '--no-pull[skip pulling base branches]' \
            '--force[force delete branches even if not fully merged]'
          ;;
      esac
      ;;
  esac
}

_git_shadow_feature_subcommands() {
  local subcommands
  subcommands=(
    'start:create a new shadow/public feature branch pair'
    'publish:cherry-pick clean commits to the public branch'
    'finish:merge and finalize the feature, then clean up branches'
    'sync:rebase the shadow branch onto its public counterpart'
  )
  _describe 'subcommand' subcommands
}

_git_shadow_config_keys() {
  local -a keys
  keys=(${(f)"$(git-shadow config list 2>/dev/null | awk '{print $1}')"})
  _describe 'config key' keys
}

_git_shadow_config() {
  local context state line

  _arguments -C \
    '1: :_git_shadow_config_subcommands' \
    '*:: :->args'

  case $state in
    args)
      case $line[1] in
        get)
          _arguments \
            '1: :_git_shadow_config_keys' \
            '--json[output as JSON]'
          ;;
        set|unset)
          _arguments \
            '1: :_git_shadow_config_keys' \
            '--project-config[save to project-level config (.git-shadow.env)]' \
            '--user-config[save to user-level config (~/.config/git-shadow/config.env)]'
          ;;
        show|list)
          _arguments '--json[output as JSON]'
          ;;
      esac
      ;;
  esac
}

_git_shadow_config_subcommands() {
  local subcommands
  subcommands=(
    'list:list all known configuration keys'
    'show:display the effective merged configuration with source tiers'
    'get:get a single configuration value'
    'set:set a configuration value'
    'unset:remove a configuration value'
  )
  _describe 'subcommand' subcommands
}

_git_shadow_completion_subcommands() {
  local subcommands
  subcommands=(
    'install:install shell completion into your shell config'
  )
  _describe 'subcommand' subcommands
}

# Register completion for git-shadow binary
compdef _git_shadow git-shadow

# Register for "git shadow" invocation (zsh git completion integration)
# zsh's _git function calls _git-<subcommand> for external git commands.
_git-shadow() { _git_shadow }
