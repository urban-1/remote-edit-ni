{$, $$, View} = require 'atom-space-pen-views'

module.exports =
  class MiniTreeView extends View
    initialize: ->
      @items = []
      
    @content: ->
      @div =>
        @div class: 'remote-edit-scroller order--center', =>
          @div class: 'remote-edit-scroller', outlet: 'scroller', =>
            @ol class: 'list-tree full-menu focusable-panel', tabindex: -1, outlet: 'tree'
        @div class: 'remote-edit-resize-handle', outlet: 'resizeHandle'

    addItem: (@item) ->
      return unless @item?


    viewForItem: (item) ->
      icon = switch
        when item.isDir then 'icon-file-directory'
        when item.isLink then 'icon-file-symlink-file'
        else 'icon-file-text'
      $$ ->
        @li class: 'list-item list-selectable-item two-lines', =>
          @span class: 'primary-line icon '+ icon, 'data-name' : item.name, title : item.name, item.name
