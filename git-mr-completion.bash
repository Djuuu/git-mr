# See https://github.com/git/git/blob/master/contrib/completion/git-completion.bash
_git_mr() {
    local isAnyAction
    local isMenu
    local isMenuStatus
    local isMenuUpdate
    local isMenuUpdateAll
    local isUpdate

    # Parse current command words to get context
    for w in "${words[@]}"; do
        case "$w" in
            open|status|update|merge|menu|ip|cr|qa|undraft|hook|base|code|help) isAnyAction=1 ;;
        esac
        [[ $w == "menu" ]] && isMenu=1
        if [[ -n "$isMenu" ]]; then
            [[ "$w" == "update" ]] && isMenuUpdate=1
            [[ "$w" == "status" ]] && isMenuStatus=1
            if [[ -n "$isMenuUpdate" ]]; then
                [[ "$w" == "--all" ]] && isMenuUpdateAll=1
            fi
        else
            [[ "$w" == "update" ]] && isUpdate=1
        fi
    done

    case "$prev" in
        # Options with values
        -t|--target) __git_complete_refs --mode="heads"; return ;;
        -c|--code)   COMPREPLY=();                       return ;;
        # Actions without additional argument or option
        hook|base|code) COMPREPLY=(); return ;;
    esac

    # Menu
    if [[ -n $isMenu ]]; then
        [[ -n $isMenuStatus ]] && return
        [[ -n $isMenuUpdateAll ]] && return
        [[ -n $isMenuUpdate ]] && __gitcomp "--all" && return
        __gitcomp "status update"
        return
    fi

    case "$cur" in
        --*)
            __gitcomp "--code --target"
            return
            ;;
        -*)
            __gitcomp "-c --code -e -t --target -v -y"
            [[ -n $isUpdate ]] && __gitcomp_nl_append "-n"
            return
            ;;
        *)
            __git_complete_refs --mode="heads"
            [[ -z $isAnyAction ]] && __gitcomp_nl_append "$(cat <<-'ACTIONS'
				open
				status
				update
				merge
				menu
				ip
				cr
				qa
				undraft
				hook
				base
				code
				help
				ACTIONS
)"
            return
            ;;
    esac
}


# Load git completion if not loaded yet and available at usual path
if ! declare -f __git_complete > /dev/null  && [ -f /usr/share/bash-completion/completions/git ]; then
    . /usr/share/bash-completion/completions/git
fi

if declare -f __git_complete > /dev/null; then
    # Add completion for direct script usage
    __git_complete "git-mr" _git_mr

    # Add completion for aliases
    for a in $(alias -p | grep "git[- ]mr" | cut -d' ' -f2 | cut -d= -f1); do
        __git_complete "$a" _git_mr
    done
fi
