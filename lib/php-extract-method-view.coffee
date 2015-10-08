{$, TextEditorView, View} = require 'atom-space-pen-views'
SubAtom = require('sub-atom')

module.exports =
    class PhpExtractMethodView extends View
        @activate: ->
            view = new PhpExtractMethodView
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
                @div class: 'block pull-right', =>
                    @button outlet: 'extractButton', class: 'inline-block btn btn-success', 'Extract method'
                    @button outlet: 'cancelButton', class: 'inline-block btn', 'Cancel'

        initialize: ->
            @subscriptions = new SubAtom
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
            @generateDocs = false

            @methodNameEditor.getModel().onDidChange () =>
                @methodBody = @buildMethod($(@accessMethodsInput).val(), @methodNameEditor.getText(), @strippedHighlighted)
                $(@previewArea).text(@methodBody)

            @subscriptions.add @accessMethodsInput[0], 'change', '', (event) =>
                @methodBody = @buildMethod($(@accessMethodsInput).val(), @methodNameEditor.getText(), @strippedHighlighted)
                $(@previewArea).text(@methodBody)

            @subscriptions.add @generateDocInput[0], 'change', '', (event) =>
                @generateDocs = !@generateDocs
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
            @methodNameEditor.focus()
            @highlighted = @activeEditor.getSelectedText()
            find = new RegExp("^#{@activeEditor.getTabText()}#{@activeEditor.getTabText()}", 'mg')
            @strippedHighlighted = @highlighted.replace(find, "#{@activeEditor.getTabText()}")
            @methodBody = @buildMethod($(@accessMethodsInput).val(), @methodNameEditor.getText(), @strippedHighlighted)
            $(@previewArea).text(@methodBody)

        hide: ->
            @panel.hide()
            @methodNameEditor.setText('')
            atom.views.getView(@activeEditor).focus();

        extractMethod: ->
            @activeEditor.insertText(@buildMethodCall(@methodNameEditor.getText(), @highlighted))
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

            @hide()

        buildMethod: (accessModifier, methodName, methodBody) ->
            if @activeEditor == undefined
                return
            parameters = @buildParameters methodBody
            methodBody = "#{accessModifier} function #{methodName}(#{parameters.join ', '})\n{\n#{@activeEditor.getTabText()}#{methodBody}\n}"
            docs = @buildDocumentation methodName, parameters
            return docs + methodBody

        buildMethodWithTabs: (accessModifier, methodName, methodBody) ->
            if @activeEditor == undefined
                return
            parameters = @buildParameters methodBody
            methodBody = "#{@activeEditor.getTabText()}#{accessModifier} function #{methodName}(#{parameters.join ', '})\n#{@activeEditor.getTabText()}{\n#{@activeEditor.getTabText()}#{@activeEditor.getTabText()}#{methodBody}\n#{@activeEditor.getTabText()}}"
            docs = @buildDocumentation methodName, parameters, true
            return docs + methodBody

        buildMethodCall: (methodName, methodBody, variable) ->
            methodCall = "$this->#{methodName}(#{@buildParameters(methodBody)});"
            if variable != undefined
                methodCall = "$#{variable} = #{methodCall}"
            return methodCall

        buildParameters: (methodBody) ->
            if methodBody == undefined
                return []
            lines = methodBody.split('\n')
            declaredVariables = ['$this']
            parameters = []
            openFunctionBrackets = 0
            findUse = false
            for line in lines
                lineVariables = []
                useVariables = []
                # Checking for comments
                if line.match(/^\s*(\/\/|\/\*\*|\*)/)
                    continue

                if findUse
                    useVariables = @lookForUseVariables(line)
                    if useVariables.length > 0
                        lineVariables.concat useVariables
                        findUse = false

                if line.match(/(function)/)
                    openFunctionBrackets++
                    if openFunctionBrackets == 1
                        useVariables = @lookForUseVariables(line)
                        findUse = true
                        if useVariables.length > 0
                            findUse = false
                            lineVariables.concat useVariables


                if useVariables.length > 0
                    for useVariable in useVariables
                        if declaredVariables.indexOf useVariable == -1
                            parameters.push useVariable

                if openFunctionBrackets > 0
                    if line.match(/(})/)
                        openFunctionBrackets--
                    if  openFunctionBrackets == 0
                        findUse = false
                    continue

                newDeclaredVariables = @stripExtra line.match(/(\$\w+\s*=)|(as\s*\$\w+)/g)
                declaredVariables = declaredVariables.concat newDeclaredVariables
                declaredVariables = @makeUnique declaredVariables
                line = line.replace /(catch\s?\(.*\))/g, ''
                allVariables = line.match /(\$\w+)/g
                if allVariables
                    newParameters = allVariables.filter (n) ->
                        return declaredVariables.indexOf(n) == -1
                    parameters = parameters.concat newParameters
            return @makeUnique(parameters)

        buildDocumentation: (methodName, parameters, tabs = false) ->
            if !@generateDocs
                return ''
            docs = "/**\n"
            if tabs
                docs = "#{@activeEditor.getTabText()}" + docs
            docs += @buildDocumentationLine " [#{methodName} description]\n", tabs
            for parameter in parameters
                docs += @buildDocumentationLine " @param [type] #{parameter} [description]\n", tabs

            docs += @buildDocumentationLine "/\n", tabs
            return docs

        buildDocumentationLine: (content, tabs = false) ->
            if tabs
                return "#{@activeEditor.getTabText()} *#{content}"
            return " *#{content}"

        makeUnique: (array) ->
            return array.filter (item, pos, self) ->
                return self.indexOf(item) == pos;

        stripExtra: (array) ->
            if array == null
                return null
            return array.map (item) ->
                return item.replace(/(\s*=)|(as\s*)/, '')

        lookForUseVariables: (line) ->
            useVariables = line.match(/use\s*\((.+)\)/)
            if useVariables != null
                useVariables = useVariables[1]
                useVariables = useVariables.split(',').map (variable) ->
                    return variable.trim()
                return useVariables
            return []
