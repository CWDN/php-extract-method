{$, TextEditorView, View} = require 'atom-space-pen-views'
SubAtom = require('sub-atom')
Parser = require('./php-parser')

module.exports =
class PhpExtractMethodView extends View
    @config:
        'show-buttons':
            title: 'Show Buttons'
            description: 'Whether to show the cancel and extract buttons'
            type: 'boolean'
            default: 'true'
    @activate: ->
        @view = new PhpExtractMethodView
    @deactivate: ->
        @view.detach()
    @content: ->
        @div class: 'php-extract-method', =>
            @div outlet: 'methodNameForm', =>
                @subview 'methodNameEditor', new TextEditorView(mini:true, placeholderText: 'Enter a method name')
                @div class: 'settings-view', =>
                    @div class: 'section-body', =>
                        @div class: 'control-group', =>
                            @div class: 'controls', =>
                                @label class: 'control-label', =>
                                    @div class: 'setting-title', 'Access Modifier'
                                    @select outlet: 'accessMethodsInput', class: 'form-control', =>
                                        @option value: 'public', 'Public'
                                        @option value: 'protected', 'Protected'
                                        @option value: 'private', 'Private'
                        @div class: 'control-group', =>
                            @div class: 'controls', =>
                                @div class: 'checkbox', =>
                                    @label =>
                                        @input outlet: 'generateDocInput', type: 'checkbox'
                                        @div class: 'setting-title', 'Generate documentation'
                        @div class: 'control-group', =>
                            @div class: 'controls', =>
                                @label class: 'control-label', =>
                                    @div class: 'setting-title', 'Preview'
                                    @pre class: 'preview-area', outlet: 'previewArea'
            @div outlet: 'buttonGroup', class: 'block pull-right', =>
                @button outlet: 'extractButton', class: 'inline-block btn btn-success', 'Extract method'
                @button outlet: 'cancelButton', class: 'inline-block btn', 'Cancel'

    initialize: ->
        @subscriptions = new SubAtom
        @parser = new Parser
        @subscriptions.add atom.commands.add 'atom-text-editor', 'php-extract-method:extract', => @show()
        @subscriptions.add atom.commands.add @element,
            'core:confirm': (event) =>
                @extractMethod()
                event.stopPropagation()
            'core:cancel': (event) =>
                @hide()
                event.stopPropagation()
        @subscriptions.add atom.commands.add @extractButton[0], 'click', => @extractMethod()
        @subscriptions.add atom.commands.add @cancelButton[0], 'click', => @hide()
        @subscriptions.add atom.config.observe 'php-extract-method.show-buttons', (show) =>
            if show
                $(@buttonGroup[0]).show()
            else
                $(@buttonGroup[0]).hide()

        @generateDocs = false

        @methodNameEditor.getModel().onDidChange () =>
            @methodBody = @buildMethod
            $(@previewArea).text(@methodBody)

        @subscriptions.add @accessMethodsInput[0], 'change', '', (event) =>
            @methodBody = @buildMethod
            $(@previewArea).text(@methodBody)

        @subscriptions.add @generateDocInput[0], 'change', '', (event) =>
            @generateDocs = !@generateDocs
            @methodBody = @buildMethod
            $(@previewArea).text(@methodBody)

        @attach()

    toggle: ->
        if @hasParent()
            @detach
        else
            @attach()

    detach: ->
        return unless @hasParent()
        @subscriptions.dispose()
        super

    confirm: ->
        @detach()

    attach: ->
        @panel ?= atom.workspace.addModalPanel(item: this)
        @panel.hide()

    show: ->
        @panel.show()
        @activeEditor = atom.workspace.getActiveTextEditor()
        @parser.setActiveEditor(@activeEditor)
        @methodNameEditor.focus()
        @highlighted = @activeEditor.getSelectedText()
        find = new RegExp("^#{@activeEditor.getTabText()}#{@activeEditor.getTabText()}", 'mg')
        @strippedHighlighted = @highlighted.replace(find, "#{@activeEditor.getTabText()}")

        @methodBody = @buildMethod
        $(@previewArea).text(@methodBody)

    hide: =>
        @panel.hide()
        @methodNameEditor.setText('')
        activeView = atom.views.getView(@activeEditor)
        if activeView == null
            return
        activeView.focus()

    buildMethod: =>
        return @parser.buildMethod(
            $(@accessMethodsInput).val(),
            @methodNameEditor.getText(),
            @strippedHighlighted,
            @generateDocs
        )

    extractMethod: =>
        methodCall = @parser.buildMethodCall(
            @methodNameEditor.getText(),
            @highlighted
        )
        @activeEditor.insertText(methodCall)

        highlightedBufferPosition = @activeEditor.getSelectedBufferRange().end
        row = 0
        loop
            row++
            descriptions = @activeEditor.scopeDescriptorForBufferPosition(
                [highlightedBufferPosition.row + row, @activeEditor.getTabLength()]
            )
            indexOfDescriptor = descriptions.scopes.indexOf('punctuation.section.scope.end.php')
            break if indexOfDescriptor == descriptions.scopes.length - 1 || row == @activeEditor.getLineCount()

        replaceRange = [
            [highlightedBufferPosition.row + row, @activeEditor.getTabLength()],
            [highlightedBufferPosition.row + row, @activeEditor.getTabLength() + Infinity]
        ]
        previousText  = @activeEditor.getTextInBufferRange(replaceRange)
        newMethodBody =  @parser.buildMethodWithTabsAndDocs(
            $(@accessMethodsInput).val(),
            @methodNameEditor.getText(),
            @highlighted
        )
        @activeEditor.setTextInBufferRange(
            replaceRange,
            "#{previousText}\n\n#{newMethodBody}\n"
        )

        @hide()
