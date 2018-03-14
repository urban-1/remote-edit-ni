#
# suda solution for password fields from:
#    https://discuss.atom.io/t/password-fields-when-using-editorview-subview/11061/8
#
{$} = require 'atom-space-pen-views'

module.exports =
  # Gets a view/subview element and maskes the TextEditor with ***
  maskPass: (passwordView) ->
      passwordElement = $(passwordView.element)
      passwordElement.find('div.lines').addClass('password-lines')
      passwordView.getModel().onDidChange =>
        string = passwordView.getModel().getText().split('').map(->
          '*'
        ).join ''

        passwordElement.find('#password-style').remove()
        passwordElement.append('<style id="password-style">.password-lines .line span.syntax--text:before {content:"' + string + '";}</style>')
