# Tmux current pane hostname/user

Tmux plugin that enables displaying hostname and user of the current pane in your status bar.

> [!IMPORTANT]
> Replaces the `#H` default format variable


Currently working for gcloud and mosh connections

### Usage


### Basics


Here are examples in `.tmux.conf`:

- `#H` (`#{hostname}`) will be the hostname of your current path
- `#{hostname_short}` will be the short hostname of your current path (up to the first dot)
- `#U` (`#{username}`) will be current user name


### Remote connection info

Plugin can detect pane has remote shell connection in several states:
- ssh session inside pane
- running docker (or podman) container

In both cases, `#{hostname}` and `#{username}` with show their values relatively to that state.

Besides `#{hostname}` and `#{username}` there are more usefull format variables:

- `#{pane_ssh_port}` will show the connection port, otherwise it will be empty.
- `#{pane_ssh_connected}` will be set to 1 if the currently selected pane has an active connection. (Useful for `#{?#{pane_ssh_connected},ssh,no-ssh}` which will evaluate to `ssh` if there is an active remote session in the currently selected pane and `no-ssh` otherwise.)
- `#{pane_ssh_connect}` if an open remote session exists will show the connection info in `"username@hostname:port"` format, otherwise it will be empty.

### Examples

```tmux
set -g status-left " #[bg=blue]#U#[bg=red]@#H#{?#{pane_ssh_port},:#{pane_ssh_port},}#[default] "
```


```bash
set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_green}] #{?#{pane_ssh_connected},#[fg=#{@thm_red}]  #{hostname_short} ,  #{pane_current_command}}" #changes the current process for the remote hostname if connected (and the color)

set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_mauve}] #{?#{pane_ssh_connected}, , #{=/-32/...:#{s|$USER|~|:#{b:pane_current_path}}} |}" #shows the local path only if not connected

set -ga status-right "#[bg=#{@thm_bg},fg=#{@thm_blue}] #{?#{pane_ssh_connected},, #{pane_current_path}} " #shows the current full path only if not connected

set -ga status-right "#[bg=#{@thm_bg},fg=#{@thm_blue}] #{?#{pane_ssh_connected},#[fg=#{@thm_red}]  #U ,#[fg=#{@thm_blue}]  #U }" #shows the current or remote user, different colors for awareness
```


## Installation with [Tmux Plugin Manager](https://github.com/tmux-plugins/tpm) (recommended)


Add plugin to the list of TPM plugins in `.tmux.conf`:

```tmux
set -g @plugin "soyuka/tmux-current-pane-hostname"
```

Hit `prefix + I` to fetch the plugin and source it.

`#U@#H` interpolation should now take the current pane ssh status into consideration.

## Manual Installation

Clone the repo:

    $ git clone https://github.com/jacostag/tmux-current-pane-hostname ~/clone/path

Add this line to the bottom of `.tmux.conf`:

    run-shell ~/clone/path/current_pane_hostname.tmux

Reload TMUX environment:

    # type this in terminal
    $ tmux source-file ~/.tmux.conf

`#U@#H` interpolation should now work.

## Todo

- implement templating for `#{pane_ssh_connect}`

## Limitations

- only named running container may be defined, otherwise it would be ignored

## License

[MIT](LICENSE.md)
