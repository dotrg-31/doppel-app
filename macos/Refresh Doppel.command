#!/bin/bash
# Double-click after ChatGPT updates: rebuilds Doppel from the current ChatGPT.app.
# Your Doppel login and data are kept.
"$(dirname "$0")/install.sh" && open "$HOME/Applications/Doppel.app"
