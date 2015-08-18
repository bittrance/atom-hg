HgRepository = require './hg-repository'
# Checks whether a valid `.hg` directory is contained within the given
# directory or one of its ancestors. If so, a Directory that corresponds to the
# `.hg` folder will be returned. Otherwise, returns `null`.
#
# * `directory` {Directory} to explore whether it is part of a hg repository.
findHgRepoRootDirectorySync = (directory) ->
  # TODO: Fix node-pathwatcher/src/directory.coffee so the following methods
  # can return cached values rather than always returning new objects:
  # getParent(), getFile(), getSubdirectory().
  hgDir = directory.getSubdirectory('.hg')
  if hgDir.existsSync?() and hgDir.getSubdirectory('store').existsSync()
    return directory
  else if directory.isRoot()
    return null
  else
    findHgRepoRootDirectorySync(directory.getParent())

# Provider that conforms to the atom.repository-provider@0.1.0 service.
module.exports =
class HgRepositoryProvider
  constructor: (@project) ->
    # Keys are real paths to the rootPath of hg-Repo
    # Values are the corresponding hgRepository objects.
    @pathToRepository = []

  # Returns a {Promise} that resolves with either:
  # * {HgRepository} if the given directory has a hg repository.
  # * `null` if the given directory does not have a hg repository.
  repositoryForDirectory: (directory) ->
    # TODO: Currently, this method is designed to be async, but it relies on a
    # synchronous API. It should be rewritten to be truly async.
    Promise.resolve(@repositoryForDirectorySync(directory))

  # Returns either:
  # * {HgRepository} if the given directory has a hg repository.
  # * `null` if the given directory does not have a hg repository.
  repositoryForDirectorySync: (directory) ->
    # Only one HgRepository should be created for each .hg folder. Therefore,
    # we must check directory and its parent directories to find the nearest
    # .hg folder.
    rootDir = findHgRepoRootDirectorySync(directory)
    console.log('getting repo ' + directory + ': ' + rootDir)
    unless rootDir
      return null

    path = rootDir.getPath()
    repo = @pathToRepository[path]?
    unless repo
      repo = HgRepository.open(path, project: @project)
      return null unless repo
      repo.onDidDestroy(=> delete @pathToRepository[path])
      @pathToRepository[path] = repo
      repo.refreshIndex()
      repo.refreshStatus()
    return repo
