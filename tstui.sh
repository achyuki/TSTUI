#!/data/data/com.termux/files/usr/bin/bash
# Copyright (c) 2025 YukiChan
# Licensed under the MIT License.
# https://github.com/achyuki/TSTUI/blob/main/LICENSE

TERMUX_ROOT="$TERMUX_APP__FILES_DIR"
TERMUX_HOME="$TERMUX_ROOT/home" # Not equal $HOME
TSTUI_GITDIR="$TERMUX_HOME/.TSTUIDATA"
TSTUI_IGNORE="$TERMUX_HOME/.tstuiignore"
TSTUI_TMPDIR="$TERMUX_ROOT/../cache/TSTUI"
GIT_CONFIG_GLOBAL= # Disable ~/.gitconfig

COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RESET='\033[0m'

error() {
    echo -e "${COLOR_RED}$*${COLOR_RESET}"
}

ok() {
    echo -e "${COLOR_GREEN}$*${COLOR_RESET}"
}

info() {
    echo -e "${COLOR_YELLOW}$*${COLOR_RESET}"
}

if [[ $UID -eq 0 ]]; then
    error "Please do not run TSTUI as root!"
    exit 1
fi

# Install dependencies
if ! which dialog git &>/dev/null; then
    apt-get update && apt-get install -y dialog git
    if [ $? -ne 0 ]; then
        echo "Dependency installation failed!"
        exit 1
    fi
fi

# 世界就是個巨大的 Wrapper.
gitbase() {
    git --git-dir="$TSTUI_GITDIR" "$@"
}

gitres() {
    gitbase --work-tree="$TERMUX_ROOT" "$@"
}

gitwrap() {
    gitres "$@" >/dev/null
}

gittmpwrap() {
    gitbase --work-tree="$TSTUI_TMPDIR" "$@" >/dev/null
}

dialogwrap() {
    dialog --keep-tite "$@" 3>&1 1>&2 2>&3
}

findwrap() {
    gitres check-ignore -nv $(find "$TERMUX_ROOT" -name "$1") | awk -F '::[[:space:]]+' '{print $2}' | grep -v '^$'
}

mv_regex() {
    local pattern="$1"
    local replace="$2"
    while read -r path; do
        mv "$path" "$(dirname "$path")/$(basename "$path" | sed "s/$pattern/$replace/")"
    done
}

# Utils
init_tstui() {
    if [[ ! -d "$TSTUI_GITDIR" ]]; then
        mkdir -p "$TSTUI_GITDIR"
        git init --bare "$TSTUI_GITDIR" &>/dev/null
        gitwrap config --local user.name tstui
        gitwrap config --local user.email tstui
        gitwrap config --local core.excludesFile ~/.tstuiignore
        echo '.TSTUIDATA' >>"$TSTUI_GITDIR/info/exclude"
    fi
}

get_branchlist() {
    gitres branch --list | sed 's/^[* ] //'
}

check_branch() {
    gitwrap rev-parse --verify "$1" &>/dev/null
}

check_branch_orexit() {
    if ! check_branch "$1"; then
        error "Snapshot '${1}' does not exist!"
        exit 1
    fi
}

check_branch_orexit_ifexist() {
    if check_branch "$1"; then
        error "Snapshot '${1}' already exist!"
        exit 1
    fi
}

check_branchname_orexit() {
    if ! gitwrap check-ref-format --branch "$1" &>/dev/null; then
        error "The snapshot name '${1}' is invalid!"
        exit 1
    fi
}

findwrap_patch() {
    findwrap ".gitignore" | mv_regex "\(.*\)" ".TSTUI_\1"
}

git_add_patch() {
    # 先处理 .gitignore, 不然会灵车.
    findwrap_patch
    findwrap ".gitattributes" | mv_regex "\(.*\)" ".TSTUI_\1"
    findwrap ".git" | mv_regex "\(.*\)" ".TSTUI_\1"
}

git_clean_patch() {
    if [[ ! -f "$TSTUI_IGNORE" ]]; then
        find "$TERMUX_ROOT" -name ".git" -exec rm -rf {} +
        return
    fi

    # 先处理 .gitignore, 不然会灵车.
    findwrap_patch
    findwrap ".git" | xargs rm -rf
}

all_unpatch() {
    findwrap ".TSTUI_*" | mv_regex "^\.TSTUI_" ""
}

