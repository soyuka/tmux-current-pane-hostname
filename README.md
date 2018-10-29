# Tmux current pane hostname/user

Tmux plugin that enables displaying hostname and user of the current pane in your status bar.

Replaces the `#H` format and adds a `#U` format option.

### Usage

- `#H` will be the hostname of your current path. If there is an ssh session opened, the ssh hostname will show instead of the local one.
- `#U` will show the `whoami` result or the user that logged in an ssh session.
- `#{pane_ssh_connected}` will be set to 1 if the currently selected pane has an active ssh connection. (Useful for `#{?#{pane_ssh_connection},ssh,no-ssh}` which will evaluate to `ssh` if there is an active ssh in the currently selected pane and `no-ssh` otherwise.)

Here's the example in `.tmux.conf`:

```bash
set -g status-right '#[fg=cyan,bold] #U@#H #[default]#[fg=blue]#(tmux display-message -p "#{pane_current_path}" | sed "s#$HOME#~#g") #[fg=red]%H:%M %d-%b-%y#[default]'
```

### Installation with [Tmux Plugin Manager](https://github.com/tmux-plugins/tpm) (recommended)

Add plugin to the list of TPM plugins in `.tmux.conf`:

    set -g @tpm_plugins "                 \
      tmux-plugins/tpm                    \
      soyuka/tmux-current-pane-hostname     \
    "

Hit `prefix + I` to fetch the plugin and source it.

`#U@#H` interpolation should now take the current pane ssh status into consideration.

### Manual Installation

Clone the repo:

    $ git clone https://github.com/soyuka/tmux-current-pane-hostname ~/clone/path

Add this line to the bottom of `.tmux.conf`:

    run-shell ~/clone/path/current_pane_hostname.tmux

Reload TMUX environment:

    # type this in terminal
    $ tmux source-file ~/.tmux.conf

`#U@#H` interpolation should now work.

### Limitations

I wanted to get the current path of the opened ssh session but that's not possible. I haven't found a way to get the output of a remote command that will be executed on an opened ssh session. A dirty way would be to use `send-keys pwd Enter` but this will show on the pane and we don't want this.
So, I'm just getting the correct ssh command corresponding to the pane job pid and parsing it, for example:
```
ssh test@host.com
# #H => host.com
# #U => test
```

### License

[MIT](LICENSE.md)
