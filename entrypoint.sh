#!/bin/bash
# =============================================================================
#  NeoGoDDaR - Docker Entrypoint
#  Deadlock Detection and Resolution in Go Programs
# =============================================================================

TOOL_DIR="/home/NeoGoDDaR/NeoGoDDaR"
EXAMPLES_DIR="$TOOL_DIR/tests/examples"
BUGS_DIR="$TOOL_DIR/tests/go-deadlock-bug-collection"

BOLD=$(tput bold 2>/dev/null || echo "")
RESET=$(tput sgr0 2>/dev/null || echo "")
GREEN=$(tput setaf 2 2>/dev/null || echo "")
CYAN=$(tput setaf 6 2>/dev/null || echo "")
YELLOW=$(tput setaf 3 2>/dev/null || echo "")
RED=$(tput setaf 1 2>/dev/null || echo "")
DIM=$(tput dim 2>/dev/null || echo "")

banner() {
    echo ""
    echo "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo "${BOLD}${CYAN}║              NeoGoDDaR — Artifact Docker Image               ║${RESET}"
    echo "${BOLD}${CYAN}║     Static Deadlock Detection and Resolution in Go           ║${RESET}"
    echo "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

usage() {
    banner
    echo "${BOLD}USAGE${RESET}"
    echo "  docker run -it gustavofeio/neogoddar [COMMAND] [OPTIONS]"
    echo ""
    echo "${BOLD}─── REPRODUCE PAPER RESULTS ────────────────────────────────────────${RESET}"
    echo ""
    echo "  ${GREEN}benchmark-examples${RESET} [-v] [-t] [-c]"
    echo "      ${BOLD}Validation suite${RESET} — curated examples used during development."
    echo "      All tests are expected to pass. Confirms the tool correctly handles"
    echo "      all supported Go concurrency features (channels, select, recursion...)."
    echo ""
    echo "  ${GREEN}benchmark-bugs${RESET} [-v] [-t] [-c]"
    echo "      ${BOLD}Bug collection suite${RESET} — real-world Go programmes with known deadlocks."
    echo "      This is the primary evaluation benchmark reported in the paper."
    echo "      Each case is a historical bug; the tool detects and resolves it."
    echo ""
    echo "  ${GREEN}benchmark-all${RESET} [-v] [-t] [-c]"
    echo "      Run both suites sequentially (validation first, then bug collection)."
    echo ""
    echo "  ${DIM}Options (apply to all benchmark commands):${RESET}"
    echo "    ${YELLOW}-v, --verbose${RESET}    Show intermediate analysis representation (MiGo/CCS)"
    echo "    ${YELLOW}-t, --terminal${RESET}   Print output to terminal instead of *.output files"
    echo "    ${YELLOW}-c, --clean${RESET}      Remove all previously generated *.output files"
    echo ""
    echo "${BOLD}─── ANALYSE INDIVIDUAL FILES ───────────────────────────────────────${RESET}"
    echo ""
    echo "  ${GREEN}analyse-go${RESET} [-patch] [-v] <file.go>"
    echo "      Analyse a Go source file for deadlocks."
    echo "      Add -patch to also automatically fix the deadlocks in the source."
    echo ""
    echo "  ${GREEN}analyse-migo${RESET} [-v] <file.migo>"
    echo "      Analyse a MiGo type representation file for deadlocks."
    echo ""
    echo "  ${GREEN}analyse-ccs${RESET} '<expression>'"
    echo "      Analyse a CCS process expression directly."
    echo ""
    echo "${BOLD}─── INTERACTIVE SHELL ──────────────────────────────────────────────${RESET}"
    echo ""
    echo "  ${GREEN}shell${RESET}"
    echo "      Start a bash shell with full access to the tool and test suites."
    echo "      Inside: ${DIM}dune exec -- GoDDaR --help${RESET}"
    echo ""
    echo "${BOLD}─── EXAMPLES ───────────────────────────────────────────────────────${RESET}"
    echo ""
    echo "  # Reproduce paper results — output saved to *.output files per test case"
    echo "  docker run -it gustavofeio/neogoddar benchmark-bugs"
    echo ""
    echo "  # Same, but print results live to the terminal"
    echo "  docker run -it gustavofeio/neogoddar benchmark-bugs --terminal"
    echo ""
    echo "  # Run validation suite with verbose intermediate representation"
    echo "  docker run -it gustavofeio/neogoddar benchmark-examples --verbose"
    echo ""
    echo "  # Run both suites and save all output files to a local folder"
    echo "  docker run -it -v \$(pwd)/results:/home/NeoGoDDaR/NeoGoDDaR/tests neogoddar benchmark-all"
    echo ""
    echo "  # Analyse your own Go file (mount your directory as /workspace)"
    echo "  docker run -it -v \$(pwd):/workspace neogoddar analyse-go /workspace/main.go"
    echo ""
    echo "  # Analyse and auto-patch deadlocks in your Go file"
    echo "  docker run -it -v \$(pwd):/workspace neogoddar analyse-go -patch /workspace/main.go"
    echo ""
    echo "  # Analyse a CCS expression directly"
    echo "  docker run -it gustavofeio/neogoddar analyse-ccs 'a!.b?.0 || b!.a?.0'"
    echo ""
    echo "  # Clean all generated *.output files from a previous run"
    echo "  docker run -it gustavofeio/neogoddar benchmark-all --clean"
    echo ""
    echo "${BOLD}─── TEST SUITE LOCATIONS (inside container) ────────────────────────${RESET}"
    echo "  ${DIM}Validation:      $EXAMPLES_DIR${RESET}"
    echo "  ${DIM}Bug collection:  $BUGS_DIR${RESET}"
    echo ""
}

# Parse and forward benchmark flags to run_benchmark.sh
run_benchmark() {
    local suite_dir="$1"
    local suite_name="$2"
    shift 2
    local flags=""

    for arg in "$@"; do
        case "$arg" in
            -v|--verbose)  flags="$flags --verbose" ;;
            -t|--terminal) flags="$flags --terminal" ;;
            -c|--clean)    flags="$flags --clean" ;;
            *)
                echo "${RED}Unknown benchmark option: $arg${RESET}"
                echo "Valid options: -v/--verbose, -t/--terminal, -c/--clean"
                exit 1
                ;;
        esac
    done

    echo "${BOLD}${YELLOW}>>> Running benchmark suite: $suite_name${RESET}"
    echo ""
    cd "$suite_dir" || { echo "${RED}Error: suite directory not found: $suite_dir${RESET}"; exit 1; }
    bash run_benchmark.sh $flags
}

