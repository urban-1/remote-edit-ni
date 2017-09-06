{$, $$, View} = require 'atom-space-pen-views'
Path = require 'path'


module.exports =
  class MiniTreeView extends View
    initialize: (filesView) ->
      # Reduced tree (the one we display)
      @tree = {root: {children:{}, parent: null, name: "root"}}
      @filesView = filesView
      @listenForEvents()

    @content: ->
      @div class: 'remote-edit-opened-tree', =>
        @span class: 'remote-edit-treeview-header inline-block', 'Open Files'
        @div class: 'remote-edit-file-scroller order--center', =>
          @div class: 'remote-edit-file-scroller', outlet: 'scroller', =>
            @ol class: 'list-tree full-menu focusable-panel', tabindex: -1, outlet: 'treeUI'
        @div class: 'remote-edit-resize-handle', outlet: 'resizeHandle'

    splitPathParts: (localFile) ->
      # explode paths
      pathParts = localFile.remoteFile.path.split(Path.sep)
      if pathParts[0] == ""
        pathParts.shift()

      pathParts.unshift(localFile.host.hostname)
      return pathParts

    addFile: (localFile) =>
      # Add hostname if not in already
      node = @tree.root

      pathParts = @splitPathParts(localFile)
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
      node.meta = localFile
      delete node["isFolder"]
      node.isFile = true

      console.debug @tree
      @refreshUITree()

    removeFile: (localFile) =>
      pathParts = @splitPathParts(localFile)
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
          currentElement.data('node', child)
          currentElement.data('node-path', path)
          parentUI.append(currentElement)
          # The parent node is actually the <ol> element...
          olParent = currentElement.find('ol.list-tree.entries').first()

        # If not a file item... recurse based on the current element set above
        if !child.isFile
          @refreshUITree(child, path, olParent, level+1)

    deselect: ->
        @treeUI.find('li.selected').removeClass('selected');

    listenForEvents: ->
      @treeUI.on 'mousedown', (e) =>
        # console.debug e
        # e.preventDefault()
        # false


      # Folder/Server Click
      @on 'mousedown', 'div.list-item', (e) =>
        if e.which == 3
          return

        if e.which == 1
            @deselect()
            uiNode = $(e.target).closest('li')
            node = uiNode.addClass('selected').data('node')

            if node.isCollapsed
              console.log("Expanding")
              node.isCollapsed = false
              uiNode.removeClass('collapsed')
            else
              console.log("Colapsing")
              node.isCollapsed = true
              uiNode.addClass('collapsed')

      # File Click
      @on 'mousedown', 'li.list-item', (e) =>
        if e.which == 1
            @deselect()
            node = $(e.target).closest('li').addClass('selected').data('node')
            console.log(node)

    viewForItem: (node) ->
      icon = switch
        when node.isFolder then 'icon-file-directory'
        when node.isFile then 'icon-file-symlink-file'
        when node.isServer then 'icon-server'
        else 'icon-file-text'

      if node.isServer or node.isFolder
        $$ ->
          @li class: 'list-nested-item folder ', =>
              @div class: 'header list-item', =>
                  @span class: 'icon '+ icon, 'data-name' : node.name, title : node.name, node.name
              @ol class: 'list-tree entries'
      else
        $$ ->
          @li class: 'list-item file', =>
            @span class: 'icon '+ icon, 'data-name' : node.name, title : node.name, node.name
