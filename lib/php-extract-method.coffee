PhpExtractMethodView = require './php-extract-method-view'
{CompositeDisposable} = require 'atom'

module.exports = PhpExtractMethod =
  phpExtractMethodView: null
  subscriptions: null

  activate: (state) ->

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-text-editor', 'php-extract-method:toggle': => @toggle()

  deactivate: ->
    @subscriptions.dispose()
    @phpExtractMethodView.destroy()

  serialize: ->
    phpExtractMethodViewState: @phpExtractMethodView.serialize()

  toggle: ->
    @phpExtractMethodView = new PhpExtractMethodView()
