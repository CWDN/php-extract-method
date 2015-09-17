{$, TextEditorView, View} = require 'atom-space-pen-views'
SubAtom = require('sub-atom')

module.exports =
    class PhpExtractMethodView extends View
        detaching: false
        @content: ->
            @div class: 'php-extract-method', =>
                @div class: "panel", =>
                    @div class: "panel-heading", =>
                        @span "Extract selected text to method"
                    @div class: "panel-body padded", =>
                        @div outlet: 'methodNameForm', =>
                            @subview 'methodNameEditor', new TextEditorView(mini:true, placeholderText: 'Enter a method name')
                            @div class: "settings-view", =>
                                @div class: "control-group", =>
                                    @div class: "controls", =>
                                        @label class: "control-label", =>
                                            @div class: "setting-title", "Access Modifier"
                                            @select outlet: 'accessMethodsInput', class: "form-control", =>
                                                @option value: "public", "Public"
                                                @option value: "protected", "Protected"
                                                @option value: "private", "Private"
                                @div class: "preview-area-container", =>
                                    @label class: "control-label", =>
                                        @div class: "setting-title", "Preview Area"
                                        @pre outlet: 'previewArea', class: "preview-area"
                    @div class: "panel-footer padded", =>
                        @div class: 'pull-right', =>
                            @button outlet: 'extractButton', class: 'btn btn-primary', "Extract method to clipboard"

        initialize: ->
            @subscriptions = new SubAtom
            @subscriptions.add atom.commands.add 'atom-text-editor', 'core:confirm', => @extractMethod()
            @subscriptions.add atom.commands.add 'atom-text-editor', 'core:cancel', => @detach()
            @subscriptions.add atom.commands.add @extractButton[0], 'click', => @extractMethod()
            @activeEditor = atom.workspace.getActiveTextEditor()
            @highlighted = @activeEditor.getSelectedText()
            find = new RegExp("#{@activeEditor.getTabText()}#{@activeEditor.getTabText()}", 'g')
            @strippedHighlighted = @highlighted.replace(find, "#{@activeEditor.getTabText()}")

            @methodNameEditor.getModel().onDidChange () =>
                @methodBody = @buildMethod($(@accessMethodsInput).val(), @methodNameEditor.getText(), @strippedHighlighted)
                $(@previewArea).text(@methodBody)

            @subscriptions.add @accessMethodsInput[0], 'change', '', (event) =>
                @methodBody = @buildMethod($(@accessMethodsInput).val(), @methodNameEditor.getText(), @strippedHighlighted)
                $(@previewArea).text(@methodBody)

            @methodBody = @buildMethod($(@accessMethodsInput).val(), @methodNameEditor.getText(), @strippedHighlighted)
            $(@previewArea).text(@methodBody)
            @attach()

        toggle: ->
            if @hasParent()
                @detach
            else
                @attach()

        detach: ->
            return unless @hasParent()
            @methodNameEditor.setText('')
            @subscriptions.dispose()
            super

        confirm: ->
            @detach()

        attach: ->
            @panel ?= atom.workspace.addModalPanel(item: this)
            @panel.show()
            @methodNameEditor.focus()

        extractMethod: ->
            @activeEditor.insertText(@buildMethodCall(@methodNameEditor.getText()))
            highlightedBufferPosition = @activeEditor.getSelectedBufferRange().end
            row = 0
            loop
                row++
                descriptions = @activeEditor.scopeDescriptorForBufferPosition(
                    [highlightedBufferPosition.row + row, @activeEditor.getTabLength()]
                )
                indexOfDescriptor = descriptions.scopes.indexOf('punctuation.section.scope.end.php')
                break if indexOfDescriptor == descriptions.scopes.length - 1

            replaceRange = [
                [highlightedBufferPosition.row + row, @activeEditor.getTabLength()],
                [highlightedBufferPosition.row + row, @activeEditor.getTabLength() + Infinity]
            ]
            previousText  = @activeEditor.getTextInBufferRange(replaceRange)
            newMethodBody =  @buildMethodWithTabs(
                $(@accessMethodsInput).val(),
                @methodNameEditor.getText(),
                @highlighted
            )
            @activeEditor.setTextInBufferRange(
                replaceRange,
                "#{previousText}\n\n#{newMethodBody}\n"
            )

            @detach()

        buildMethod: (accessModifier, methodName, methodBody) ->
            return "#{accessModifier} function #{methodName}()\n{\n#{@activeEditor.getTabText()}#{methodBody}\n}"

        buildMethodWithTabs: (accessModifier, methodName, methodBody) ->
            return "#{@activeEditor.getTabText()}#{accessModifier} function #{methodName}()\n#{@activeEditor.getTabText()}{\n#{@activeEditor.getTabText()}#{@activeEditor.getTabText()}#{methodBody}\n#{@activeEditor.getTabText()}}"

        buildMethodCall: (methodName, variable) ->
            methodCall = "$this->#{methodName}();"
            if variable != undefined
                methodCall = "$#{variable} = #{methodCall}"
            return methodCall
