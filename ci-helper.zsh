#!/bin/zsh

# CI/Lint Helper Script for oh-my-zsh (Lazy Loading)
# Generic version for multi-repository development workflows
# Place this file in ~/.oh-my-zsh/custom/ and customize the configuration

# =============================================================================
# CONFIGURATION - Loaded from external config file
# =============================================================================

# Configuration will be loaded from ~/.config/worktree-tools/config.zsh
# If not found, defaults below will be used
declare -A REPO_CONFIGS
declare -A REPO_MODULES

# Default configuration (used as fallback)
_load_default_config() {
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
    # Function to get modules for a repository
    get_repo_modules() {
        local repo=$1
        echo "${REPO_MODULES[$repo]:-}"
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
        local task=$2
        local modules=$(get_repo_modules $repo)

        if [[ -z $modules ]]; then
            return 1
        fi

        local command=""
        # Split modules by space and iterate
        for module in ${=modules}; do
            if [[ -n $command ]]; then
                command="$command :$module:$task"
            else
                command=":$module:$task"
            fi
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
                # Check if this repo is configured
                if [[ -n ${REPO_CONFIGS[$repo_from_url]} ]]; then
                    echo "$repo_from_url"
                    return
                fi
            fi
        fi

        # Fallback to directory path matching
        local current_dir=$(pwd)
        local repo_name=""

        # Check each configured repo against current path
        for repo in ${(k)REPO_CONFIGS[@]}; do
            if [[ $current_dir == *"$repo"* ]]; then
                repo_name="$repo"
                break
            fi
        done

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
        
        local config="${REPO_CONFIGS[$repo]}"
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
            local test_cmd=$(build_gradle_command $repo "testDebugUnitTest")
            local lint_cmd=$(build_gradle_command $repo "lintDebug")

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
            local lint_cmd=$(build_gradle_command $repo "lintDebug")
            eval "$lint_cmd"
            
            if [[ $? -eq 0 ]]; then
                echo -e "\033[32m✅ SUCCESS\033[0m"
            fi
        else
            echo "🍎 Module-level lint not configured for non-Gradle projects, running full lint..."
            run_lint
        fi
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

        # Simple heuristics for IDE selection
        if [[ -f "$git_root/gradlew" ]] || [[ -f "$git_root/build.gradle" ]]; then
            # Android/Gradle project
            echo "📱 Opening Android Studio..."
            if command -v studio &> /dev/null; then
                studio "$git_root" &
            elif [[ -d "/Applications/Android Studio.app" ]]; then
                open -a "Android Studio" "$git_root"
            else
                echo "❌ Android Studio not found"
                return 1
            fi
        elif [[ -f "$git_root/Package.swift" ]]; then
            # Swift Package
            echo "🍎 Opening Xcode for Swift Package..."
            local workspace_path="$git_root/.swiftpm/xcode/package.xcworkspace"
            if [[ -d "$workspace_path" ]]; then
                open "$workspace_path"
            else
                echo "💡 Opening Package.swift in Xcode"
                open "$git_root/Package.swift"
            fi
        elif [[ -f "$git_root"/*.xcworkspace ]]; then
            # Xcode workspace
            echo "🍎 Opening Xcode workspace..."
            open "$git_root"/*.xcworkspace
        elif [[ -f "$git_root"/*.xcodeproj ]]; then
            # Xcode project
            echo "🍎 Opening Xcode project..."
            open "$git_root"/*.xcodeproj
        else
            echo "🤔 Unknown project type, opening in default editor..."
            if command -v code &> /dev/null; then
                code "$git_root"
            else
                open "$git_root"
            fi
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