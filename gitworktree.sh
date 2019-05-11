#!/bin/bash

##########################################################################################
#   
#   gitmaketree -  created by Jim Shaffer
#   to install:
#      > gitmaketree install [<alias_name>]
#   
#   to change to a different alias later, just change the function name in .bashrc
#   that looks like: 
#       gitmaketree() {
#   
##########################################################################################


install_in_bashrc () {

    bashrc="~/.bashrc"

    script_name=$(basename $0)
    echo "copying $0 to ~/.$script_name"
    \cp "$0" "~/.$script_name"
    error=$?; (( $error )) && echo "Error copying script. Exiting." && exit 1

    echo "creating alias cd=\'cd -P\'. This will force cd to switch to the absolute path"
    echo "of a symbolic link rather than appending the link to current path. We want this."
    echo "alias cd=\'cd -P\'  # force cd to actual physical path when following a symbolic link"
    echo
    echo "creating alias for ${gitmaketree_alias} => ~/.$script_name"
    echo "alias ${gitmaketree_alias}=\'~/.$script_name $1 $2 \'"
    echo
    echo "usage: $gitmaketree_alias <path_new_worktree>"
    echo "       A new branch will be created from the name of the last directory in <path_new_worktree>"
    echo
}

gitmaketree () {
    # 1) worktree add <path_new_worktree>  (this will also create a new branch)
    #    check proper usage, new worktree not in same directory, not on master, uncommitted/unstaged files
    # 2) make a symbolic link to the new worktree directory and add that to .gitignore
    # 3) make a symbolic link in the new worktree directory back to parent and add that to it's .gitignore
    # 4) copy_extra_stuff_path1/2 that creating a new worktree might not do
    # 5) cd to the new worktree (cd_to_new_worktree_at_end=1 #1=yes, 0=no)
    # note: must have this alias to work properly with the shortcuts: alias cd='cd -P'

    warn_if_uncommited_unstaged_files=1 #1=yes, 0=no
    warn_if_not_on_master=1             #1=yes, 0=no
    warn_if_in_current_dir_or_path=1    #1=yes, 0=no
    cd_to_new_worktree_at_end=1         #1=yes, 0=no
    copy_extra_stuff_path1=""
    copy_extra_stuff_path2=""

    if [[ -z $1 ]] || [[ -n $2 ]]; then
        echo "usage: gitmaketree_alias <path_new_worktree>"
        echo "       A new branch will be created from the name of the last directory in <path_new_worktree>"
        exit 1
    elif [[ $(git rev-parse --is-inside-work-tree 2>/dev/null) != "true" ]]; then
        echo "Not in a working repository. Exiting"
        exit 1
    else
        # WARNINGS
        rp=$(realpath "$1" 2>/dev/null); 
        if [[ -n $rp ]]; then 
            echo "New worktree absolute path: $rp"
        else 
            rp="$1"
            echo "New worktree path: $rp"
        fi
        if (( $warn_if_in_current_dir_or_path)) && ( ! [[ "$rp" =~ "/" ]] || [[ "$(pwd)" =~ "$rp" ]] ); then
            read -p "WARNING: Worktree path should not be inside the current directory or a sub-path. Continue [Y/N]? " reply1
            if ! [[ $reply1 =~ ^[Yy] ]]; then
                exit
            fi
        fi
        if (( $warn_if_not_on_master )) && [[ $(git rev-parse --abbrev-ref HEAD 2>/dev/null) != "master" ]]; then
            read -p "WARNING: Not on master branch or latest commit. Continue [Y/N]? " reply2
            if ! [[ $reply2 =~ ^[Yy] ]]; then
                exit
            fi
        fi
        if (( $warn_if_uncommited_unstaged_files )) && [[ $(git status --porcelain 2>/dev/null) ]]; then
            read -p "WARNING: Uncommitted or unstaged files exist. Continue [Y/N]? " reply3
            if ! [[ $reply3 =~ ^[Yy] ]]; then
                exit
            fi
        fi

        # CREATE WORKTREE
        branch_name=$(basename "$1")
        git worktree add "$1"
        error=$?; (( $error )) && echo "Error using git worktree add ${1}." && exit 1

        # CREATE BRANCH LINK AND ADD TO GITIGNORE
        worktree_absolute_path=$(realpath "$1")
        ln -sf "$worktree_absolute_path" "_$branch_name"
        error=$?
        if (( $error )); then
            echo "Error unable to create link _$branch_name"
        else
            if ! [[ -e .gitignore ]]; then
                # if it doesn't exist ignore itself
                touch .gitignore
                echo -e "\n.gitignore" >> .gitignore
                echo ".gitignore created. \".gitignore\" added to .gitignore"
            else
                echo ".gitignore already exists. \".gitignore\" NOT added to .gitignore"
            fi
            sed -i '/^${branch_name}$/d' .gitignore
            echo -e "\n_${branch_name}" >> .gitignore
            echo "\"_${branch_name}\" added to .gitignore"
        fi

        # CREATE PARENT LINK AND ADD TO GITIGNORE
        cwd=$(pwd)
        ln -sf "$cwd" "${worktree_absolute_path}/_parent"
        error=$?
        if (( $error )); then
            echo "Error unable to create link ${worktree_absolute_path}/_parent"
        else
            if ! [[ -e "${1}/.gitignore" ]]; then
                # if it doesn't exist ignore itself
                touch "${1}/.gitignore"
                echo -e "\n.gitignore" >> "${1}/.gitignore"
                echo "${1}/.gitignore created. \".gitignore\" added to ${1}/.gitignore"
            else
                echo "${1}/.gitignore already exists. \".gitignore\" NOT added to ${1}/.gitignore"
            fi
            sed -i '/^_parent$/d' "${1}/.gitignore"
            echo -e "\n_parent" >> "${1}/.gitignore"
            echo "\"_parent\" added to ${1}/.gitignore"
        fi

        # COPY EXTRA STUFF
        if [[ -n $copy_extra_stuff_path1 ]]; then
            \cp "$copy_extra_stuff_path1" "$1"
            error=$?; (( $error )) && echo "Error unable to copy $copy_extra_stuff_path1 to $1"
        fi
        if [[ -n $copy_extra_stuff_path2 ]]; then
            \cp "$copy_extra_stuff_path2" "$1"
            error=$?; (( $error )) && echo "Error unable to copy $copy_extra_stuff_path2 to $1"
        fi

        # SWITCH TO NEW WORKTREE
        if (( $cd_to_new_worktree_at_end )); then
            echo "switching to $worktree_absolute_path (absolute path for: ${1})"
            cd "$worktree_absolute_path"
        fi
    fi
}

