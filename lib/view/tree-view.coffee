{$, $$, View} = require 'atom-space-pen-views'
Path = require 'path'


module.exports =
  class MiniTreeView extends View
    initialize: ->
      # Reduced tree (the one we display)
      @tree = {root: {children:{}, parent: null, name: "root"}}

    @content: ->
      @div class: 'remote-edit-opened-tree', =>
        @div class: 'remote-edit-scroller order--center', =>
          @div class: 'remote-edit-scroller', outlet: 'scroller', =>
            @span class: 'remote-edit-treeview-header inline-block', 'Open Files'
            @ol class: 'list-tree full-menu focusable-panel', tabindex: -1, outlet: 'treeUI'
        @div class: 'remote-edit-resize-handle', outlet: 'resizeHandle'

    splitPathParts: (file, hostname) ->
      # explode paths
      pathParts = file.path.split(Path.sep)
      if pathParts[0] == ""
        pathParts.shift()

      pathParts.unshift(hostname)
      return pathParts

    addFile: (file, hostname) =>
      # Add hostname if not in already
      node = @tree.root

      pathParts = @splitPathParts(file, hostname)
      console.log pathParts

      # Build path as we go
      pathStr = ""

      count = 0
      for p in pathParts
        count++
        pathStr += Path.sep + p

        # If there move to next node and continue
        if pathStr of node.children
          node = node.children[pathStr]
          continue

        console.debug "Adding " + pathStr
        node.children[pathStr] = {children: {}, parent: node, name: p}

        if count == 2
          node.isServer = true
        else if count > 2
          node.isFolder = true

        node = node.children[pathStr]

      # Node should be pointing to the leaf
      node.meta = file
      delete node["isFolder"]
      node.isFile = true

      console.debug @tree
      @refreshUITree()

    removeFile: (file, hostname) =>
      pathParts = @splitPathParts(file, hostname)
      node = @tree.root
      console.debug @tree

      pathStr = ""
      for p in pathParts
        pathStr += Path.sep + p
        if !(pathStr of node.children)
          break

        node = node.children[pathStr]

      # Check if we found it
      if pathParts[pathParts.length - 1] != node.name
        console.debug "Could not locate node..."
        return

      # Delete nodes walking up
      while node.parent
        parent = node.parent
        delete parent.children[pathStr]
        length = (k for own k of parent.children).length
        if length == 0
          node = parent
          pathStr = Path.dirname(pathStr)
        else
          break

      @refreshUITree()

    #
    # UI
    #
    refreshUITree: (node=@tree.root, name="root", parentUI=null, level=0) ->
      return unless @tree?

      length = (k for own k of node.children).length

      # New root
      if level == 0
        @treeUI.empty()
        parentUI = @treeUI

      # Depth first...
      for path of node.children

        # if folder with one child which is folder, do not display - mark skipping
        child = node.children[path]
        childLength = (k for own k of child.children).length
        skippingCurrent = false

        if child.isFolder and childLength == 1
          # Ensure that the only child is actually another folder
          innerChild = null
          for i of child.children
            innerChild = child.children[i]

          if innerChild.isFolder
            skippingCurrent = true

        if skippingCurrent
          # use the same list we were given...
          olParent = parentUI
        else
          console.debug parentUI
          # here we either have a legit folder or a server or a file
          # Add this node to current parent and use as parent for the rest
          currentElement = @viewForItem(child)
          parentUI.append(currentElement)
          # The parent node is actually the <ol> element...
          olParent = currentElement.find('ol.list-tree.entries').first()

        # If not a file item... recurse based on the current element set above
        if !child.isFile
          @refreshUITree(child, path, olParent, level+1)



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
