module.exports =
class PhpParser

    buildMethod: (accessModifier, methodName, methodBody, buildDocs) =>
        if @activeEditor == undefined
            return
        parameters = @buildParameters methodBody
        methodBody = "#{accessModifier} function #{methodName}(#{parameters.join ', '})\n{\n#{@activeEditor.getTabText()}#{methodBody}\n}"
        if buildDocs
            docs = @buildDocumentation methodName, parameters
            methodBody = docs + methodBody
        return methodBody

    buildMethodWithTabsAndDocs: (accessModifier, methodName, methodBody) =>
        if @activeEditor == undefined
            return
        parameters = @buildParameters methodBody
        methodBody = "#{@activeEditor.getTabText()}#{accessModifier} function #{methodName}(#{parameters.join ', '})\n#{@activeEditor.getTabText()}{\n#{@activeEditor.getTabText()}#{@activeEditor.getTabText()}#{methodBody}\n#{@activeEditor.getTabText()}}"
        docs = @buildDocumentation methodName, parameters, true
        return docs + methodBody

    buildMethodCall: (methodName, methodBody, variable) =>
        parameters = @buildParameters(methodBody).join(', ')
        methodCall = "$this->#{methodName}(#{parameters});"
        if variable != undefined
            methodCall = "$#{variable} = #{methodCall}"
        return methodCall

    buildParameters: (methodBody) =>
        if methodBody == undefined
            return []
        lines = methodBody.split('\n')
        declaredVariables = ['$this']
        parameters = []
        openFunctionBrackets = 0
        initialOpenBracket = true
        firstLine = true
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
                if !initialOpenBracket
                    continue
                initialOpenBracket = false

            newDeclaredVariables = @stripExtra line.match(/(\$\w+\s*=)|(as\s*\$\w+)|(catch.*\$\w+)|(for\s*\(\s*\$\w+)|(list\(\s*(\$\w+,?\s?)+)/g)
            functionVariables = @stripExtra line.match(/(function\s*\(\s*(\$\w+,?\s?)+)/g)
            declaredVariables = declaredVariables.concat newDeclaredVariables
            if !firstLine
                declaredVariables = @makeUnique declaredVariables
            else
                tempDeclaredVariables = declaredVariables.slice()
            line = line.replace /(catch\s?\(.*\))/g, ''
            allVariables = line.match /(\$\w+)/g
            if allVariables
                newParameters = allVariables.filter (variable) ->
                    if firstLine
                        isDeclared = tempDeclaredVariables.indexOf(variable) > -1
                        if isDeclared
                            declaredIndex = tempDeclaredVariables.indexOf(variable)
                            tempDeclaredVariables.splice(declaredIndex, 1)
                            return false
                    else
                        isDeclared = declaredVariables.indexOf(variable) > -1
                        if isDeclared
                            return false

                    if functionVariables == null
                        return true

                    isFunctionParameter = functionVariables.indexOf(variable) > -1
                    if isFunctionParameter
                        functionIndex = functionVariables.indexOf(variable)
                        functionVariables.splice(functionIndex, 1)
                        return false

                    return true
                parameters = parameters.concat newParameters
            firstLine = false
        return @makeUnique(parameters)

    buildDocumentation: (methodName, parameters, tabs = false) =>
        docs = "/**\n"
        if tabs
            docs = "#{@activeEditor.getTabText()}" + docs
        docs += @buildDocumentationLine " [#{methodName} description]\n", tabs
        for parameter in parameters
            docs += @buildDocumentationLine " @param [type] #{parameter} [description]\n", tabs

        docs += @buildDocumentationLine "/\n", tabs
        return docs

    buildDocumentationLine: (content, tabs = false) =>
        if tabs
            return "#{@activeEditor.getTabText()} *#{content}"
        return " *#{content}"

    makeUnique: (array) =>
        return array.filter (item, pos, self) ->
            return self.indexOf(item) == pos;

    stripExtra: (array) =>
        if array == null
            return null
        parsed = array.map (item) ->
            return item.match(/(\$\w+)/g)
        return @flattenArray(parsed)

    lookForUseVariables: (line) =>
        useVariables = line.match(/use\s*\((.+)\)/)
        if useVariables != null
            useVariables = useVariables[1]
            useVariables = useVariables.split(',').map (variable) ->
                return variable.trim()
            return useVariables
        return []

    setActiveEditor: (editor) =>
        @activeEditor = editor

    flattenArray: (array) =>
        unless array?
            return null
        else if array.length is 0
            return []
        else
            return (array.reduce (l,r)->l.concat(r))