##########################################################################################
#   
#  Start Here
#   
##########################################################################################

cat <<'EOF'
                 ,@@@@@@@,
         ,,,.   ,@@@@@@/@@,  .oo8888o.
      ,&%%&%&&%,@@@@@/@@@@@@,8888\88/8o
     ,%&\%&&%&&%,@@@\@@@/@@@88\88888/88'
     %&&%&%&/%&&%@@\@@/ /@@@88888\88888'
     %&&%/ %&%%&&@@\ V /@@' `88\8 `/88'
     `&%\ ` /%&'    |.|        \ '|8'
         |o|        | |         | |
         |.|        | |         | |
  jgs \\/ ._\//_/__/  ,\_//__\\/.  \_//__/_

EOF
# https://asciiart.website/index.php?art=plants/trees

if [[ -z $1 ]] || [[ $1 == "-h" ]]; then
    echo "usage: gitmaketree_alias <path_new_worktree>"
    echo "       A new branch will be created from the name of the last directory in <path_new_worktree>."
    echo "       If trying to install into .bashrc, use $0 install [desired_alias]"
elif [[ $1 == "install" ]]; then
    if [[ -n $2 ]]; then
        gitmaketree_alias="$2"
    else
        gitmaketree_alias="gitmaketree"
    fi
    install_in_bashrc
else
    gitmaketree $1 $2
fi

