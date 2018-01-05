# remote-edit-ni for atom.io [newinnovations fork of remote-edit]

Atom package to browse and edit remote files using SSH and FTP.

This fork differs from the original package sveale/remote-edit:

* Several changes in atom have broken sveale/remote-edit. This fork currently supports the changes in atom up to version 1.23.x.
* The original reason behind this fork is to have the possibility to open additional files from the same remote directory as the current editor tab. Using <kbd>Alt+r m</kbd>. ("m" for more)
* Keybindings in remote-edit-ni are under <kbd>Alt+r</kbd>. ("r" for remote)


## Keyboard shortcuts

<kbd>Alt+r b</kbd>
Select remote host and start browsing in / or last directory (when selected in preferences).

<kbd>Alt+r m</kbd>
Browse remote host in directory of the current editor tab.

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
