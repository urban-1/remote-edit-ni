# remote-edit for atom.io (remote-edit-ni) [newinnovations fork]

Atom package to browse and edit remote files using FTP and SFTP.

* This fork adds a minor feature that opens the host browse dialog in the remote directory of the current editor tab.
* New keybindings under <kbd>Alt+r</kbd>


## Keyboard shortcuts

<kbd>Alt+r b</kbd>
Select remote host and start browsing in / or last directory (when selected in preferences).

<kbd>Alt+r m</kbd>
Browse remote host and directory of the current editor tab.

<kbd>Alt+r o</kbd>
Show open remote files.

### shortcuts within _host selection_ dialog

<kbd>Shift+a</kbd> or <kbd>Shift+s</kbd>
Add sftp host.

<kbd>Shift+f</kbd>
Add ftp host.

<kbd>Shift+e</kbd>
Edit hosts.

<kbd>Shift+d</kbd>
Delete hosts or downloaded files. Usable when selecting hosts (_Browse_) or open files (_Show open remote files_).


## Security concerns
 * By default, __all information is stored in cleartext to disk__. This includes passwords and passphrases.
 * Passwords and passphrases can alternatively be stored in the systems __default keychain__ by enabling it in the settings page for remote-edit. This is achieved using [node-keytar](https://github.com/atom/node-keytar) and might not work on all systems.
