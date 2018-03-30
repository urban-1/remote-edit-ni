# remote-edit-ni for atom.io

[![Build Status](https://travis-ci.org/newinnovations/remote-edit-ni.svg?branch=master)](https://travis-ci.org/newinnovations/remote-edit-ni)

Remote-edit-ni is a continuation of the remote-edit package. It is compatible with the latest version of atom (1.25.x at the time of writing).

This version integrates the work of @urban-1 and @newinnovations.


## Main keyboard shortcuts

- <kbd>Alt+r b</kbd>/<kbd>&#8984;+r b</kbd> -
Select remote host and start browsing in / or last directory (when selected in preferences).

- <kbd>Alt+r m</kbd>/<kbd>&#8984;+r m</kbd> -
Browse remote host in directory of the current editor tab.

-   <kbd>Alt+r v</kbd>/<kbd>&#8984;+r v</kbd> -
Show/hide remote-edit panel

- <kbd>Alt+r o</kbd>/<kbd>&#8984;+r o</kbd> -
Show open (downloaded) remote files.

- <kbd>Alt+r f</kbd> -
Give focus to the remote-edit file browser. This allows you to navigate with
keyboard (up/down/enter/backspace)


### shortcuts within _host selection_ dialog

- <kbd>Shift+a</kbd> or <kbd>Shift+s</kbd> -
Add sftp host.

- <kbd>Shift+f</kbd> -
Add ftp host.

- <kbd>Shift+e</kbd> -
Edit hosts.

- <kbd>Shift+d</kbd> -
Delete hosts or downloaded files. Usable when selecting hosts (_Browse_) or open files (_Show open remote files_).


## TODO

* Check keybindings. They are now in the <kbd>Alt+r</kbd> range
* Keyboard support in files-view, eg:
  * focus when opening files
  * escape to close files-view


## Credits
This is a fork of a project created by Sverre Aleksandersen (sveale). It was
forked to implement bug fixes and several new features.
