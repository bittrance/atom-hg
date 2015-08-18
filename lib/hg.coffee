HgRepositoryProvider = require './hg-repository-provider'

module.exports =
  activate: -> null

  deactivate: -> null

  getRepositoryProviderService: ->
    new HgRepositoryProvider(atom.project)
