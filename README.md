# Tmux current pane hostname/user

Tmux plugin that enables displaying hostname and user of the current pane.

Replaces the `#H` format and adds a `#U` format option.

### Usage

- `#H` will be the hostname of your current path. If there is an ssh session opened, the ssh hostname will show instead of the local one.
- `#U` will show the `whoami` result or the user that logged in an ssh session.

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

`#U@#H}` interpolation should now take the current pane ssh status in consideration.

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


### License

[MIT](LICENSE.md)
