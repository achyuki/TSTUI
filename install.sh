#!/data/data/com.termux/files/usr/bin/bash
# Copyright (c) 2025 YukiChan
# Licensed under the MIT License.
# https://github.com/achyuki/TSTUI/blob/main/LICENSE

REPO_URL="https://github.com/achyuki/TSTUI"
TSTUI_PATH="$PREFIX/bin/tstui"
TSTUI_IGNORE_PATH="$HOME/.tstuiignore"

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

repodownload() {
    if ! curl -sL "$REPO_URL/raw/main/$1" -o "$2"; then
        error "Network error!"
        exit 1
    fi
}

info "Installing dependencies..."
if ! which dialog git &>/dev/null; then
    apt-get update && apt-get install -y dialog git
    if [ $? -ne 0 ]; then
        echo "Dependency installation failed!"
        exit 1
    fi
fi

info "Installing TSTUI..."
repodownload "tstui.sh" $TSTUI_PATH
repodownload ".tstuiignore" $TSTUI_IGNORE_PATH

chmod 700 $TSTUI_PATH

ok "TSTUI installation completed."
error "tstui --help"
tstui --help