# from termux-setup-storage
setup_storage() {
    case "${TERMUX__USER_ID:-}" in '' | *[!0-9]* | 0[0-9]*) TERMUX__USER_ID=0 ;; esac
    am broadcast --user "$TERMUX__USER_ID" \
        --es com.termux.app.reload_style storage \
        -a com.termux.app.reload_style com.termux >/dev/null
}

envfix() {
    mkdir -p "$TMPDIR"
    mkdir -p "$TERMUX_ROOT/usr/etc/apt/apt.conf.d"
    mkdir -p "$TERMUX_ROOT/usr/etc/apt/preferences.d"
}

snapshot_create() {
    local branch_name=$1
    check_branch_orexit_ifexist "$branch_name"
    gitwrap checkout --orphan "$branch_name"

    info "Creating snapshot '$branch_name'..."
    gitwrap rm -rf --cached "$TERMUX_ROOT" &>/dev/null # 灵车
    git_add_patch
    gitwrap add "$TERMUX_ROOT"
    all_unpatch
    gitwrap commit -m "nya"

    ok "Snapshot '${branch_name}' creation completed."
}

snapshot_restore() {
    local branch_name=$1
    check_branch_orexit "$branch_name"

    info "Restoring to snapshot '$branch_name'..."
    gitwrap reset --hard "$branch_name"
    git_clean_patch
    gitwrap clean -fd
    all_unpatch
    envfix &>/dev/null

    ok "Restore to snapshot '${branch_name}' completed."

}

snapshot_delete() {
    local branch_name=$1
    check_branch_orexit "$branch_name"

    gitwrap branch -D "$branch_name"
    # 灵车.
    # gitwrap gc
    # rm -f "$TSTUI_GITDIR/objects/pack/*.pack"

    ok "Snapshot '${branch_name}' deletion completed."
}

snapshot_export() {
    local branch_name=$1
    local export_path=$2
    mkdir -p "$(dirname "$export_path")"

    info "Exporting snapshot '$branch_name' to $export_path..."
    gitwrap archive --format=tar.gz --output="$export_path" "$branch_name"

    ok "Snapshot '${branch_name}' export completed."

}

snapshot_import() {
    local branch_name=$1
    local import_path=$2

    check_branchname_orexit "$branch_name"
    if [ ! -f "$import_path" ]; then
        error "Import file '${import_path}' does not exist."
        return 1
    fi
    check_branch_orexit_ifexist "$branch_name"
    [[ -d "$TSTUI_TMPDIR" ]] || mkdir -p "$TSTUI_TMPDIR"
    gittmpwrap checkout --orphan "$branch_name"

    info "Importing snapshot file $import_path..."
    tar -xzf "$import_path" -C "$TSTUI_TMPDIR"
    gittmpwrap add "$TSTUI_TMPDIR"
    gittmpwrap commit -m "nya"
    rm -rf "$TSTUI_TMPDIR"

    ok "Snapshot imported as '${branch_name}' completed."

}

# Dialogs
dialog_confirm() {
    dialogwrap --title "Warning" --yesno "$*" 10 40
}

