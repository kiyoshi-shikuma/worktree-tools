#!/bin/zsh

# CI/Lint Helper Script for oh-my-zsh (Lazy Loading)
# Generic version for multi-repository development workflows
# Place this file in ~/.oh-my-zsh/custom/ and customize the configuration

# =============================================================================
# CONFIGURATION - Loaded from external config file
# =============================================================================

# Configuration will be loaded from ~/.config/worktree-tools/config.zsh
# If not found, defaults below will be used
# Note: Arrays are initialized in _load_ci_config to avoid redeclaration issues

# Default configuration (used as fallback)
_load_default_config() {
    # Initialize arrays if not already done
    [[ -z ${(t)REPO_CONFIGS} ]] && declare -gA REPO_CONFIGS
    [[ -z ${(t)REPO_MODULES} ]] && declare -gA REPO_MODULES
    
    # Define your repositories and their CI commands
    # Format: REPO_NAME => "build_cmd|test_cmd|lint_cmd"
    REPO_CONFIGS[MyApp-Android]="./gradlew assembleDebug|./gradlew testDebugUnitTest|./gradlew lintDebug detekt"
    REPO_CONFIGS[MyApp-iOS]="bundle exec fastlane build|bundle exec fastlane unit_tests|swiftlint --strict && swiftformat . --lint --strict"

    # Define modular components (optional)
    # Format: REPO_NAME => "module1 module2"
    REPO_MODULES[MyApp-Android]="core-module feature-module"
}

# =============================================================================
# IMPLEMENTATION
# =============================================================================

# Flag to track if implementation has been loaded
_ci_helper_loaded=false

# Load configuration from external file
_load_ci_config() {
    # Initialize associative arrays ONLY if not already declared
    [[ -z ${(t)REPO_CONFIGS} ]] && declare -gA REPO_CONFIGS
    [[ -z ${(t)REPO_MODULES} ]] && declare -gA REPO_MODULES
    [[ -z ${(t)REPO_IDE_CONFIGS} ]] && declare -gA REPO_IDE_CONFIGS

    local config_file="$HOME/.config/worktree-tools/config.zsh"

    if [[ -f "$config_file" ]]; then
        source "$config_file"
    else
        # Use default configuration
        _load_default_config
    fi
}

# Lazy loading function
_load_ci_helper_impl() {
    if [[ $_ci_helper_loaded == false ]]; then
        # Load configuration first
        _load_ci_config
        # Define all the implementation functions
        _define_ci_helper_functions
        _ci_helper_loaded=true
    fi
}

