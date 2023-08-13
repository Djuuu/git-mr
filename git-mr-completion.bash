# See https://github.com/git/git/blob/master/contrib/completion/git-completion.bash

# bash completion support for git-mr
#
# Source this file in one of your shell startup scripts (e.g. .bashrc):
#
#   . "/path/to/git-mr/git-mr-completion.bash"
#
# Git completion is required.
#

__git-mr_commands() {
    __gitcomp_nl_append "$(
        cat <<-'ACTIONS'
		open
		status
		update
		menu
		ip
		cr
		qa
		ok
		undraft
		merge
		base
		code
		hook
		help
		ACTIONS
    )"
}

__git-mr_menu_commands() {
    __gitcomp_nl_append "$(
        cat <<-'ACTIONS'
		status
		update
		ACTIONS
    )"
}

__git-mr_branch_names() {
    __git_complete_refs --mode="heads"
}

_git_mr() {
    # Disable default bash completion (current directory file names, etc.)
    compopt +o bashdefault +o default 2>/dev/null

    # Parse current command words to get action context
    local mr_action="default" w
    for w in "${words[@]}"; do
        case $w in
            help | usage) mr_action="help" ;;
            open) mr_action="open" ;;
            status) [[ $mr_action == "menu" ]] && mr_action="menu-status" || mr_action="status" ;;
            update) [[ $mr_action == "menu" ]] && mr_action="menu-update" || mr_action="update" ;;
            merge) mr_action="merge" ;;
            menu) mr_action="menu" ;;
            ip | cr | qa | ok) mr_action="transition" ;;
            IP | CR | QA | OK) mr_action="transition" ;;
            undraft) mr_action="transition" ;;
            hook) mr_action="plumbing" ;;
            base) mr_action="plumbing" ;;
            code) mr_action="plumbing" ;;
        esac

        if [[ $w != "$cur" ]]; then
            case $w in
                op) mr_action="open" ;;
                st) [[ $mr_action == "menu" ]] && mr_action="menu-status" || mr_action="status" ;;
                up) [[ $mr_action == "menu" ]] && mr_action="menu-update" || mr_action="update" ;;
                mg) mr_action="merge" ;;
            esac
        fi
    done

    [[ $mr_action == "plumbing" ]] && return 0 # No more argument or option

    # Build options depending on action context
    if [[ $cur = -* ]]; then
        case $mr_action in default | open)
            __gitcomp_nl_append '-c'; __gitcomp_nl_append '--code'
        ;; esac
        case $mr_action in default | open | update)
            __gitcomp_nl_append '-t'; __gitcomp_nl_append '--target'
            __gitcomp_nl_append '-e'; __gitcomp_nl_append '--extended'
            __gitcomp_nl_append '--no-commits'
        ;; esac
        case $mr_action in default | open | status | menu-status)
            __gitcomp_nl_append '--no-color'
            __gitcomp_nl_append '--no-links'
        ;; esac
        case $mr_action in default | update | menu-update | transition | merge)
            __gitcomp_nl_append '-y'; __gitcomp_nl_append '--yes'
        ;; esac
        __gitcomp_nl_append '-v'; __gitcomp_nl_append '--verbose'

        case $mr_action in default)
            __gitcomp_nl_append '-h'
        ;; esac

        case $mr_action in update)
            __gitcomp_nl_append '-n'; __gitcomp_nl_append '--new-section'
            __gitcomp_nl_append '-r'; __gitcomp_nl_append '--replace-commits'
        ;; esac
        case $mr_action in menu-update)
            __gitcomp_nl_append '--current'
        ;; esac
        case $mr_action in merge)
            __gitcomp_nl_append '-f'; __gitcomp_nl_append '--force'
        ;; esac
        return
    fi

    if [[ $cur != -* ]]; then
        case $mr_action in
            default) __git-mr_commands ;;
            menu) __git-mr_menu_commands ;;
        esac
    fi

    # Options with values
    case "$prev" in
        -c | --code) return ;; # required argument
        -t | --target) __git-mr_branch_names; return ;;
    esac

    case $mr_action in
        default)
            [[ -n $cur ]] && case $cur in
                o|op|ope|open |\
                s|st|sta|stat|statu|status |\
                u|up|upd|upda|updat|update |\
                m|me|men|menu |\
                i|ip|c|cr|q|qa|ok |\
                un|und|undr|undra|undraf|undraft |\
                mer|merg|merge |\
                b|ba|bas|base |\
                co|cod|code |\
                h|ho|hoo|hook |\
                he|hel|help) ;;
                *) __git-mr_branch_names ;;
            esac
            ;;
        help | menu*) return ;; # no argument
        *) __git-mr_branch_names ;;
    esac
}

# Prevent classic sourcing on zsh
if [[ -n ${ZSH_VERSION-} && -z ${GIT_SOURCING_ZSH_COMPLETION-} ]]; then
    echo "zsh: add 'git-mr/completion' to your fpath instead of sourcing git-mr-completion.bash" 1>&2
    return
fi

# Load git completion if not loaded yet and available at usual paths
if ! declare -f __git_complete &>/dev/null; then
    if [[ -f "${HOME}/.local/share/bash-completion/completions/git" ]]; then
           . "${HOME}/.local/share/bash-completion/completions/git"
    elif [[ -f "/usr/share/bash-completion/completions/git" ]]; then
             . "/usr/share/bash-completion/completions/git"
    fi
fi

# Exit if git completion is still missing
if ! declare -f __git_complete &>/dev/null; then
    return
fi

# Add completion for direct script usage
__git_complete "git-mr" _git_mr

# Add completion for aliases
for a in $(alias -p | grep "git[- ]mr" | cut -d' ' -f2 | cut -d= -f1); do
    __git_complete "$a" _git_mr
done
