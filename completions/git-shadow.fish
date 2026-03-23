# git-shadow fish completion
#
# Installation (automatic via symlink):
#   git shadow completion install
#
# Manual installation:
#   ln -sf /path/to/git-shadow/completions/git-shadow.fish \
#     ~/.config/fish/completions/git-shadow.fish

# Disable file completion by default
complete -c git-shadow -f

# ---------------------------------------------------------------------------
# Top-level commands
# ---------------------------------------------------------------------------

set -l top_cmds version install-hooks doctor status commit promote check-local-comments feature config completion

complete -c git-shadow -n "not __fish_seen_subcommand_from $top_cmds" -a version              -d "show the current version"
complete -c git-shadow -n "not __fish_seen_subcommand_from $top_cmds" -a install-hooks        -d "install pre-commit and pre-push git hooks"
complete -c git-shadow -n "not __fish_seen_subcommand_from $top_cmds" -a doctor               -d "run diagnostic checks on the environment"
complete -c git-shadow -n "not __fish_seen_subcommand_from $top_cmds" -a status               -d "show shadow/public branch state"
complete -c git-shadow -n "not __fish_seen_subcommand_from $top_cmds" -a commit               -d "create a shadow-aware commit"
complete -c git-shadow -n "not __fish_seen_subcommand_from $top_cmds" -a promote              -d "promote a local @local commit to the public branch"
complete -c git-shadow -n "not __fish_seen_subcommand_from $top_cmds" -a check-local-comments -d "check staged files for local comment markers"
complete -c git-shadow -n "not __fish_seen_subcommand_from $top_cmds" -a feature              -d "manage feature branch lifecycle"
complete -c git-shadow -n "not __fish_seen_subcommand_from $top_cmds" -a config               -d "manage git-shadow configuration"
complete -c git-shadow -n "not __fish_seen_subcommand_from $top_cmds" -a completion           -d "manage shell completion"

# ---------------------------------------------------------------------------
# feature subcommands and flags
# ---------------------------------------------------------------------------

set -l feature_subcmds start publish finish sync

complete -c git-shadow -n "__fish_seen_subcommand_from feature; and not __fish_seen_subcommand_from $feature_subcmds" -a start   -d "create a new shadow/public feature branch pair"
complete -c git-shadow -n "__fish_seen_subcommand_from feature; and not __fish_seen_subcommand_from $feature_subcmds" -a publish -d "cherry-pick clean commits to the public branch"
complete -c git-shadow -n "__fish_seen_subcommand_from feature; and not __fish_seen_subcommand_from $feature_subcmds" -a finish  -d "merge and finalize the feature, then clean up"
complete -c git-shadow -n "__fish_seen_subcommand_from feature; and not __fish_seen_subcommand_from $feature_subcmds" -a sync    -d "rebase the shadow branch onto its public counterpart"
complete -c git-shadow -n "__fish_seen_subcommand_from feature; and __fish_seen_subcommand_from sync" -l continue -d "resume after manual conflict resolution"
complete -c git-shadow -n "__fish_seen_subcommand_from feature; and __fish_seen_subcommand_from sync" -l abort    -d "abort the sync rebase"

complete -c git-shadow -n "__fish_seen_subcommand_from feature; and __fish_seen_subcommand_from publish" -l commit       -d "commit staged changes before publishing"
complete -c git-shadow -n "__fish_seen_subcommand_from feature; and __fish_seen_subcommand_from publish" -s m -r         -d "commit message"
complete -c git-shadow -n "__fish_seen_subcommand_from feature; and __fish_seen_subcommand_from finish"  -l keep-branches -d "do not delete branches after finishing"
complete -c git-shadow -n "__fish_seen_subcommand_from feature; and __fish_seen_subcommand_from finish"  -l no-pull       -d "skip pulling base branches"
complete -c git-shadow -n "__fish_seen_subcommand_from feature; and __fish_seen_subcommand_from finish"  -l force         -d "force delete branches even if not fully merged"

# ---------------------------------------------------------------------------
# config subcommands and flags
# ---------------------------------------------------------------------------

function __git_shadow_config_keys
  git-shadow config list 2>/dev/null | awk '{print $1}'
end

set -l config_subcmds list show get set unset

complete -c git-shadow -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from $config_subcmds" -a list  -d "list all known configuration keys"
complete -c git-shadow -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from $config_subcmds" -a show  -d "display the effective merged configuration"
complete -c git-shadow -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from $config_subcmds" -a get   -d "get a single configuration value"
complete -c git-shadow -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from $config_subcmds" -a set   -d "set a configuration value"
complete -c git-shadow -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from $config_subcmds" -a unset -d "remove a configuration value"

complete -c git-shadow -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from get set unset" -a "(__git_shadow_config_keys)" -d "config key"
complete -c git-shadow -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from show get list" -l json           -d "output as JSON"
complete -c git-shadow -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set unset"     -l project-config -d "save to project-level config (.git-shadow.env)"
complete -c git-shadow -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set unset"     -l user-config    -d "save to user-level config (~/.config/git-shadow/config.env)"

# ---------------------------------------------------------------------------
# status flags
# ---------------------------------------------------------------------------

complete -c git-shadow -n "__fish_seen_subcommand_from status" -l json -d "output as JSON"

# ---------------------------------------------------------------------------
# commit flags
# ---------------------------------------------------------------------------

complete -c git-shadow -n "__fish_seen_subcommand_from commit" -s m -r -d "commit message"

# ---------------------------------------------------------------------------
# completion subcommands
# ---------------------------------------------------------------------------

complete -c git-shadow -n "__fish_seen_subcommand_from completion; and not __fish_seen_subcommand_from install" -a install -d "install shell completion into your shell config"