dialog_select_branch() {
    local branches=($(get_branchlist))
    if [ ${#branches[@]} -eq 0 ]; then
        dialogwrap --title "Error" --msgbox "No snapshots found." 10 40
        return 1
    fi
    [[ -d "$TMPDIR" ]] || mkdir -p "$TMPDIR" # tac require
    branches=($(get_branchlist | tac))

    local options=()
    for i in "${!branches[@]}"; do
        options+=("$((i + 1))" "${branches[$i]}")
    done

    local choice
    choice=$(dialogwrap --title "Snapshot" --menu "Select a snapshot:" 15 40 10 "${options[@]}")
    if [ $? -ne 0 ]; then
        return 1
    fi

    echo "${branches[$((choice - 1))]}"
}

dialog_input_branchname() {
    local branch_name
    branch_name=$(dialogwrap --title "Create" --inputbox "Enter snapshot name:" 10 40)
    if [ $? -ne 0 ]; then
        return 1
    fi

    if [[ -z "$branch_name" ]]; then
        dialogwrap --title "Error" --msgbox "Snapshot name cannot be empty." 10 40
        return 1
    fi

    echo "$branch_name"
}

# Command help
show_help() {
    echo "TermuxSnapshotTUI (TSTUI) - Termux snapshot management tool based on git"
    echo "v0.1.3"
    echo ""
    echo "Usage: tstui [command] [options]"
    echo ""
    echo "Commands:"
    echo "  (no command)          Launch TUI interface"
    echo "  list                  List all snapshots"
    echo "  restore <name>        Restore to specified snapshot"
    echo "  create <name>         Create a new snapshot"
    echo "  delete <name>         Delete a snapshot"
    echo "  export <name> <path>  Export snapshot to tar.gz file"
    echo "  import <name> <path>  Import snapshot from tar.gz file"
    echo ""
    echo "Options:"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Example:"
    echo "  tstui create backup1"
    echo "  tstui list"
    echo "  tstui restore backup1"
}

# TUI Handle
tui() {
    local choice branch_name
    choice=$(
        dialogwrap --title "TermuxSnapshotTUI" \
            --menu "Use touch or ↑↓←→↲ to operate." 0 40 0 \
            1 "『🍀 Restore 』" \
            2 "『🌸 Create 』" \
            3 "『❌ Delete 』" \
            4 "『❄️ Export 』" \
            5 "『✨ Import 』"
    )
    if [ $? = 0 ]; then
        case $choice in
        1)
            branch_name=$(dialog_select_branch)
            if [ $? -eq 0 ]; then
                if dialog_confirm "Are you sure you want to restore to snapshot '$branch_name'?\nAll changes will be lost."; then
                    snapshot_restore "$branch_name"
                fi
            fi
            ;;
        2)
            branch_name=$(dialog_input_branchname)
            if [ $? -eq 0 ]; then
                snapshot_create "$branch_name"
            fi
            ;;
        3)
            branch_name=$(dialog_select_branch)
            if [ $? -eq 0 ]; then
                if dialog_confirm "Are you sure you want to delete snapshot '$branch_name'?"; then
                    snapshot_delete "$branch_name"
                fi
            fi
            ;;
        4)
            branch_name=$(dialog_select_branch)
            if [ $? -eq 0 ]; then
                local export_path="$EXTERNAL_STORAGE/TSTUI/$branch_name.tar.gz"
                setup_storage
                if dialog_confirm "Are you sure you want to export snapshot '$branch_name' to $export_path\nThe file will be overwritten if it exists."; then
                    snapshot_export "$branch_name" "$export_path"
                fi
            fi
            ;;
        5)
            local import_path
            import_path=$(dialogwrap --title "Import" --inputbox "Enter snapshot file path:" 10 40 "/sdcard/TSTUI/")
            if [ $? -eq 0 ]; then
                if [[ -z "$import_path" ]]; then
                    dialogwrap --title "Error" --msgbox "Snapshot file path cannot be empty." 10 40
                    return 1
                fi
                snapshot_import "$(basename "$import_path" .tar.gz)" "$import_path"
            fi
            ;;
        esac
    fi
}

# CLI Handle
cli() {
    case "$1" in
    "list")
        info "Available snapshots:"
        get_branchlist
        ;;
    "restore")
        if [ -z "$2" ]; then
            error "Snapshot name is required!"
            show_help
            return 1
        fi
        snapshot_restore "$2"
        ;;
    "create")
        if [ -z "$2" ]; then
            error "Snapshot name is required!"
            show_help
            return 1
        fi
        snapshot_create "$2"
        ;;
    "delete")
        if [ -z "$2" ]; then
            error "Snapshot name is required!"
            show_help
            return 1
        fi
        snapshot_delete "$2"
        ;;
    "export")
        if [ -z "$2" ] || [ -z "$3" ]; then
            error "Snapshot name and export path are required!"
            show_help
            return 1
        fi
        snapshot_export "$2" "$3"
        ;;
    "import")
        if [ -z "$2" ] || [ -z "$3" ]; then
            error "Snapshot name and import path are required!"
            show_help
            return 1
        fi
        snapshot_import "$2" "$3"
        ;;
    "-h" | "--help")
        show_help
        ;;
    *)
        error "Unknown command '$1'"
        show_help
        return 1
        ;;
    esac
}

main() {
    init_tstui

    if [ "$1" ]; then
        cli "$@"
        exit $?
    fi

    tui
}

main "$@"