# Define all the implementation functions
_define_ci_helper_functions() {
    # Helper to resolve repo identifier (shorthand or full name) to shorthand
    # This allows configs to use shorthand consistently
    resolve_to_shorthand() {
        local identifier=$1

        # First check if it's already a shorthand
        if [[ -n ${REPO_MAPPINGS[$identifier]} ]]; then
            echo "$identifier"
            return 0
        fi

        # Check if it's a full name, find the shorthand
        for shorthand full_name in ${(kv)REPO_MAPPINGS[@]}; do
            if [[ "$full_name" == "$identifier" ]]; then
                echo "$shorthand"
                return 0
            fi
        done

        # Not found in mappings, return as-is for backward compatibility
        echo "$identifier"
    }

    # Get config value supporting both shorthand and full name keys
    get_repo_config() {
        local repo=$1
        local shorthand=$(resolve_to_shorthand "$repo")

        # Try shorthand first, then full name for backward compatibility
        local config="${REPO_CONFIGS[$shorthand]:-${REPO_CONFIGS[$repo]:-}}"
        echo "$config"
    }

    # Function to get modules for a repository
    get_repo_modules() {
        local repo=$1
        local shorthand=$(resolve_to_shorthand "$repo")

        # Try shorthand first, then full name for backward compatibility
        echo "${REPO_MODULES[$shorthand]:-${REPO_MODULES[$repo]:-}}"
    }

    # Get IDE config supporting both shorthand and full name keys
    get_repo_ide_config() {
        local repo=$1
        local shorthand=$(resolve_to_shorthand "$repo")

        # Try shorthand first, then full name for backward compatibility
        echo "${REPO_IDE_CONFIGS[$shorthand]:-${REPO_IDE_CONFIGS[$repo]:-}}"
    }

    # Function to find git worktree root
    find_git_root() {
        # Try using git command first (handles worktrees and submodules better)
        if command -v git &> /dev/null && git rev-parse --show-toplevel 2>/dev/null; then
            return 0
        fi
        
        # Fallback to manual search
        local current_dir=$(pwd)
        while [[ ! -d "$current_dir/.git" && "$current_dir" != "/" ]]; do
            current_dir=$(dirname "$current_dir")
        done
        if [[ -d "$current_dir/.git" ]]; then
            echo "$current_dir"
        else
            echo ""
        fi
    }

    # Function to build gradle command for modules
    build_gradle_command() {
        local repo=$1
        shift  # Remove repo from arguments, rest are tasks
        local tasks=("$@")
        local modules=$(get_repo_modules $repo)

        if [[ -z $modules ]]; then
            return 1
        fi

        local command=""
        # Split modules by space and iterate
        for module in ${=modules}; do
            for task in "${tasks[@]}"; do
                if [[ -n $command ]]; then
                    command="$command :$module:$task"
                else
                    command=":$module:$task"
                fi
            done
        done

        echo "./gradlew --quiet $command"
    }

    # Function to detect which repository we're in
    detect_repo() {
        # First try to get the git remote origin URL (most reliable for worktrees)
        if command -v git &> /dev/null; then
            local origin_url=$(git remote get-url origin 2>/dev/null)
            if [[ -n $origin_url ]]; then
                # Extract repo name from URL
                local repo_from_url=$(basename "$origin_url" .git)

                # Check if this repo is configured (try both shorthand and full name)
                if [[ -n $(get_repo_config "$repo_from_url") ]]; then
                    echo "$repo_from_url"
                    return
                fi
            fi
        fi

        # Fallback to directory path matching
        local current_dir=$(pwd)
        local repo_name=""

        # Check each configured repo (try both shorthand and full name)
        # First check REPO_CONFIGS keys
        for repo in ${(k)REPO_CONFIGS[@]}; do
            if [[ $current_dir == *"$repo"* ]]; then
                repo_name="$repo"
                break
            fi
        done

        # If not found, check REPO_MAPPINGS full names
        if [[ -z $repo_name ]]; then
            for shorthand full_name in ${(kv)REPO_MAPPINGS[@]}; do
                if [[ $current_dir == *"$full_name"* ]]; then
                    repo_name="$shorthand"
                    break
                fi
            done
        fi

        echo $repo_name
    }

    # Function to check if we're in a valid repository
    check_repo() {
        local repo=$(detect_repo)
        if [[ -z $repo ]]; then
            local current_dir=$(pwd)
            echo "❌ Error: This command does not work in an unregistered repository."
            echo "Please add this repository to the REPO_CONFIGS in ~/.config/worktree-tools/config.zsh"
            echo ""
            echo "This command currently works in these registered repositories:"
            for repo in ${(k)REPO_CONFIGS[@]}; do
                echo "  - $repo"
            done
            return 1
        fi
        echo $repo
    }

    # Function to get command from repo config
    get_repo_command() {
        local repo=$1
        local command_type=$2  # build, test, or lint
        
        local config="$(get_repo_config "$repo")"
        case $command_type in
            "build")
                echo "${config%%|*}"
                ;;
            "test")
                local temp="${config#*|}"
                echo "${temp%%|*}"
                ;;
            "lint")
                echo "${config##*|}"
                ;;
        esac
    }

    # Function to run CI commands
    run_ci() {
        local repo=$(check_repo)
        if [[ $? -ne 0 ]]; then
            return 1
        fi

        echo "🚀 Running CI for $repo..."

        local build_cmd=$(get_repo_command $repo "build")
        local test_cmd=$(get_repo_command $repo "test")
        local lint_cmd=$(get_repo_command $repo "lint")

        echo "🔨 Building..."
        eval "$build_cmd"
        local build_result=$?

        if [[ $build_result -eq 0 ]]; then
            echo "🧪 Testing..."
            eval "$test_cmd"
            local test_result=$?

            if [[ $test_result -eq 0 ]]; then
                echo "🔍 Linting..."
                eval "$lint_cmd"
                local lint_result=$?

                if [[ $lint_result -eq 0 ]]; then
                    echo -e "\033[32m✅ SUCCESS\033[0m"
                fi
            fi
        fi
    }

    # Function to run CI commands for modules only
    run_ci_modules() {
        local repo=$(check_repo)
        if [[ $? -ne 0 ]]; then
            return 1
        fi

        local modules=$(get_repo_modules $repo)
        if [[ -z $modules ]]; then
            echo "❌ No modules configured for $repo"
            echo "💡 Add modules to REPO_MODULES in the script configuration"
            return 1
        fi

        echo "🚀 Running module CI for $repo..."
        echo "📦 Modules: $modules"

        # Check if this is a gradle-based project
        if [[ $(get_repo_command $repo "build") == *"gradlew"* ]]; then
            local assemble_cmd=$(build_gradle_command $repo "assembleDebug")
            if [[ $? -ne 0 ]]; then
                echo "❌ Failed to build gradle command for modules"
                return 1
            fi
            local test_cmd=$(build_gradle_command $repo "testDebugUnitTest")
            local lint_cmd=$(build_gradle_command $repo "lintDebug" "detekt")

            eval "$assemble_cmd && $test_cmd && $lint_cmd"
            if [[ $? -eq 0 ]]; then
                echo -e "\033[32m✅ SUCCESS\033[0m"
            fi
        else
            echo "🍎 Module-level CI not configured for non-Gradle projects, running full CI..."
            run_ci
        fi
    }

    # Function to run test commands
    run_test() {
        local repo=$(check_repo)
        if [[ $? -ne 0 ]]; then
            return 1
        fi

        echo "🧪 Running tests for $repo..."

        local test_cmd=$(get_repo_command $repo "test")
        eval "$test_cmd"
        
        if [[ $? -eq 0 ]]; then
            echo -e "\033[32m✅ SUCCESS\033[0m"
        fi
    }

    # Function to run lint commands
    run_lint() {
        local repo=$(check_repo)
        if [[ $? -ne 0 ]]; then
            return 1
        fi

        echo "🔍 Running lint for $repo..."

        local lint_cmd=$(get_repo_command $repo "lint")
        eval "$lint_cmd"
        
        if [[ $? -eq 0 ]]; then
            echo -e "\033[32m✅ SUCCESS\033[0m"
        fi
    }

    # Function to run lint commands for modules only
    run_lint_modules() {
        local repo=$(check_repo)
        if [[ $? -ne 0 ]]; then
            return 1
        fi

        local modules=$(get_repo_modules $repo)
        if [[ -z $modules ]]; then
            echo "❌ No modules configured for $repo"
            return 1
        fi

        echo "🔍 Running module lint for $repo..."
        echo "📦 Modules: $modules"

        # Check if this is a gradle-based project
        if [[ $(get_repo_command $repo "build") == *"gradlew"* ]]; then
            local lint_cmd=$(build_gradle_command $repo "lintDebug" "detekt")
            if [[ $? -ne 0 ]]; then
                echo "❌ Failed to build gradle command for modules"
                return 1
            fi
            eval "$lint_cmd"

            if [[ $? -eq 0 ]]; then
                echo -e "\033[32m✅ SUCCESS\033[0m"
            fi
        else
            echo "🍎 Module-level lint not configured for non-Gradle projects, running full lint..."
            run_lint
        fi
    }

    # Function to get IDE configuration for a repository
    get_ide_config() {
        local repo=$1
        local field=$2  # ide_type, workspace_path, or fallback_command
        
        local config="$(get_repo_ide_config "$repo")"
        case $field in
            "ide_type")
                echo "${config%%|*}"
                ;;
            "workspace_path")
                local temp="${config#*|}"
                echo "${temp%%|*}"
                ;;
            "fallback_command")
                echo "${config##*|}"
                ;;
        esac
    }

    # Function to detect IDE type and workspace for a repository
    # Returns: "ide_type|workspace_path|status_code"
    # This is pure logic - no side effects, fully testable
    detect_ide_info() {
        local git_root=$1
        local repo=$2

        # Check if repository has specific IDE configuration
        local ide_type=$(get_ide_config $repo "ide_type")
        local workspace_path=$(get_ide_config $repo "workspace_path")

        if [[ -n $ide_type ]]; then
            # Use configured IDE type
            case $ide_type in
                "android-studio")
                    echo "android-studio||0"
                    return 0
                    ;;
                "xcode-workspace")
                    local full_workspace_path="$git_root/$workspace_path"
                    if [[ -d "$full_workspace_path" ]]; then
                        echo "xcode-workspace|$full_workspace_path|0"
                        return 0
                    else
                        echo "xcode-workspace|$full_workspace_path|1"
                        return 1
                    fi
                    ;;
                "xcode-package")
                    local full_workspace_path="$git_root/$workspace_path"
                    if [[ -d "$full_workspace_path" ]]; then
                        echo "xcode-package|$full_workspace_path|0"
                        return 0
                    else
                        echo "xcode-package|$full_workspace_path|1"
                        return 1
                    fi
                    ;;
                "vscode")
                    echo "vscode|$git_root|0"
                    return 0
                    ;;
                *)
                    echo "unknown|$ide_type|1"
                    return 1
                    ;;
            esac
        else
            # Fallback: Generic heuristics for IDE selection
            if [[ -f "$git_root/gradlew" ]] || [[ -f "$git_root/build.gradle" ]]; then
                echo "android-studio|$git_root|0"
                return 0
            elif [[ -f "$git_root/Package.swift" ]]; then
                local workspace_path="$git_root/.swiftpm/xcode/package.xcworkspace"
                if [[ -d "$workspace_path" ]]; then
                    echo "xcode-package|$workspace_path|0"
                    return 0
                else
                    echo "xcode-package|$git_root/Package.swift|0"
                    return 0
                fi
            else
                # Check for .xcworkspace files
                local workspace_files=("$git_root"/*.xcworkspace(N))
                if [[ ${#workspace_files[@]} -gt 0 ]]; then
                    echo "xcode-workspace|${workspace_files[1]}|0"
                    return 0
                fi

                # Check for .xcodeproj files
                local project_files=("$git_root"/*.xcodeproj(N))
                if [[ ${#project_files[@]} -gt 0 ]]; then
                    echo "xcode-project|${project_files[1]}|0"
                    return 0
                fi

                # Default fallback
                echo "default|$git_root|0"
                return 0
            fi
        fi
    }

    # Function to execute IDE launch command
    # This function has side effects - calls external commands
    launch_ide() {
        local ide_type=$1
        local target_path=$2

        case $ide_type in
            "android-studio")
                if command -v studio &> /dev/null; then
                    studio "$target_path" &
                elif [[ -d "/Applications/Android Studio.app" ]]; then
                    open -a "Android Studio" "$target_path"
                else
                    return 1
                fi
                ;;
            "xcode-workspace"|"xcode-package"|"xcode-project")
                open "$target_path"
                ;;
            "vscode")
                if command -v code &> /dev/null; then
                    code "$target_path"
                else
                    open "$target_path"
                fi
                ;;
            "default")
                if command -v code &> /dev/null; then
                    code "$target_path"
                else
                    open "$target_path"
                fi
                ;;
            *)
                return 1
                ;;
        esac
        return 0
    }

    # Function to open IDE for current repository
    open_ide() {
        local repo=$(check_repo)
        if [[ $? -ne 0 ]]; then
            echo "❌ Repository check failed"
            return 1
        fi

        echo "✅ Detected repository: $repo"

        local git_root=$(find_git_root)
        echo "🔍 Git root result: '$git_root'"

        if [[ -z $git_root ]]; then
            echo "❌ Error: Not in a git repository"
            return 1
        fi

        echo "💻 Opening IDE for $repo..."

        # Detect IDE info (testable pure function)
        local ide_info=$(detect_ide_info "$git_root" "$repo")
        local ide_type="${ide_info%%|*}"
        local temp="${ide_info#*|}"
        local target_path="${temp%%|*}"
        local status_code="${temp##*|}"

        if [[ $status_code -ne 0 ]]; then
            case $ide_type in
                "xcode-workspace"|"xcode-package")
                    local workspace_path=$(get_ide_config $repo "workspace_path")
                    echo "❌ $workspace_path not found at $target_path"
                    local fallback_command=$(get_ide_config $repo "fallback_command")
                    if [[ -n $fallback_command ]]; then
                        echo "💡 Try running '$fallback_command'"
                    fi
                    ;;
                "unknown")
                    echo "❌ Unknown IDE type: $target_path"
                    ;;
            esac
            return 1
        fi

        # Map IDE type to user-friendly messages
        case $ide_type in
            "android-studio")
                echo "📱 Opening Android Studio..."
                ;;
            "xcode-workspace"|"xcode-project")
                echo "🍎 Opening Xcode workspace..."
                ;;
            "xcode-package")
                echo "🍎 Opening Xcode for Swift Package..."
                ;;
            "vscode")
                echo "🌐 Opening VS Code..."
                ;;
            "default")
                echo "🤔 Unknown project type, opening in default editor..."
                ;;
        esac

        # Launch IDE (side effect function)
        if launch_ide "$ide_type" "$target_path"; then
            echo "✅ IDE opening: $target_path"
            return 0
        else
            case $ide_type in
                "android-studio")
                    echo "❌ Android Studio not found"
                    ;;
                *)
                    echo "❌ Failed to open IDE"
                    ;;
            esac
            return 1
        fi
    }

    # Function to show help
    show_help() {
        echo "CI/Lint Helper Commands:"
        echo ""
        echo "  run_ci           - Run the main CI command for the current repository"
        echo "  run_test         - Run tests only for the current repository"
        echo "  run_lint         - Run linting commands for the current repository"
        echo "  run_ci_modules   - Run CI for configured modules only"
        echo "  run_lint_modules - Run lint for configured modules only"
        echo "  open_ide         - Open the appropriate IDE for the current repository"
        echo ""
        echo "Configured repositories:"
        for repo in ${(k)REPO_CONFIGS[@]}; do
            echo "  - $repo"
            local modules=$(get_repo_modules $repo)
            if [[ -n $modules ]]; then
                echo "    Modules: $modules"
            fi
        done
        echo ""
        echo "To add new repositories, edit REPO_CONFIGS in the script."
        echo "To add modules, edit REPO_MODULES in the script."
    }
}

# Lightweight wrapper functions that use lazy loading
ci_helper() {
    _load_ci_helper_impl
    case $1 in
        "ci"|"run_ci")
            run_ci
            ;;
        "test"|"run_test")
            run_test
            ;;
        "lint"|"run_lint")
            run_lint
            ;;
        "ci_modules"|"run_ci_modules")
            run_ci_modules
            ;;
        "lint_modules"|"run_lint_modules")
            run_lint_modules
            ;;
        "open_ide"|"ide")
            open_ide
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo "❌ Unknown command: $1"
            echo "Use 'ci_helper help' for available commands"
            return 1
            ;;
    esac
}

# Create aliases for easier access
alias ci='ci_helper ci'
alias test='ci_helper test'
alias lint='ci_helper lint'
alias ci_modules='ci_helper ci_modules'
alias lint_modules='ci_helper lint_modules'
alias ide='ci_helper ide'