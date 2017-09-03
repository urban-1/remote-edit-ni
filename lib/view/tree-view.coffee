{$, $$, View} = require 'atom-space-pen-views'
Path = require 'path'


module.exports =
  class MiniTreeView extends View
    initialize: ->
      @items = []
      @tree = []

    @content: ->
      @div =>
        @div class: 'remote-edit-scroller order--center', =>
          @div class: 'remote-edit-scroller', outlet: 'scroller', =>
            @span class: 'remote-edit-treeview-header inline-block', 'Open Files'
            @hr
            @ol class: 'list-tree full-menu focusable-panel', tabindex: -1, outlet: 'tree'
        @div class: 'remote-edit-resize-handle', outlet: 'resizeHandle'

    addFile: (file, hostname) ->
      toadd = {}
      # explode paths
      pathParts = file.path.split(Path.sep)
      if pathParts[0] == ""
        pathParts.shift()

      # Prepend hostname, so we can use recursion
      pathParts.unshift(hostname)
      toadd.path = pathParts
      toadd.meta = file
      toadd.hostname = hostname

      @items.push(toadd)
      @rebuildTree()

    removeFile: (file, hostname) ->
      index = 0
      foundIndex = -1

      # Search for this item and remember index
      for item in @items
        if item.hostname == hostname and item.meta.path = file.path
          foundIndex = index
          break

        index++

      # if we have an index splice
      if foundIndex > -1
        @items.splice(foundIndex, 1)

      @rebuildTree()



    reduceTree: (node, name, level=0) ->
      length = (k for own k of node.children).length

      # Add meta data to be able to detect icon later (todo: move to render?)
      if level == 1
        node.isServer = true
      else if level > 1 and length == 0
        node.isFile = true
      else if level > 1
        node.isFolder = true

      if length == 0
        return

      # We always keep 0 since it is the host
      if length == 1 and level > 1 and !node.keep
        console.debug "Removing " + name
        node.parent.children = node.children
        node = node.parent

      # in any case now, recurse
      for key of node.children
        @reduceTree(node.children[key], key, level+1)


    rebuildTree: ->
      @tree = {root: children:{}, parent: null}
      # Loop all items and build the full tree
      for item in @items

        # Add hostname if not in already
        node = @tree.root

        for p in item.path
          if !(p of node.children)
            console.debug "Adding " + p
            node.children[p] = {children: {}, parent: node}

          node = node.children[p]

        # Node should be pointing to the leaf
        node.meta = item.meta
        node.parent.keep = true

      console.debug @tree

      # Now reduce the tree and add meta data
      @reduceTree(@tree.root, "root", 0)
      console.debug @tree





    viewForItem: (item) ->
      icon = switch
        when item.isDir then 'icon-file-directory'
        when item.isLink then 'icon-file-symlink-file'
        else 'icon-file-text'
      $$ ->
        @li class: 'list-item list-selectable-item two-lines', =>
          @span class: 'primary-line icon '+ icon, 'data-name' : item.name, title : item.name, item.name
