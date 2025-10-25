#!/bin/zsh

# Git Worktree Helper Script for oh-my-zsh (Lazy Loading)
# Generic version for multi-repository worktree workflows
# Place this file in ~/.oh-my-zsh/custom/ and customize the configuration

# =============================================================================
# CONFIGURATION - Loaded from external config file
# =============================================================================

# Configuration will be loaded from ~/.config/worktree-tools/config.zsh
# If not found, defaults below will be used

# Default configuration variables
GIT_USERNAME="${USER}"
BRANCH_PREFIX="${USER}"
BASE_DEV_PATH="$HOME/dev"
BARE_REPOS_PATH="$BASE_DEV_PATH/.repos"
WORKTREES_PATH="$BASE_DEV_PATH/worktrees"
WORKTREE_TEMPLATES_PATH="$BASE_DEV_PATH/worktree_templates"

# Default configuration (used as fallback)
_load_default_worktree_config() {
    # Initialize array if not already declared
    [[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
    # Your git username and branch prefix
    GIT_USERNAME="${USER}"
    BRANCH_PREFIX="${USER}"

    # Base paths for your development setup
    BASE_DEV_PATH="$HOME/dev"
    BARE_REPOS_PATH="$BASE_DEV_PATH/.repos"
    WORKTREES_PATH="$BASE_DEV_PATH/worktrees"
    WORKTREE_TEMPLATES_PATH="$BASE_DEV_PATH/worktree_templates"

    # Repository shorthand mappings
    # Format: shorthand => full-repo-name
    REPO_MAPPINGS[webapp]="MyApp-WebApp"
    REPO_MAPPINGS[api]="MyApp-API"
    REPO_MAPPINGS[mobile]="MyApp-Mobile"
    REPO_MAPPINGS[lib]="MyApp-Library"
}

# =============================================================================
# IMPLEMENTATION
# =============================================================================

# Flag to track if implementation has been loaded
_git_worktree_loaded=false

# Load configuration from external file
_load_worktree_config() {
    # Initialize array ONLY if not already declared
    [[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS

    local config_file="$HOME/.config/worktree-tools/config.zsh"

    if [[ -f "$config_file" ]]; then
        source "$config_file"
    else
        # Use default configuration
        _load_default_worktree_config
    fi
}

# Lazy loading function
_load_git_worktree_impl() {
    if [[ $_git_worktree_loaded == false ]]; then
        # Load configuration first
        _load_worktree_config
        # Define all the implementation functions
        _define_git_worktree_functions
        _git_worktree_loaded=true
    fi
}

# Define all the implementation functions
_define_git_worktree_functions() {

    # Function to detect current repository from configured mappings
    detect_current_repo() {
        local current_dir=$(pwd)
        local repo_name=""

        # Check each configured repo against current path
        for repo in ${(v)REPO_MAPPINGS[@]}; do
            if [[ $current_dir == *"$repo"* ]]; then
                repo_name="$repo"
                break
            fi
        done

        echo $repo_name
    }

    # Function to resolve repo shorthand to full name
    resolve_repo_name() {
        local shorthand=$1

        # Check if shorthand exists in mappings
        if [[ -n ${REPO_MAPPINGS[$shorthand]} ]]; then
            echo ${REPO_MAPPINGS[$shorthand]}
        else
            # Try to detect from current directory
            local detected_repo=$(detect_current_repo)
            if [[ -n $detected_repo ]]; then
                echo $detected_repo
            else
                echo "❌ Unknown repository shorthand: '$shorthand'"
                echo "Available configured repositories:"
                for repo_short repo_full in ${(kv)REPO_MAPPINGS[@]}; do
                    echo "  $repo_short -> $repo_full"
                done
                echo "Or run from within a configured repository directory"
                return 1
            fi
        fi
    }

    # Function to get nested directory name for a repo (if configured)
    get_nested_dir_name() {
        local repo_identifier=$1  # Can be shorthand or full repo name

        # Initialize REPO_NESTED_WORKTREES if not declared
        [[ -z ${(t)REPO_NESTED_WORKTREES} ]] && declare -gA REPO_NESTED_WORKTREES

        # Try shorthand first, then full repo name
        if [[ -n ${REPO_NESTED_WORKTREES[$repo_identifier]} ]]; then
            echo ${REPO_NESTED_WORKTREES[$repo_identifier]}
        else
            echo ""
        fi
    }

    # Function to resolve the actual worktree path (handles nested structure)
    # Returns: outer_path|inner_path
    # If not nested: returns path|path (same path for both)
    resolve_worktree_paths() {
        local repo_name=$1
        local branch_name=$2
        local repo_shorthand=$3  # Optional: if provided, check nested config by shorthand

        local outer_path="$WORKTREES_PATH/$repo_name-$branch_name"
        local nested_dir=""

        # Check both shorthand and full repo name for nested config
        if [[ -n $repo_shorthand ]]; then
            nested_dir=$(get_nested_dir_name "$repo_shorthand")
        fi
        if [[ -z $nested_dir ]]; then
            nested_dir=$(get_nested_dir_name "$repo_name")
        fi

        if [[ -n $nested_dir ]]; then
            # Nested structure: outer_path/nested_dir
            echo "$outer_path|$outer_path/$nested_dir"
        else
            # Regular structure: outer_path is the worktree
            echo "$outer_path|$outer_path"
        fi
    }

    # Function to add a new worktree
    add_worktree() {
        local first_arg=$1
        local second_arg=$2

        # Determine if first arg is repo shorthand or branch name
        local repo_shorthand=""
        local branch_name=""

        # Check if first arg is a known repo shorthand
        if [[ -n ${REPO_MAPPINGS[$first_arg]} ]]; then
            repo_shorthand=$first_arg
            branch_name=$second_arg
        else
            # First arg is not a known shorthand, treat it as branch name
            # and try to detect repo from current directory
            local detected_repo=$(detect_current_repo)
            if [[ -n $detected_repo ]]; then
                repo_shorthand=$detected_repo
                branch_name=$first_arg
            else
                local current_dir=$(pwd)
                echo "❌ Error: Could not recognize repository from current directory: $current_dir"
                echo "Either provide a repository shorthand or run from within a configured repository directory"
                echo "Available configured repositories:"
                for repo_short repo_full in ${(kv)REPO_MAPPINGS[@]}; do
                    echo "  $repo_short -> $repo_full"
                done
                return 1
            fi
        fi

        if [[ -z $branch_name ]]; then
            echo "❌ Error: Branch name is required"
            echo "Usage: add-wt [<repo>] <branch-name>"
            echo "Available repos: ${(k)REPO_MAPPINGS[@]}"
            return 1
        fi

        # Check for "/" character in branch name (only if using a prefix)
        if [[ -n $BRANCH_PREFIX && $branch_name == *"/"* ]]; then
            echo "❌ Error: Branch name cannot contain '/' character when using a branch prefix"
            echo "The branch prefix '$BRANCH_PREFIX' will be prepended to your branch name"
            echo "Your final branch will be: $BRANCH_PREFIX/$branch_name"
            return 1
        fi

        local repo_name=$(resolve_repo_name $repo_shorthand)
        if [[ $? -ne 0 ]]; then
            return 1
        fi

        local bare_repo_path="$BARE_REPOS_PATH/$repo_name.git"

        # Resolve worktree paths (handles nested structure)
        local paths=$(resolve_worktree_paths "$repo_name" "$branch_name" "$repo_shorthand")
        local outer_path="${paths%%|*}"
        local inner_path="${paths##*|}"

        # Check if bare repo exists
        if [[ ! -d $bare_repo_path ]]; then
            echo "❌ Error: Bare repository not found at $bare_repo_path"
            echo "Please ensure your bare repositories are set up in $BARE_REPOS_PATH/"
            return 1
        fi

        # Check if worktree already exists
        if [[ -d $outer_path ]]; then
            echo "❌ Error: Worktree already exists at $outer_path"
            return 1
        fi

        # Create outer directory structure for nested worktrees
        if [[ "$outer_path" != "$inner_path" ]]; then
            mkdir -p "$outer_path"
        else
            mkdir -p "$(dirname "$outer_path")"
        fi

        # Prefix branch with branch prefix (if configured)
        local prefixed_branch
        if [[ -n $BRANCH_PREFIX ]]; then
            prefixed_branch="$BRANCH_PREFIX/$branch_name"
        else
            prefixed_branch="$branch_name"
        fi

        echo "🌳 Creating worktree for $repo_name..."
        echo "📁 Bare repo: $bare_repo_path"
        echo "🌿 Branch: $prefixed_branch"
        if [[ "$outer_path" != "$inner_path" ]]; then
            echo "📂 Worktree (outer): $outer_path"
            echo "📂 Worktree (inner): $inner_path"
        else
            echo "📂 Worktree: $inner_path"
        fi

        # Check if remote branch exists
        local remote_branch="origin/$prefixed_branch"
        local branch_exists_remotely=false
        
        # Check if remote branch exists
        if git -C "$bare_repo_path" show-ref --verify --quiet "refs/remotes/$remote_branch"; then
            branch_exists_remotely=true
            echo "📡 Found remote branch: $remote_branch"
        else
            echo "🆕 No remote branch found, creating new local branch"
        fi

        # Create the worktree
        if [[ $branch_exists_remotely == true ]]; then
            # Create worktree tracking the remote branch
            echo "🔗 Creating worktree with tracking to $remote_branch"
            git -C "$bare_repo_path" worktree add "$inner_path" -b "$prefixed_branch" --track "$remote_branch"
        else
            # Check if local branch already exists
            if git -C "$bare_repo_path" show-ref --verify --quiet "refs/heads/$prefixed_branch"; then
                echo "📝 Local branch '$prefixed_branch' already exists, using existing branch"
                git -C "$bare_repo_path" worktree add "$inner_path" "$prefixed_branch"
            else
                # Create worktree with new local branch based on main/master/develop
                local main_branch="main"
                if git -C "$bare_repo_path" show-ref --verify --quiet "refs/remotes/origin/master"; then
                    main_branch="master"
                elif git -C "$bare_repo_path" show-ref --verify --quiet "refs/remotes/origin/develop"; then
                    main_branch="develop"
                fi
                echo "🌱 Creating worktree with new local branch from origin/$main_branch"
                git -C "$bare_repo_path" worktree add "$inner_path" -b "$prefixed_branch" "origin/$main_branch"
            fi
        fi
        
        if [[ $? -eq 0 ]]; then
            echo -e "\033[32m✅ SUCCESS\033[0m"
            if [[ "$outer_path" != "$inner_path" ]]; then
                echo "📂 Worktree created at: $outer_path"
                echo "   └─ Git worktree: $inner_path"
            else
                echo "📂 Worktree created at: $inner_path"
            fi
            if [[ $branch_exists_remotely == true ]]; then
                echo "🔗 Branch is tracking: $remote_branch"
            fi

            # Copy templates to the new worktree
            copy_templates "$repo_name" "$inner_path" "$repo_shorthand"

            echo "📂 Switching to: $inner_path"
            echo "WORKTREE_CD_TARGET:$inner_path"
        else
            echo -e "\033[31m❌ FAILED\033[0m"
            return 1
        fi
    }

    # Function to copy templates to worktree
    copy_templates() {
        local repo_name=$1
        local worktree_path=$2
        local repo_shorthand=$3  # Optional, not currently used
        
        local template_dir="$WORKTREE_TEMPLATES_PATH/$repo_name"
        
        if [[ ! -d $template_dir ]]; then
            echo "ℹ️  No templates found at $template_dir"
            return 0
        fi
        
        echo "📋 Copying templates from $template_dir..."
        
        # Copy everything from template directory including hidden files
        if [[ -n "$(ls -A "$template_dir" 2>/dev/null)" ]]; then
            # Enable dotglob to include hidden files in glob expansion
            setopt local_options dotglob
            if cp -r "$template_dir"/* "$worktree_path/"; then
                echo "✅ Templates copied successfully"
            else
                echo "⚠️  Warning: Some template files may not have been copied (check permissions)"
                return 1
            fi
        else
            echo "ℹ️  Template directory is empty"
        fi
    }

    # Function to list worktrees
    list_worktrees() {
        local repo_shorthand=$1

        # If no argument provided, try to detect from current directory
        if [[ -z $repo_shorthand ]]; then
            local detected_repo=$(detect_current_repo)
            if [[ -n $detected_repo ]]; then
                repo_shorthand=$detected_repo
            else
                local current_dir=$(pwd)
                echo "❌ Error: Could not recognize repository from current directory: $current_dir"
                echo "Either provide a repository shorthand or run from within a configured repository directory"
                echo "Available configured repositories:"
                for repo_short repo_full in ${(kv)REPO_MAPPINGS[@]}; do
                    echo "  $repo_short -> $repo_full"
                done
                return 1
            fi
        fi

        local repo_name=$(resolve_repo_name $repo_shorthand)
        if [[ $? -ne 0 ]]; then
            return 1
        fi

        local bare_repo_path="$BARE_REPOS_PATH/$repo_name.git"

        # Check if bare repo exists
        if [[ ! -d $bare_repo_path ]]; then
            echo "❌ Error: Bare repository not found at $bare_repo_path"
            echo "Please ensure your bare repositories are set up in $BARE_REPOS_PATH/"
            return 1
        fi

        echo "📋 Worktrees for $repo_name:"

        # Resolve WORKTREES_PATH to canonical path for comparison (handles symlinks like /var -> /private/var on macOS)
        local canonical_worktrees_path
        if [[ -d "$WORKTREES_PATH" ]]; then
            canonical_worktrees_path=$(cd "$WORKTREES_PATH" && pwd -P)
        else
            # If directory doesn't exist yet, resolve parent and append last component
            canonical_worktrees_path="$WORKTREES_PATH"
        fi

        # Get worktree list and format it nicely
        local worktree_list=$(git -C "$bare_repo_path" worktree list --porcelain)
        local first_worktree=""
        local current_worktree=""
        local current_branch=""

        while IFS= read -r line; do
            if [[ $line == worktree* ]]; then
                current_worktree=${line#worktree }
            elif [[ $line == branch* ]]; then
                current_branch=${line#branch refs/heads/}

                # Only show worktrees that are in our worktrees path (use canonical path comparison)
                if [[ $current_worktree == $canonical_worktrees_path* ]] || [[ $current_worktree == $WORKTREES_PATH* ]]; then
                    # For nested worktrees, current_worktree might be like:
                    # /path/worktrees/Repo-branch/Repo (inner)
                    # We want to display: Repo-branch (outer)

                    local display_path="$current_worktree"
                    local parent_dir=$(dirname "$current_worktree")
                    local inner_dir_name=$(basename "$current_worktree")

                    # Check if this might be a nested worktree
                    # If parent is in WORKTREES_PATH and inner name matches repo, use parent
                    if [[ ($parent_dir == $canonical_worktrees_path* || $parent_dir == $WORKTREES_PATH*) &&
                          $inner_dir_name == $repo_name ]]; then
                        display_path="$parent_dir"
                    fi

                    local worktree_name=$(basename "$display_path")
                    echo "  $worktree_name ($current_branch)"

                    # Remember first worktree for cd
                    if [[ -z $first_worktree ]]; then
                        first_worktree=$current_worktree
                    fi
                fi
            fi
        done <<< "$worktree_list"

        # Silently cd to first worktree if found
        if [[ -n $first_worktree ]]; then
            echo "WORKTREE_CD_TARGET:$first_worktree"
        fi
    }

    # Function to switch to a worktree
    switch_worktree() {
        local first_arg=$1
        local second_arg=$2

        # Determine if first arg is repo shorthand or search string
        local repo_shorthand=""
        local search_string=""

        # Check if first arg is a known repo shorthand
        if [[ -n ${REPO_MAPPINGS[$first_arg]} ]]; then
            repo_shorthand=$first_arg
            search_string=$second_arg
        else
            # First arg is not a known shorthand, treat it as search string
            # and try to detect repo from current directory
            local detected_repo=$(detect_current_repo)
            if [[ -n $detected_repo ]]; then
                repo_shorthand=$detected_repo
                search_string=$first_arg
            else
                local current_dir=$(pwd)
                echo "❌ Error: Could not recognize repository from current directory: $current_dir"
                echo "Either provide a repository shorthand or run from within a configured repository directory"
                echo "Available configured repositories:"
                for repo_short repo_full in ${(kv)REPO_MAPPINGS[@]}; do
                    echo "  $repo_short -> $repo_full"
                done
                return 1
            fi
        fi

        if [[ -z $search_string ]]; then
            echo "❌ Error: Search string is required"
            echo "Usage: switch-wt [<repo>] <search-string>"
            echo "Available repos: ${(k)REPO_MAPPINGS[@]}"
            return 1
        fi

        local repo_name=$(resolve_repo_name $repo_shorthand)
        if [[ $? -ne 0 ]]; then
            return 1
        fi

        local bare_repo_path="$BARE_REPOS_PATH/$repo_name.git"

        # Check if bare repo exists
        if [[ ! -d $bare_repo_path ]]; then
            echo "❌ Error: Bare repository not found at $bare_repo_path"
            echo "Please ensure your bare repositories are set up in $BARE_REPOS_PATH/"
            return 1
        fi

        echo "🔍 Searching for worktrees matching '$search_string' in $repo_name..."

        # Resolve WORKTREES_PATH to canonical path for comparison
        local canonical_worktrees_path
        if [[ -d "$WORKTREES_PATH" ]]; then
            canonical_worktrees_path=$(cd "$WORKTREES_PATH" && pwd -P)
        else
            canonical_worktrees_path="$WORKTREES_PATH"
        fi

        # Get worktree list and find matches
        local worktree_list=$(git -C "$bare_repo_path" worktree list --porcelain)
        local matching_worktree=""
        local current_worktree=""
        local current_branch=""

        # Parse worktree list to find matches
        while IFS= read -r line; do
            if [[ $line == worktree* ]]; then
                current_worktree=${line#worktree }
            elif [[ $line == branch* ]]; then
                current_branch=${line#branch refs/heads/}
                # Only consider worktrees in our WORKTREES_PATH and check if branch matches
                if [[ $current_worktree == $canonical_worktrees_path* ]] || [[ $current_worktree == $WORKTREES_PATH* ]]; then
                    if [[ ${current_branch:l} == *${search_string:l}* ]]; then
                        matching_worktree=$current_worktree
                        break
                    fi
                fi
            fi
        done <<< "$worktree_list"

        if [[ -n $matching_worktree ]]; then
            echo "🎯 Found matching worktree: $current_branch"
            echo "📂 Switching to: $matching_worktree"
            echo "WORKTREE_CD_TARGET:$matching_worktree"
        else
            echo "❌ No worktrees found matching '$search_string'"
            echo "📋 Available worktrees for $repo_name:"
            git -C "$bare_repo_path" worktree list
        fi
    }

    # Function to remove a worktree
    remove_worktree() {
        local first_arg=$1
        local second_arg=$2

        # Determine if first arg is repo shorthand or worktree name
        local repo_shorthand=""
        local worktree_name=""

        # Check if first arg is a known repo shorthand
        if [[ -n ${REPO_MAPPINGS[$first_arg]} ]]; then
            repo_shorthand=$first_arg
            worktree_name=$second_arg
        else
            # First arg is not a known shorthand, treat it as worktree name
            # and try to detect repo from current directory
            local detected_repo=$(detect_current_repo)
            if [[ -n $detected_repo ]]; then
                repo_shorthand=$detected_repo
                worktree_name=$first_arg
            else
                local current_dir=$(pwd)
                echo "❌ Error: Could not recognize repository from current directory: $current_dir"
                echo "Either provide a repository shorthand or run from within a configured repository directory"
                echo "Available configured repositories:"
                for repo_short repo_full in ${(kv)REPO_MAPPINGS[@]}; do
                    echo "  $repo_short -> $repo_full"
                done
                return 1
            fi
        fi

        if [[ -z $worktree_name ]]; then
            echo "❌ Error: Worktree name is required"
            echo "Usage: wt-rm [<repo>] <worktree-name>"
            echo "Available repos: ${(k)REPO_MAPPINGS[@]}"
            return 1
        fi

        local repo_name=$(resolve_repo_name $repo_shorthand)
        if [[ $? -ne 0 ]]; then
            return 1
        fi

        local bare_repo_path="$BARE_REPOS_PATH/$repo_name.git"

        # Check if bare repo exists
        if [[ ! -d $bare_repo_path ]]; then
            echo "❌ Error: Bare repository not found at $bare_repo_path"
            echo "Please ensure your bare repositories are set up in $BARE_REPOS_PATH/"
            return 1
        fi

        echo "🔍 Looking for worktree '$worktree_name' in $repo_name..."

        # Resolve WORKTREES_PATH to canonical path for comparison
        local canonical_worktrees_path
        if [[ -d "$WORKTREES_PATH" ]]; then
            canonical_worktrees_path=$(cd "$WORKTREES_PATH" && pwd -P)
        else
            canonical_worktrees_path="$WORKTREES_PATH"
        fi

        # Find the exact worktree match
        local worktree_list=$(git -C "$bare_repo_path" worktree list --porcelain)
        local target_worktree=""
        local current_worktree=""
        local outer_dir=""

        while IFS= read -r line; do
            if [[ $line == worktree* ]]; then
                current_worktree=${line#worktree }
                # Check if this worktree is in our worktrees path (canonical path comparison)
                if [[ $current_worktree == $canonical_worktrees_path* ]] || [[ $current_worktree == $WORKTREES_PATH* ]]; then
                    # Check for nested structure
                    local parent_dir=$(dirname "$current_worktree")
                    local inner_dir_name=$(basename "$current_worktree")
                    local check_name=""

                    # If nested (parent is in WORKTREES_PATH and inner name matches repo)
                    if [[ ($parent_dir == $canonical_worktrees_path* || $parent_dir == $WORKTREES_PATH*) &&
                          $inner_dir_name == $repo_name ]]; then
                        check_name=$(basename "$parent_dir")
                        outer_dir="$parent_dir"
                    else
                        check_name=$(basename "$current_worktree")
                        outer_dir=""
                    fi

                    if [[ $check_name == $worktree_name ]]; then
                        target_worktree=$current_worktree
                        break
                    fi
                fi
            fi
        done <<< "$worktree_list"

        if [[ -n $target_worktree ]]; then
            echo "🗑️  Found worktree: $target_worktree"

            # Check if we're currently in the worktree we want to remove
            local current_dir=$(pwd)
            local check_dir="$target_worktree"
            if [[ -n $outer_dir ]]; then
                check_dir="$outer_dir"
            fi

            if [[ $current_dir == $check_dir* ]]; then
                echo "❌ Error: Cannot remove worktree while you are inside it"
                echo "📂 Current directory: $current_dir"
                if [[ -n $outer_dir ]]; then
                    echo "🗑️  Target worktree: $outer_dir"
                else
                    echo "🗑️  Target worktree: $target_worktree"
                fi
                echo "💡 Please navigate outside this worktree first, then try again"
                return 1
            fi

            echo "🗑️  Removing worktree: $target_worktree"
            git -C "$bare_repo_path" worktree remove "$target_worktree"

            if [[ $? -eq 0 ]]; then
                # If nested structure, also remove outer directory if empty
                if [[ -n $outer_dir && -d $outer_dir ]]; then
                    if [[ -z "$(ls -A "$outer_dir" 2>/dev/null)" ]]; then
                        rmdir "$outer_dir"
                        echo "✅ Worktree and outer directory removed successfully"
                    else
                        echo "✅ Worktree removed successfully (outer directory not empty)"
                    fi
                else
                    echo "✅ Worktree removed successfully"
                fi
            else
                echo "❌ Failed to remove worktree"
                return 1
            fi
        else
            echo "❌ No worktree found with name '$worktree_name'"
            echo "📋 Available worktrees for $repo_name:"

            # Show available worktrees
            while IFS= read -r line; do
                if [[ $line == worktree* ]]; then
                    current_worktree=${line#worktree }
                    if [[ $current_worktree == $canonical_worktrees_path* ]] || [[ $current_worktree == $WORKTREES_PATH* ]]; then
                        # Check for nested structure
                        local parent_dir=$(dirname "$current_worktree")
                        local inner_dir_name=$(basename "$current_worktree")
                        local display_name=""

                        if [[ ($parent_dir == $canonical_worktrees_path* || $parent_dir == $WORKTREES_PATH*) &&
                              $inner_dir_name == $repo_name ]]; then
                            display_name=$(basename "$parent_dir")
                        else
                            display_name=$(basename "$current_worktree")
                        fi

                        echo "  $display_name"
                    fi
                fi
            done <<< "$worktree_list"
        fi
    }

    # Function to save current worktree files to template
    template_save() {
        local repo_shorthand=$1

        # If no argument provided, try to detect from current directory
        if [[ -z $repo_shorthand ]]; then
            local detected_repo=$(detect_current_repo)
            if [[ -n $detected_repo ]]; then
                repo_shorthand=$detected_repo
            else
                local current_dir=$(pwd)
                echo "❌ Error: Could not recognize repository from current directory: $current_dir"
                echo "Either provide a repository shorthand or run from within a configured repository directory"
                echo "Available configured repositories:"
                for repo_short repo_full in ${(kv)REPO_MAPPINGS[@]}; do
                    echo "  $repo_short -> $repo_full"
                done
                return 1
            fi
        fi

        local repo_name=$(resolve_repo_name $repo_shorthand)
        if [[ $? -ne 0 ]]; then
            return 1
        fi

        local template_dir="$WORKTREE_TEMPLATES_PATH/$repo_name"
        local current_dir=$(pwd)

        echo "💾 Saving current worktree files to template for $repo_name..."
        echo "📁 Template directory: $template_dir"

        # Check if template directory exists
        if [[ ! -d "$template_dir" ]]; then
            echo "❌ Error: Template directory does not exist at $template_dir"
            echo "💡 Create the template directory first and add files you want to track"
            return 1
        fi

        local files_copied=0

        # Find all files in template directory recursively (including hidden files/folders)
        while IFS= read -r -d '' template_file; do
            # Get relative path from template directory
            local rel_path="${template_file#$template_dir/}"
            local worktree_file="$current_dir/$rel_path"
            
            # Skip if it's a directory
            [[ -d "$template_file" ]] && continue
            
            if [[ -f "$worktree_file" ]]; then
                # Copy the file directly (directory structure already exists in template)
                cp "$worktree_file" "$template_file"
                echo "📄 Copied: $rel_path"
                ((files_copied++))
            else
                echo "⚠️  Not found in worktree: $rel_path"
            fi
        done < <(find "$template_dir" -type f -print0)

        if (( files_copied > 0 )); then
            echo "✅ Saved $files_copied files to template"
        else
            echo "ℹ️  No matching files found to save"
        fi

        echo "💾 Template save completed for $repo_name"
    }

    # Function to load template files to current worktree
    template_load() {
        local repo_shorthand=$1

        # If no argument provided, try to detect from current directory
        if [[ -z $repo_shorthand ]]; then
            local detected_repo=$(detect_current_repo)
            if [[ -n $detected_repo ]]; then
                repo_shorthand=$detected_repo
            else
                local current_dir=$(pwd)
                echo "❌ Error: Could not recognize repository from current directory: $current_dir"
                echo "Either provide a repository shorthand or run from within a configured repository directory"
                echo "Available configured repositories:"
                for repo_short repo_full in ${(kv)REPO_MAPPINGS[@]}; do
                    echo "  $repo_short -> $repo_full"
                done
                return 1
            fi
        fi

        local repo_name=$(resolve_repo_name $repo_shorthand)
        if [[ $? -ne 0 ]]; then
            return 1
        fi

        local template_dir="$WORKTREE_TEMPLATES_PATH/$repo_name"
        local current_dir=$(pwd)

        if [[ ! -d $template_dir ]]; then
            echo "❌ Error: No template found for $repo_name at $template_dir"
            echo "Use 'wt-template-save' to create a template first"
            return 1
        fi

        echo "📥 Loading template files to current worktree for $repo_name..."
        echo "📁 Template directory: $template_dir"

        # Copy everything from template directory including hidden files
        if [[ -n "$(ls -A "$template_dir" 2>/dev/null)" ]]; then
            # Enable dotglob to include hidden files in glob expansion
            setopt local_options dotglob
            if cp -r "$template_dir"/* "$current_dir/"; then
                echo "✅ Template files loaded successfully"
            else
                echo "❌ Error: Failed to copy template files (check permissions)"
                return 1
            fi
        else
            echo "ℹ️  Template directory is empty"
        fi

        echo "📥 Template load completed for $repo_name"
    }

    # Function to show help
    show_worktree_help() {
        echo "Git Worktree Helper Commands:"
        echo ""
        echo "  wt-add [<repo>] <branch-name>  - Create a new worktree"
        echo "  wt-list [<repo>]               - List worktrees for repository"
        echo "  wt-switch [<repo>] <search>    - Switch to worktree matching search string"
        echo "  wt-rm [<repo>] <worktree-name> - Remove a specific worktree"
        echo "  wt-template-save [<repo>]      - Save current template files"
        echo "  wt-template-load [<repo>]      - Load template files"
        echo ""
        echo "Repository shorthands (optional for most commands if running from repo directory):"
        for key value in ${(kv)REPO_MAPPINGS[@]}; do
            printf "  %-8s - %s\n" "$key" "$value"
        done
        echo ""
        echo "Examples:"
        echo "  wt-add webapp feature-branch   # Create worktree with explicit repo"
        echo "  wt-add feature-branch          # Create worktree, auto-detect repo"
        echo "  wt-list webapp                 # List worktrees for webapp"
        echo "  wt-list                        # List worktrees for current repo"
        echo "  wt-switch webapp feature       # Switch to first worktree containing 'feature'"
        echo "  wt-switch dev                  # Switch to first worktree containing 'dev' in current repo"
        echo "  wt-rm webapp testme            # Remove 'testme' worktree from webapp repo"
        echo "  wt-rm old-feature              # Remove 'old-feature' worktree from current repo"
        echo "  wt-template-save               # Save current worktree's template files"
        echo "  wt-template-load webapp        # Load template files from webapp template"
        echo ""
        echo "Configuration:"
        echo "  Git Username: $GIT_USERNAME"
        if [[ -n $BRANCH_PREFIX ]]; then
            echo "  Branch Prefix: $BRANCH_PREFIX (branches created as: $BRANCH_PREFIX/branch-name)"
        else
            echo "  Branch Prefix: (none - branches created without prefix)"
        fi
        echo "  Bare repos: $BARE_REPOS_PATH"
        echo "  Worktrees: $WORKTREES_PATH"
        echo "  Templates: $WORKTREE_TEMPLATES_PATH"
    }
}

# Lightweight wrapper functions that use lazy loading
git_worktree() {
    _load_git_worktree_impl
    case $1 in
        "add"|"add-wt")
            add_worktree $2 $3
            ;;
        "list"|"list-wt")
            list_worktrees $2
            ;;
        "switch"|"switch-wt")
            switch_worktree $2 $3
            ;;
        "rm"|"remove")
            remove_worktree $2 $3
            ;;
        "template-save")
            template_save $2
            ;;
        "template-load")
            template_load $2
            ;;
        "help"|"-h"|"--help")
            show_worktree_help
            ;;
        *)
            echo "❌ Unknown command: $1"
            echo "Use 'git_worktree help' for available commands"
            return 1
            ;;
    esac
}

# Helper function to execute worktree commands and handle directory changes
_exec_worktree_command() {
    local output=$(git_worktree "$@")
    
    # Extract and handle CD target first
    local cd_target=$(echo "$output" | grep "^WORKTREE_CD_TARGET:" | cut -d: -f2-)
    
    # Display output WITHOUT the WORKTREE_CD_TARGET line
    echo "$output" | grep -v "^WORKTREE_CD_TARGET:"
    
    # Change directory silently
    if [[ -n $cd_target ]]; then
        cd "$cd_target"
    fi
}

# Create aliases for easier access
alias wt-add='_exec_worktree_command add'
alias wt-list='_exec_worktree_command list'
alias wt-switch='_exec_worktree_command switch'
alias wt-rm='_exec_worktree_command rm'
alias wt-template-save='git_worktree template-save'
alias wt-template-load='git_worktree template-load'