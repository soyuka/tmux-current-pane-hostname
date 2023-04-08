#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create map placeholders to handle scripts
# to provide one handler for multiple placeholders.
# Use '//' as separator, due to unix limitation in filenames
placeholders_to_scripts=(
	"\#U//#($CURRENT_DIR/scripts/user.sh)"
	"\#\{username\}//#($CURRENT_DIR/scripts/user.sh)"
	"\#H//#($CURRENT_DIR/scripts/host.sh)"
	"\#\{hostname\}//#($CURRENT_DIR/scripts/host.sh)"
	"\#\{hostname_short\}//#($CURRENT_DIR/scripts/host_short.sh)"
	"\#\{pane_ssh_port\}//#($CURRENT_DIR/scripts/port.sh)"
	"\#\{pane_ssh_connected\}//#($CURRENT_DIR/scripts/pane_ssh_connected.sh)"
	"\#\{pane_ssh_connect\}//#($CURRENT_DIR/scripts/pane_ssh_connect.sh)")


source $CURRENT_DIR/scripts/shared.sh

do_interpolation() {
	local interpolated=$1
	for assignment in ${placeholders_to_scripts[@]}; do
		# ${assignment%\/\/*} - remove from // til EOL
		# ${assignment#*\/\/} - remove from BOL til //
		# ${interpolated//A/B} - replace all occurrences of A in interpolated with B
		local interpolated=${interpolated//${assignment%\/\/*}/${assignment#*\/\/}}
	done
	echo "$interpolated"
}

update_tmux_option() {
	local option=$1
	local option_value=$(get_tmux_option "$option")
	local new_option_value=$(do_interpolation "$option_value")
	set_tmux_option "$option" "$new_option_value"
}

main() {
	update_tmux_option "status-right"
	update_tmux_option "status-left"
}

main
