#!/usr/bin/env bash

# @TODO user-formatted pane_ssh_connect output
declare -r pane_ssh_connect_format='@pane-ssh-connect-format'

get_tmux_option() {
	# @note there is some limitation in show-option subcommand
	# @see https://man7.org/linux/man-pages/man1/tmux.1.html#FORMATS
	# Option may have user-defined options, e.g.:
	#   set-option -g @pane_format "#{pane_id}"
	#   set-window-option -g pane-border-format "#{E:@pane_format}"
	# In this case, `get_tmux_option "pane-border-format"` will return `"#{E:@pane_format}"`, not `"#{pane_id}"`
	# There is no reason to implement recursive variable expantion for now.
	local option=$1
	local default_value=$2
	local option_value=$(tmux show-option -gqv "$option")
	[[ -z "$option_value" ]] && echo "$default_value" || echo "$option_value"
}

set_tmux_option() {
	local option=$1
	local value=$2
	tmux set-option -gq "$option" "$value"
}

