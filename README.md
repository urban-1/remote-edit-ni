# remote-edit for atom.io

[![Build Status](https://travis-ci.org/sveale/remote-edit.svg?branch=master)](https://travis-ci.org/sveale/remote-edit)
[![Build status](https://ci.appveyor.com/api/projects/status/i1swrbog9vdk29uk)](https://ci.appveyor.com/project/SverreAleksandersen/remote-edit)


Atom package to browse and edit remote files using FTP and SFTP.


## Key features

*   Add FTP/SFTP hosts graphically (FTPS not supported at the moment)
*   Supports password, key and agent authentication
*   Browse files through a select list
*   Build a tree-view with currently open files that can synchronise with the
    browse files view
*   Automatically upload file on save
*   Multi-window support (ie. server settings and downloaded files are serialized
    and accessible across multiple Atom windows)


## Keyboard shortcuts

(In format Windows/Linux - MacOS if they differ)

-   <kbd>Ctrl+Alt+b</kbd> - <kbd>Ctrl+Cmd+b</kbd> Select and manage hosts

-   <kbd>Ctrl+Alt+/</kbd> - <kbd>Ctrl+Cmd+/</kbd> Show/hide remote-edit panel

-   <kbd>Ctrl+Alt+o</kbd> - <kbd>Ctrl+Cmd+o</kbd> Show downloaded files


#### Select and manage hosts

While in <kbd>Ctrl+Alt+b</kbd> - <kbd>Ctrl+Cmd+b</kbd> panel (_Browse_)

While in this view, you can do the following:

-   <kbd>Shift+e</kbd> Edit selected host

-   <kbd>Shift+a</kbd> Add a new SFTP host (alternative: <kbd>Shift+a</kbd>)

-   <kbd>Shift+f</kbd> Add a new FTP host

-   <kbd>Shift+d</kbd> Delete hosts or downloaded files. Usable also in open files (_Show open files_).


## Screenshots <!-- https://imgur.com/a/Czx5z -->

### Available commands
![Available commands](http://i.imgur.com/tXLC5Nl.png)

### Adding new hosts
FTP                        |  SFTP
:-------------------------:|:-------------------------:
![Adding a new FTP host](http://i.imgur.com/hpIMGUA.png) | ![Adding a new SFTP host](http://i.imgur.com/UtwSXd2.png)


### Editing existing host
![Editing an existing host](http://i.imgur.com/LPGTQzw.png)

### Selecting host to connect
![Select host](http://i.imgur.com/UVct73u.png)

### Browsing host filesystem and open files (left-hand side panel)
![Browsing host](http://i.imgur.com/wRk7QMf.png)

### Show downloaded files
![Show open files](http://i.imgur.com/jcanLYf.png)


## Settings window
![Settings window for remote-edit](http://i.imgur.com/zGTDgF0.png)


## Security concerns
 * By default, __all information is stored in cleartext to disk__. This includes passwords and passphrases.
 * Passwords and passphrases can alternatively be stored in the systems __default keychain__ by enabling it in the settings page for remote-edit. This is achieved using [node-keytar](https://github.com/atom/node-keytar) and might not work on all systems.

## Tips and tricks

### SSH auth with password fails

On some sshd configuration (Mac OS X Mavericks), if _PasswordAuthentication_ is not explicitly set to yes, ssh server will not allow non-interactive password authentication. See [this issue](https://github.com/mscdex/ssh2/issues/154) for more in-depth information.

### Agent authentication when using SSH

The package uses [ssh2](https://github.com/mscdex/ssh2) to connect to ssh servers, and also use the default construct in this package to authenticate with an agent.
On Windows, the agent will be set to "pageant", otherwise it assumes a \ix system and uses "process.env['SSH_AUTH_SOCK']" to get the agent.
This can be overridden in the settings.


## Credits
This is a fork of a project created by Sverre Aleksandersen (sveale). It was
created to integrate bug fixes and new features.

The original project can be found at https://github.com/sveale/remote-edit
