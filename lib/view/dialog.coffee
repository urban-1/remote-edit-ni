{$, $$, View, TextEditorView} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'
Passwd = require './passwd'

module.exports =
class Dialog extends View
  @content: ({prompt, @type} = {}) ->
    @div class: 'dialog', =>
      @label prompt, class: 'icon', outlet: 'promptText'
      @p class: 'hidden', outlet: 'promptDetail'
      @subview 'miniEditor', new TextEditorView(mini: true)
      @div class: 'error-message', outlet: 'errorMessage'

  initialize: ({@prompt, iconClass, @type, @detail} = {}) ->
    @promptText.addClass(iconClass) if iconClass

    @disposables = new CompositeDisposable
    @disposables.add atom.commands.add 'atom-workspace',
      'core:confirm': => @onConfirm(@miniEditor.getText())
      'core:cancel': (event) =>
        @cancel()
        event.stopPropagation()

    @miniEditor.getModel().onDidChange => @showError()
    @miniEditor.on 'blur', => @cancel()

    if @type == "password"
      Passwd.maskPass(@miniEditor)

    if @detail
      @promptDetail.html(@detail)
      @promptDetail.removeClass('hidden')

  onConfirm: (value) ->
    @callback?(undefined, value)
    @cancel()
    value

  showError: (message='') ->
    @errorMessage.text(message)
    @flashError() if message

  destroy: ->
    @disposables.dispose()

  cancel: ->
    @cancelled()
    @restoreFocus()
    @destroy()

  cancelled: ->
    @hide()

  toggle: (@callback) ->
    if @panel?.isVisible()
      @cancel()
    else
      @show()

  show: () ->
    @panel ?= atom.workspace.addModalPanel(item: this)
    @panel.show()
    @storeFocusedElement()
    @miniEditor.focus()

  hide: ->
    @panel?.hide()

  storeFocusedElement: ->
    @previouslyFocusedElement = $(document.activeElement)

  restoreFocus: ->
    @previouslyFocusedElement?.focus()
