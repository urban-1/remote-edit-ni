{$, $$, TextEditorView} = require 'atom-space-pen-views'
{View} = require 'space-pen'
{CompositeDisposable, Emitter, TextEditor} = require 'atom'
LocalFile = require '../model/local-file'

Dialog = require './dialog'
MiniTreeView = require './tree-view'
ElectronDialog = require('electron').remote.dialog


fs = require 'fs'
os = require 'os'
async = require 'async'
util = require 'util'
path = require 'path'
_ = require 'underscore-plus'
mkdirp = require 'mkdirp'
moment = require 'moment'
upath = require 'upath'
try
  pfolders = require 'platform-folders'
catch err
  console.debug 'Platform folders could not be loaded! Files will be stored in regular temp location'
  pfolders = undefined

module.exports =
  class FilesView extends View

    @content: ->
      @div class: 'remote-edit-tree-views remote-edit-resizer tool-panel', 'data-show-on-right-side': false, =>
        @div class: 'tab-bar', =>
          @div class: 'tab active', =>
            @div class: 'title', 'Remote edit'
            @div class: 'close-icon', click: 'hide'
        @subview 'treeView', new MiniTreeView()
        @div class: 'remote-edit-panel-toggle', =>
          @span class: 'before  icon-chevron-up'
          @span class: 'middle icon-unfold'
          @span class: 'after icon-chevron-down'
        @div class: 'remote-edit-info focusable-panel', click: 'clickInfo', =>
          @div class: 'remote-edit-message', outlet: 'message'
          @p class: 'remote-edit-server', =>
            @span class: 'remote-edit-server-type inline-block octicon-clippy', 'Host:'
            @span class: 'remote-edit-server-alias inline-block highlight', outlet: 'server_alias', 'unknown'
          @p class: 'remote-edit-folder text-bold', =>
            @span 'Folder: '
            @span outlet: 'server_folder', 'unknown'

        @div class: 'remote-edit-file-list', outlet: 'listHidable', =>
          # @tag 'atom-text-editor', 'mini': true, class: 'native-key-bindings', outlet: 'filter'
          # Gettext does not exist cause there is no model behind this...
          @input class: 'remote-edit-filter-text native-key-bindings', tabindex: 1, outlet: 'filter'
          @div class: 'remote-edit-file-scroller', outlet: 'scroller', =>
            @ol class: 'list-tree full-menu focusable-panel', tabindex: 1, outlet: 'list'
        @div class: 'remote-edit-resize-handle', outlet: 'resizeHandle'

    doFilter: (e) ->
      switch e.keyCode
        when 13
          toOpen = @filter.val()
          if @filter.val()[0] == "." or @filter.val()[0] != "/"
            toOpen = @path + "/" + @filter.val()

          @openDirectory(toOpen, (err) =>
            if err?
              @setError("Could not open location")
            else
              @filter.val("")
            )
          return

      # Hide the elements that do not match the filter's value
      if @filter.val().length > 0
        @list.find('li span').each (index, item) =>
          if ! $(item).text().match(@filter.val())
            $(item).addClass('hidden')
          else
            $(item).removeClass('hidden')
      else
        @list.find('li span').removeClass('hidden')

      e.preventDefault()


    initialize: (@host) ->
      @emitter = new Emitter
      @disposables = new CompositeDisposable
      @listenForEvents()
      @cutPasteBuffer = {}
      @treeView.setFilesView(@)

      atom.config.observe 'remote-edit-ni.showOpenedTree', (bool) =>
        if bool
          @treeView.removeClass('hidden')
        else
          @treeView.addClass('hidden')

    connect: (connectionOptions = {}, connect_path = false, callback) ->
      console.debug "connect(): re-connecting (FilesView::connect) to path=#{connect_path}"
      dir = upath.normalize(if connect_path then connect_path else if atom.config.get('remote-edit-ni.rememberLastOpenDirectory') and @host.lastOpenDirectory? then @host.lastOpenDirectory else @host.directory)
      async.waterfall([
        (callback) =>
          if @host.usePassword and !connectionOptions.password?
            if @host.password == "" or @host.password == '' or !@host.password?
              async.waterfall([
                (callback) ->
                  passwordDialog = new Dialog({prompt: "Enter password", type: 'password'})
                  passwordDialog.toggle(callback)
              ], (err, result) =>
                connectionOptions = _.extend({password: result}, connectionOptions)
                @show()
                callback(null)
              )
            else
              callback(null)
          else
            callback(null)
        (callback) =>
          if !@host.isConnected()
            @host.close()
            @setMessage("Connecting...")
            @host.connect(callback, connectionOptions)
          else
            callback(null)
        (callback) =>
          @openDirectory(dir, callback)
      ], (err, result) =>
        if err?
          console.error err
          @list.empty()
          if err.code == 450 or err.type == "PERMISSION_DENIED"
            @setError("You do not have read permission to what you've specified as the default directory! See the console for more info.")
          else if err.code is 2 and @path is @host.lastOpenDirectory
            # no such file, can occur if lastOpenDirectory is used and the dir has been removed
            console.debug  "No such file, can occur if lastOpenDirectory is used and the dir has been removed"
            @host.lastOpenDirectory = undefined
            @connect(connectionOptions)
          else if @host.usePassword and (err.code == 530 or err.level == "connection-ssh")
            async.waterfall([
              (callback) ->
                passwordDialog = new Dialog({prompt: "Enter password", type: 'password'})
                passwordDialog.toggle(callback)
            ], (err, result) =>
              @show()
              @connect({password: result})
            )
          else
            @setError(err)

        @list.focus()
        callback?(null)
      )

    getFilterKey: ->
      return "name"

    destroy: ->
      @panel.destroy() if @panel?
      @disposables.dispose()

    cancelled: ->
      @hide()
      @host?.close()
      @destroy()

    toggle: ->
      if @panel?.isVisible()
        @hide()
      else
        @show()

    show: ->
      @panel ?= atom.workspace.addLeftPanel(item: this, visible: true)
      @panel?.show()

    hide: ->
      @panel?.hide()

    viewForItem: (item) ->
      icon = switch
        when item.isDir then 'icon-file-directory'
        when item.isLink then 'icon-file-symlink-file'
        else 'icon-file-text'
      $$ ->
        @li class: 'list-item list-selectable-item two-lines', =>
          @span class: 'primary-line icon '+ icon, 'data-path': item.path, 'data-name' : item.name, title : item.name, item.name
          if item.name != '..'
            @span class: 'text-subtle text-smaller', "S: #{item.size}, M: #{item.lastModified}, P: #{item.permissions}"

    openDirectory: (dir, callback) ->
      dir = upath.normalize(dir)
      @host.invalidate()
      async.waterfall([
        (callback) =>
          if !@host.isConnected()
            @setMessage("Connecting...")
            @host.connect(callback)
          else
            callback(null)
        (callback) =>
          @host.getFilesMetadata(dir, callback)
        (items, callback) =>
          items = _.sortBy(items, 'isFile') if atom.config.get 'remote-edit-ni.foldersOnTop'
          @setItems(items)
          callback(undefined, undefined)
      ], (err, result) =>
        if ! err
          @updatePath(dir)
          @populateInfo()
        else
          @setError(err) if err?

        callback?(err, result)
      )

    populateList: ->
      super
      @setError path.resolve @path

    populateInfo: ->
      @server_alias.html(if @host.alias then @host.alias else @host.hostname)
      @server_folder.html(@path)

    getNewPath: (next) ->
      if (@path[@path.length - 1] == "/")
        @path + next
      else
        @path + "/" + next

    updatePath: (next) =>
      @path = upath.normalize(next)
      @host.lastOpenDirectory = @path
      @server_folder.html(@path)

    # This is the "main" entry point for external components to interact with
    # the left side panel
    setHost: (host, connect_path = false, callback) ->
      # Ensure the panel is visible
      @show()

      # Avoid re-connecting if the hostname is the same
      if @host?.equals(host)
        if connect_path
          @openDirectory(connect_path, callback)
        else
          callback?(null)

        @list.focus()
        return

      @host?.close()
      @host = host

      # Extend the callers' callback with some basic post-connect functions
      @connect({}, connect_path, () =>
        @list.focus()
        @selectInitialItem()
        callback?()
      )


    getDefaultSaveDirForHostAndFile: (file, callback) ->
      async.waterfall([
        (callback) ->
          if pfolders?
            fs.realpath(pfolders.getCacheFolder(), callback)
          else
            fs.realpath(os.tmpdir(), callback)
        (tmpDir, callback) ->
          tmpDir = tmpDir + path.sep + "remote-edit"
          fs.mkdir(tmpDir, ((err) ->
            if err? && err.code == 'EEXIST'
              callback(null, tmpDir)
            else
              callback(err, tmpDir)
            )
          )
        (tmpDir, callback) =>
          tmpDir = tmpDir + path.sep + @host.hashCode() + '_' + @host.username + "-" + @host.hostname + file.dirName
          mkdirp(tmpDir, ((err) ->
            if err? && err.code == 'EEXIST'
              callback(null, tmpDir)
            else
              callback(err, tmpDir)
            )
          )
      ], (err, savePath) ->
        callback(err, savePath)
      )

    openFile: (file) =>
      dtime = moment().format("HH:mm:ss DD/MM/YY")

      async.waterfall([
        (callback) =>
          if !@host.isConnected()
            @setMessage("Connecting...")
            @host.connect(callback)
          else
            callback(null)
        (callback) =>
          @getDefaultSaveDirForHostAndFile(file, callback)
        (savePath, callback) =>
          # savePath = savePath + path.sep + dtime.replace(/([^a-z0-9\s]+)/gi, '').replace(/([\s]+)/gi, '-') + "_" + file.name
          savePath = savePath + path.sep + file.name
          localFile = new LocalFile(savePath, file, dtime, @host)

          uri = path.normalize(savePath)
          filePane = atom.workspace.paneForURI(uri)
          if filePane
            filePaneItem = filePane.itemForURI(uri)
            filePane.activateItem(filePaneItem)

            confirmResult = ElectronDialog.showMessageBox({
                    title: "File Already Opened...",
                    message: "Reopen this file? Unsaved changes will be lost",
                    type: "warning",
                    buttons: ["Yes", "No"]
                })

            if confirmResult
              callback(null, null)
            else
              filePaneItem.destroy()

          if !filePane or !confirmResult
            localFile = new LocalFile(savePath, file, dtime, @host)
            @host.getFile(localFile, callback)
      ], (err, localFile) =>
        if err?
          @setError(err)
          console.error err
        else if localFile
          @host.addLocalFile(localFile)
          uri = "remote-edit://localFile/?localFile=#{encodeURIComponent(JSON.stringify(localFile.serialize()))}&host=#{encodeURIComponent(JSON.stringify(localFile.host.serialize()))}"
          # Create the textEditor but also make sure we clean up on destroy
          # and remove the local file...
          atom.workspace.open(uri, split: 'left').then(
            (textEditor) =>
              textEditor.onDidDestroy(() =>
                  @host.removeLocalFile(localFile)
                  @treeView.removeFile(localFile)
              )
          )
          # Add it to the tree view
          @treeView.addFile(localFile)
      )

    #
    # Called on event listener to handle all actions of the file list
    # TODO: This is async, add callback support if/when needed
    #
    confirmed: (item) ->
      async.waterfall([
        (callback) =>
          if !@host.isConnected()
            dir = if item.isFile then item.dirName else item.path
            @connect({}, dir)
          callback(null)
        (callback) =>
          if item.isFile
            @openFile(item)
          else if item.isDir
            @host.invalidate()
            @openDirectory(item.path, () => @selectInitialItem())
          else if item.isLink
            if atom.config.get('remote-edit-ni.followLinks')
              @openDirectory(item.path, () => @selectInitialItem())
            else
              @openFile(item)
      ], (err, savePath) ->
        callback(err, savePath)
      )

    clickInfo: (event, element) ->
      #console.log event

    resizeStarted: =>
      $(document).on('mousemove', @resizeTreeView)
      $(document).on('mouseup', @resizeStopped)

    resizeStopped: =>
      $(document).off('mousemove', @resizeTreeView)
      $(document).off('mouseup', @resizeStopped)

    resizeVerticalStarted: (e) =>
      @resizeVerticalOffset = e.clientY - @treeView.getHeight()
      $(document).on('mousemove', @resizeVerticalTreeView)
      $(document).on('mouseup', @resizeVerticalStopped)

    resizeVerticalStopped: =>
      $(document).off('mousemove', @resizeVerticalTreeView)
      $(document).off('mouseup', @resizeVerticalTreeView)

    resizeVerticalTreeView: (e) =>
      return @resizeVerticalStopped() unless e.which is 1
      @treeView.setHeight(e.clientY - @resizeVerticalOffset)

    resizeTreeView: ({pageX, which}) =>
      return @resizeStopped() unless which is 1
      width = pageX - @offset().left
      @width(width)

    resizeToFitContent: ->
      @width(1) # Shrink to measure the minimum width of list
      @width(Math.max(@list.outerWidth(), @treeView.treeUI.outerWidth()+10))

    scrollToView: (element, parent) ->
        # element = $(element);
        # parent = $(parent);

        offset = element.offset().top - parent.offset().top + parent.scrollTop();
        height = element.innerHeight();
        offset_end = offset + height;

        visible_area_start = parent.scrollTop();
        visible_area_end = visible_area_start + parent.innerHeight();

        if (offset < visible_area_start)
             parent.scrollTop(offset);
             return false;
        else if (offset_end > visible_area_end)
            parent.scrollTop(parent.scrollTop() + offset_end - visible_area_end + 10);
            return false;

        return true;


    listSelectNext: =>
      item = @getSelectedItem()
      if item.next('li').length == 0
        return

      @deselect()
      item.next('li').addClass('selected').data('select-list-item')
      @scrollToView(@getSelectedItem(), @scroller)

    listSelectPrev: =>
      item = @getSelectedItem()
      if item.prev('li').length == 0
        return

      @deselect()
      item.prev('li').addClass('selected').data('select-list-item')
      @scrollToView(@getSelectedItem(), @scroller)

    listEnter: =>
      item = @getSelectedItem()
      if !item
        return
      @confirmed(item.data('select-list-item'))
      @list.focus()



    listenForEvents: ->

      @list.on 'dblclick', 'li', (e) =>
        @list.focus()
        if $(e.target).closest('li').hasClass('selected')
          false
        @deselect()
        @selectedItem = $(e.target).closest('li').addClass('selected').data('select-list-item')
        if e.which == 1
          @confirmed(@selectedItem)
          e.preventDefault()
          false
        else if e.which == 3
          false

      @list.on 'mousedown', 'li', (e) =>
        @list.focus()
        if $(e.target).closest('li').hasClass('selected')
          false
        @deselect()
        @selectedItem = $(e.target).closest('li').addClass('selected').data('select-list-item')
        e.preventDefault()
        false

      @on 'dblclick', '.remote-edit-resize-handle', =>
        @resizeToFitContent()

      @on 'mousedown', '.remote-edit-resize-handle', (e) =>
        @resizeStarted(e)

      @on 'mousedown', '.remote-edit-panel-toggle', (e) =>
        @resizeVerticalStarted(e)

      @on 'mousedown', '.remote-edit-panel-toggle .after', (e) =>
        if e.which == 1
          @listHidable.addClass("hidden")
          @treeView.removeClass("hidden")
          @treeView.resetHeight()

        e.preventDefault()
        false

      @on 'mousedown', '.remote-edit-panel-toggle .before', (e) =>
        if e.which == 1
          @listHidable.removeClass("hidden")
          @treeView.addClass("hidden")
          @treeView.resetHeight()

        e.preventDefault()
        false

      @on 'mousedown', '.remote-edit-panel-toggle .middle', (e) =>
        if e.which == 1
          @listHidable.removeClass("hidden")
          @treeView.removeClass("hidden")
          @treeView.resetHeight()

        e.preventDefault()
        false

      @filter.on "keyup", (e) =>
        @doFilter(e)

      # Files-view Commands
      @disposables.add atom.commands.add 'atom-workspace', 'filesview:open', =>
        # FIXME: This does not return item's data
        item = @getSelectedItem()
        if item.isFile
          @openFile(item)
        else if item.isDir
          @openDirectory(item)
      @disposables.add atom.commands.add 'atom-workspace', 'filesview:list-select-next', => @listSelectNext()
      @disposables.add atom.commands.add 'atom-workspace', 'filesview:list-select-prev', => @listSelectPrev()
      @disposables.add atom.commands.add 'atom-workspace', 'filesview:list-enter', => @listEnter()
      @disposables.add atom.commands.add 'atom-workspace', 'filesview:previous-folder', =>
        if @path.length > 1
          # Open directory and focus on the list
          @openDirectory(@path + path.sep + '..',
            () =>
              @selectInitialItem()
              @list.focus()
          )
      @disposables.add atom.commands.add 'atom-workspace', 'filesview:list-focus', =>
        @selectInitialItem()
        @list.focus()
      @disposables.add atom.commands.add 'atom-workspace', 'filesview:hide', => @hide()

      # Remote-edit Commands
      @disposables.add atom.commands.add 'atom-workspace', 'remote-edit:set-permissions', => @setPermissions()
      @disposables.add atom.commands.add 'atom-workspace', 'remote-edit:create-folder', => @createFolder()
      @disposables.add atom.commands.add 'atom-workspace', 'remote-edit:create-file', => @createFile()
      @disposables.add atom.commands.add 'atom-workspace', 'remote-edit:reload-folder', => @reloadFolder()
      @disposables.add atom.commands.add 'atom-workspace', 'remote-edit:rename-folder-file', => @renameFolderFile()
      @disposables.add atom.commands.add 'atom-workspace', 'remote-edit:remove-folder-file', => @deleteFolderFile()
      @disposables.add atom.commands.add 'atom-workspace', 'remote-edit:cut-folder-file', => @copycutFolderFile(true)
      @disposables.add atom.commands.add 'atom-workspace', 'remote-edit:paste-folder-file', => @pasteFolderFile()
      @disposables.add atom.commands.add 'atom-workspace', 'remote-edit:reveal-in-browser', => @revealCurrentFile()
      @disposables.add atom.commands.add 'atom-workspace', 'remote-edit:close-all-connections', => @closeAllConnections()

    # Close all connections of remoteEdit, including any open tabs
    closeAllConnections: () =>
      for editor in atom.workspace.getTextEditors()
        if editor.host
          editor.host.close()

      # Now close the files view connection (ours)
      @host?.close()
      @hide()

    # Reveal the current tab/file in browser ONLY if it is a remote RemoteEditEditor
    revealCurrentFile: () ->
        editor = atom.workspace.getActiveTextEditor()
        localFile = editor?.localFile
        if !localFile
            return

        # Show this file
        @revealFile(
            editor?.host,
            localFile.remoteFile.dirName,
            localFile.remoteFile.path
        )

    # Reveal a file in the browser, given the host, the folder path and the
    # file path. This can be called with file=null to change folder.
    revealFile: (host, folder, file) =>
      if file
        @setHost(host, folder, () => @selectItemByPath(file))
      else
        @setHost(host, folder, () => @selectInitialItem())



    # Default selection on focus or on enter directory
    selectInitialItem: () =>
      # Refuse to select if something already selected
      if @getSelectedItem().length
        return

      # Ensure we are not in a empty directory
      if @list.children().length > 1
        @list.children().first().next().addClass('selected')
      else
        @list.children().first().addClass('selected')

    selectItemByPath: (path) ->
      @deselect()
      item = $('li.list-item span[data-path="'+path+'"]').closest('li')
      item.addClass('selected')
      @scrollToView(item, @scroller)

    setItems: (@items=[]) ->
      @message.hide()
      return unless @items?

      @list.empty()
      if @items.length
        for item in @items
          itemView = $(@viewForItem(item))
          itemView.data('select-list-item', item)
          @list.append(itemView)
      else
        @setMessage('No matches found')

    reloadFolder: () =>
      @openDirectory(@path)

    createFolder: () =>
      if typeof @host.createFolder != 'function'
        throw new Error("Not implemented yet!")

      async.waterfall([
        (callback) ->
          nameDialog = new Dialog({prompt: "Enter the name for new folder."})
          nameDialog.toggle(callback)
        (foldername, callback) =>
          @host.createFolder(@path + "/" + foldername, callback)
      ], (err, result) =>
        @openDirectory(@path)
      )

    createFile: () =>
      if typeof @host.createFile != 'function'
        throw new Error("Not implemented yet!")

      async.waterfall([
        (callback) ->
          nameDialog = new Dialog({prompt: "Enter the name for new file."})
          nameDialog.toggle(callback)
        (filename, callback) =>
          @host.createFile(@path + "/" + filename, callback)
      ], (err, result) =>
        @openDirectory(@path)
      )


    renameFolderFile: () =>
      if typeof @host.renameFolderFile != 'function'
        throw new Error("Not implemented yet!")

      if !@selectedItem or !@selectedItem.name or @selectedItem.name == '.'
        return

      async.waterfall([
        (callback) =>
          nameDialog = new Dialog({prompt: """Enter the new name for #{if @selectedItem.isDir then 'folder' else if @selectedItem.isFile then 'file' else 'link'} "#{@selectedItem.name}"."""})
          nameDialog.miniEditor.setText(@selectedItem.name)
          nameDialog.toggle(callback)
        (newname, callback) =>
          @deselect()
          @host.renameFolderFile(@path, @selectedItem.name, newname, @selectedItem.isDir, callback)
      ], (err, result) =>
        @openDirectory(@path)
      )

    deleteFolderFile: () =>
      if typeof @host.deleteFolderFile != 'function'
        throw new Error("Not implemented yet!")

      if !@selectedItem or !@selectedItem.name or @selectedItem.name == '.'
        return

      atom.confirm
        message: "Are you sure you want to delete #{if @selectedItem.isDir then'folder' else if @selectedItem.isFile then 'file' else 'link'}?"
        detailedMessage: "You are deleting: #{@selectedItem.name}"
        buttons:
           'Yes': =>
             @host.deleteFolderFile(@path + "/" + @selectedItem.name, @selectedItem.isDir, () =>
               @openDirectory(@path)
             )
           'No': =>
            @deselect()

      @selectedItem = false


    copycutFolderFile: (cut=false) =>
      if @selectedItem and @selectedItem.name and @selectedItem.name != '.'
        @cutPasteBuffer = {
          name: @selectedItem.name
          oldPath:  @path + "/" + @selectedItem.name
          isDir: @selectedItem.isDir
          cut: cut
          }

    pasteFolderFile: () =>

      if typeof @host.moveFolderFile != 'function'
        throw new Error("Not implemented yet!")

      # We only support cut... copying a folder we need to do recursive stuff...
      if !@cutPasteBuffer.cut
        throw new Error("Copy is Not implemented yet!")

      if !@cutPasteBuffer or !@cutPasteBuffer.oldPath or @cutPasteBuffer.oldPath == '.'
        @setError("Nothing to paste")
        return

      # Construct the new path using the old name
      @cutPasteBuffer.newPath = @path + '/' + @cutPasteBuffer.name

      if !@selectedItem or !@selectedItem.name or @selectedItem.name == '.'
        return

      async.waterfall([
        (newname, callback) =>
          @deselect()
          @host.moveFolderFile(@cutPasteBuffer.oldPath, @cutPasteBuffer.newPath, @cutPasteBuffer.isDir,  () =>
            @openDirectory(@path)
            # reset buffer
            @cutPasteBuffer = {}
          )
      ], (err, result) =>
        @openDirectory(@path)
      )


    setPermissions: () =>
      if typeof @host.setPermissions != 'function'
        throw new Error("Not implemented yet!")

      if !@selectedItem or !@selectedItem.name or @selectedItem.name == '..'
        return

      async.waterfall([
        (callback) =>
          fp = @path + "/" + @selectedItem.name
          Dialog ?= require '../view/dialog'
          permDialog = new Dialog({prompt: "Enter permissions (ex. 0664) for #{fp}"})
          permDialog.toggle(callback)
        (permissions, callback) =>
          @host.setPermissions(@path + "/" + @selectedItem.name, permissions, callback)
        ], (err) =>
          @deselect()
          if !err?
            @openDirectory(@path)
        )

    deselect: () ->
      @list.find('li.selected').removeClass('selected');

    getSelectedItem: ->
      return @list.find('li.selected')

    setError: (message='') ->
      @emitter.emit 'info', {message: message, type: 'error'}

    setMessage: (message='') ->
      @message.empty().show().append("<ul class='background-message centered'><li>#{message}</li></ul>")