analyse_go() {
    local patch=""
    local verbose=""
    local file=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -patch|--patch) patch="-patch"; shift ;;
            -v|--verbose)   verbose="-v"; shift ;;
            *)
                if [ -z "$file" ]; then
                    file="$1"; shift
                else
                    echo "${RED}Unexpected argument: $1${RESET}"; exit 1
                fi
                ;;
        esac
    done

    if [ -z "$file" ]; then
        echo "${RED}Error: no Go file specified.${RESET}"
        echo "Usage: analyse-go [-patch] [-v] <file.go>"
        exit 1
    fi
    if [ ! -f "$file" ]; then
        echo "${RED}Error: file not found: $file${RESET}"
        exit 1
    fi

    echo "${BOLD}${YELLOW}>>> Analysing Go file: $file${RESET}"
    [ -n "$patch" ] && echo "${DIM}    (auto-patch mode enabled)${RESET}"
    echo ""
    cd "$TOOL_DIR"
    dune exec -- GoDDaR $verbose go $patch "$file"
}

analyse_migo() {
    local verbose=""
    local file=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -v|--verbose) verbose="-v"; shift ;;
            *)
                if [ -z "$file" ]; then
                    file="$1"; shift
                else
                    echo "${RED}Unexpected argument: $1${RESET}"; exit 1
                fi
                ;;
        esac
    done

    if [ -z "$file" ]; then
        echo "${RED}Error: no MiGo file specified.${RESET}"
        echo "Usage: analyse-migo [-v] <file.migo>"
        exit 1
    fi
    if [ ! -f "$file" ]; then
        echo "${RED}Error: file not found: $file${RESET}"
        exit 1
    fi

    echo "${BOLD}${YELLOW}>>> Analysing MiGo file: $file${RESET}"
    echo ""
    cd "$TOOL_DIR"
    dune exec -- GoDDaR $verbose migo "$file"
}

analyse_ccs() {
    local expr="$1"
    if [ -z "$expr" ]; then
        echo "${RED}Error: no CCS expression provided.${RESET}"
        echo "Usage: analyse-ccs '<expression>'"
        echo "Example: analyse-ccs 'a!.b?.0 || b!.a?.0'"
        exit 1
    fi
    echo "${BOLD}${YELLOW}>>> Analysing CCS expression: ${expr}${RESET}"
    echo ""
    cd "$TOOL_DIR"
    dune exec -- GoDDaR ccs "$expr"
}

# Create user workspace mount point
mkdir -p /home/NeoGoDDaR/workspace

# --- Command dispatcher ---
case "${1:-}" in
    "benchmark-examples")
        banner; shift
        run_benchmark "$EXAMPLES_DIR" "examples (validation suite)" "$@"
        ;;
    "benchmark-bugs")
        banner; shift
        run_benchmark "$BUGS_DIR" "go-deadlock-bug-collection (paper evaluation suite)" "$@"
        ;;
    "benchmark-all")
        banner; shift
        run_benchmark "$EXAMPLES_DIR" "examples (validation suite)" "$@"
        echo ""
        echo "${BOLD}${CYAN}────────────────────────────────────────────────────────────${RESET}"
        echo ""
        run_benchmark "$BUGS_DIR" "go-deadlock-bug-collection (paper evaluation suite)" "$@"
        ;;
    "analyse-go")
        banner; shift
        analyse_go "$@"
        ;;
    "analyse-migo")
        banner; shift
        analyse_migo "$@"
        ;;
    "analyse-ccs")
        banner; shift
        analyse_ccs "$@"
        ;;
    "shell")
        banner
        echo "${BOLD}${GREEN}Interactive shell — tool ready at: $TOOL_DIR${RESET}"
        echo "${DIM}Run 'dune exec -- GoDDaR --help' to see all tool options.${RESET}"
        echo ""
        cd "$TOOL_DIR"
        exec /bin/bash
        ;;
    "help"|"--help"|"-h")
        usage
        ;;
    "")
        usage
        echo "${BOLD}${GREEN}No command given — starting interactive shell.${RESET}"
        echo "${DIM}Run 'dune exec -- GoDDaR --help' to see all tool options.${RESET}"
        echo ""
        cd "$TOOL_DIR"
        exec /bin/bash
        ;;
    *)
        echo "${RED}Unknown command: $1${RESET}"
        usage
        exit 1
        ;;
esac
