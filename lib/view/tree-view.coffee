{$, $$, View} = require 'atom-space-pen-views'
Path = require 'path'


module.exports =
  class MiniTreeView extends View
    initialize: ->
      @items = []
      @tree = []

    @content: ->
      @div class: 'remote-edit-opened-tree', =>
        @div class: 'remote-edit-scroller order--center', =>
          @div class: 'remote-edit-scroller', outlet: 'scroller', =>
            @span class: 'remote-edit-treeview-header inline-block', 'Open Files'
            @ol class: 'list-tree full-menu focusable-panel', tabindex: -1, outlet: 'treeUI'
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
      @refreshUITree()

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


    merge = (xs...) ->
      if xs?.length > 0
        tap {}, (m) -> m[k] = v for k, v of x for x in xs

    tap = (o, fn) -> fn(o); o

    reduceTree: (node, path, level=0) ->
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
        console.debug "Removing " + path
        # FIXME: merge
        node.parent.children = merge node.parent.children, node.children
        delete node.parent.children[path]
        console.debug node.parent.children
        node = node.parent

      # in any case now, recurse
      for path of node.children
        @reduceTree(node.children[path], path, level+1)


    rebuildTree: ->
      @tree = {root: children:{}, parent: null, name: "root"}
      # Loop all items and build the full tree
      for item in @items

        # Add hostname if not in already
        node = @tree.root
        # Build path as we go
        pathStr = ""

        for p in item.path
          pathStr += Path.sep + p
          if !(pathStr of node.children)
            console.debug "Adding " + pathStr
            node.children[pathStr] = {children: {}, parent: node, name: p}

          node = node.children[pathStr]

        # Node should be pointing to the leaf
        node.meta = item.meta
        node.parent.keep = true

      console.debug @tree

      # Now reduce the tree and add meta data
      @reduceTree(@tree.root, "root", 0)
      console.debug @tree

    refreshUITree: (node=@tree.root, name="root", parentUI=null, level=0) ->
      return unless @tree?

      # New root
      if level == 0
        @treeUI.empty()
        parentUI = @treeUI

      # Depth first...
      for path of node.children
        # add this node to current parent and use as parent for the rest
        currentElement = @viewForItem(node.children[path])
        parentUI.append(currentElement)

        # If not a file item... recurse
        if !node.children[path].isFile
          # The parent node is actually the <ol> element...
          olParent = currentElement.find('ol.list-tree.entries').first()
          @refreshUITree(node.children[path], path, olParent, level+1)



    viewForItem: (node) ->
      icon = switch
        when node.isFolder then 'icon-file-directory'
        when node.isFile then 'icon-file-symlink-file'
        when node.isServer then 'icon-server'
        else 'icon-file-text'

      if node.isServer or node.isFolder
        $$ ->
          @li class: 'list-nested-item folder', =>
              @div class: 'header list-item', =>
                  @span class: 'icon '+ icon, 'data-name' : node.name, title : node.name, node.name
              @ol class: 'list-tree entries'
      else
        $$ ->
          @li class: 'list-item file', =>
            @span class: 'icon '+ icon, 'data-name' : node.name, title : node.name, node.name
