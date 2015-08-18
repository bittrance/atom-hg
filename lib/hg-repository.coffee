{Emitter, Disposable, CompositeDisposable} = require 'event-kit'

crypto = require 'crypto'
deepEqual = require 'deep-equal'
hg = require 'hg'
nPath = require 'path'
jsdiff = require 'diff'

module.exports =
class HgRepository

  devMode: atom.inDevMode()

  ###
  Section: Construction and Destruction
  ###

  # Public: Creates a new HgRepository instance.
  #
  # * `path` The {String} path to the Mercurial repository to open.
  # * `options` An optional {Object} with the following keys:
  #   * `refreshOnWindowFocus` A {Boolean}, `true` to refresh the index and
  #     statuses when the window is focused.
  #
  # Returns a {HgRepository} instance or `null` if the repository could not be opened.
  @open: (path, options) ->
    return null unless path
    try
      new HgRepository(path, options)
    catch err
      console.error(err)
      null

  constructor: (path, options={}) ->
    @emitter = new Emitter
    @subscriptions = new CompositeDisposable
    @repo = new hg.HGRepo(path)
    @parsers = new hg.Parsers('3.4')

    @statuses = {}
    @diffstats = {}
    @linediffs = {}
    @upstream = {ahead: 0, behind: 0}

    {@project, refreshOnWindowFocus} = options

    refreshOnWindowFocus ?= true
    if refreshOnWindowFocus
      onWindowFocus = =>
        @refreshIndex()
        @refreshStatus()

      window.addEventListener 'focus', onWindowFocus
      @subscriptions.add new Disposable(-> window.removeEventListener 'focus', onWindowFocus)

    if @project?
      @project.getBuffers().forEach (buffer) => @subscribeToBuffer(buffer)
      @subscriptions.add @project.onDidAddBuffer (buffer) => @subscribeToBuffer(buffer)

  # Public: Destroy this {HgRepository} object.
  #
  # This destroys any tasks and subscriptions and releases the HgRepository
  # object
  destroy: ->
    if @emitter?
      @emitter.emit 'did-destroy'
      @emitter.dispose()
      @emitter = null

    # if @statusTask?
      # @statusTask.terminate()
      # @statusTask = null

    if @repo?
      # @repo.release()
      @repo = null

    if @subscriptions?
      @subscriptions.dispose()
      @subscriptions = null

  ###
  Section: Event Subscription
  ###

  # Public: Invoke the given callback when this HgRepository's destroy() method
  # is invoked.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  # Public: Invoke the given callback when a specific file's status has
  # changed. When a file is updated, reloaded, etc, and the status changes, this
  # will be fired.
  #
  # * `callback` {Function}
  #   * `event` {Object}
  #     * `path` {String} the old parameters the decoration used to have
  #     * `pathStatus` {Number} representing the status. This value can be passed to
  #       {::isStatusModified} or {::isStatusNew} to get more information.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeStatus: (callback) ->
    @emitter.on 'did-change-status', callback

  # Public: Invoke the given callback when a multiple files' statuses have
  # changed. For example, on window focus, the status of all the paths in the
  # repo is checked. If any of them have changed, this will be fired. Call
  # {::getPathStatus(path)} to get the status for your path of choice.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeStatuses: (callback) ->
    @emitter.on 'did-change-statuses', callback

  ###
  Section: Repository Details
  ###

  # Returns the corresponding {Repository}
  getRepo: () ->
    if @repo?
      return @repo
    else
      throw new Error("Repository has been destroyed")

  # Public: A {String} indicating the type of version control system used by
  # this repository.
  getType: -> 'hg'

  # Public: Returns the {String} path of the repository.
  getPath: -> @repo.path

  # Public: Returns the {String} working directory path of the repository.
  getWorkingDirectory: -> @repo.path

  # Public: Returns true if at the root, false if in a subfolder of the
  # repository.
  isProjectAtRoot: -> @projectAtRoot ?= @project?.relativize(@getPath()) is ''

  # Public: Makes a path relative to the repository's working directory.
  relativize: (path) -> null

  # Slash win32 path
  slashPath: (path) ->
    return path unless path
    if process.platform is 'win32'
      return path.replace(/\\/g, '/')
    else
      return path

  # Public: Returns true if the given branch exists.
  hasBranch: (branch) -> null

  # Public: Retrieves a shortened version of the HEAD reference value.
  #
  # This removes the leading segments of `refs/heads`, `refs/tags`, or
  # `refs/remotes`.  It also shortens the SHA-1 of a detached `HEAD` to 7
  # characters.
  #
  # * `path` An optional {String} path in the repository to get this information
  #   for, only needed if the repository contains submodules.
  #
  # Returns a {String}.
  getShortHead: (path) -> @tags?['tip'][1]

  # Public: Is the given path a submodule in the repository?
  #
  # * `path` The {String} path to check.
  #
  # Returns a {Boolean}.
  isSubmodule: (path) -> null

  # Public: Returns the number of commits behind the current branch is from the
  # its upstream remote branch.
  #
  # * `reference` The {String} branch reference name.
  # * `path`      The {String} path in the repository to get this information for,
  #   only needed if the repository contains submodules.
  getAheadBehindCount: (reference, path) -> null

  # Public: Get the cached ahead/behind commit counts for the current branch's
  # upstream branch.
  #
  # * `path` An optional {String} path in the repository to get this information
  #   for, only needed if the repository has submodules.
  #
  # Returns an {Object} with the following keys:
  #   * `ahead`  The {Number} of commits ahead.
  #   * `behind` The {Number} of commits behind.
  getCachedUpstreamAheadBehindCount: (path) -> null

  # Public: Returns the Mercurial property value specified by the key.
  #
  # * `path` An optional {String} path in the repository to get this information
  #   for, only needed if the repository has submodules.
  getConfigValue: (key, path) -> null

  # Public: Returns the origin url of the repository.
  #
  # * `path` (optional) {String} path in the repository to get this information
  #   for, only needed if the repository has submodules.
  getOriginUrl: (path) -> null

  # Public: Returns the upstream branch for the current HEAD, or null if there
  # is no upstream branch for the current HEAD.
  #
  # * `path` An optional {String} path in the repo to get this information for,
  #   only needed if the repository contains submodules.
  #
  # Returns a {String} branch name such as `refs/remotes/origin/master`.
  getUpstreamBranch: (path) -> null

  # Public: Gets all the local and remote references.
  #
  # * `path` An optional {String} path in the repository to get this information
  #   for, only needed if the repository has submodules.
  #
  # Returns an {Object} with the following keys:
  #  * `heads`   An {Array} of head reference names.
  #  * `remotes` An {Array} of remote reference names.
  #  * `tags`    An {Array} of tag reference names.
  getReferences: (path) -> null

  # Public: Returns the current {String} SHA for the given reference.
  #
  # * `reference` The {String} reference to get the target of.
  # * `path` An optional {String} path in the repo to get the reference target
  #   for. Only needed if the repository contains submodules.
  getReferenceTarget: (reference, path) -> null

  ###
  Section: Reading Status
  ###

  isPathModified: (path) -> @statuses[path] == 'M'
  isPathNew: (path) -> @statuses[path] == 'A'
  isPathIgnored: (path) -> @statuses[path] == 'I'

  # Public: Get the status of a directory in the repository's working directory.
  #
  # * `path` The {String} path to check.
  #
  # Returns a {Number} representing the status. This value can be passed to
  # {::isStatusModified} or {::isStatusNew} to get more information.
  getDirectoryStatus: (directoryPath) ->
      for path in @statuses
          return 'M' if path.indexOf(directoryPath) is 0

  # Public: Get the status of a single path in the repository.
  #
  # `path` A {String} repository-relative path.
  #
  # Returns a {Number} representing the status. This value can be passed to
  # {::isStatusModified} or {::isStatusNew} to get more information.
  getPathStatus: (path) -> @statuses[path]

  # Public: Get the cached status for the given path.
  #
  # * `path` A {String} path in the repository, relative or absolute.
  #
  # Returns a status {Number} or null if the path is not in the cache.
  getCachedPathStatus: (path) -> @statuses[path]

  # Public: Returns true if the given status indicates modification.
  isStatusModified: (status) -> status == 'M'

  # Public: Returns true if the given status indicates a new path.
  isStatusNew: (status) -> status == 'A'

  # Public: Returns true if the given status is ignored.
  isStatusIgnored: (status) -> status == 'I'

  ###
  Section: Retrieving Diffs
  ###

  # Public: Retrieves the number of lines added and removed to a path.
  #
  # This compares the working directory contents of the path to the `HEAD`
  # version.
  #
  # * `path` The {String} path to check.
  #
  # Returns an {Object} with the following keys:
  #   * `added` The {Number} of added lines.
  #   * `deleted` The {Number} of deleted lines.
  getDiffStats: (path) -> @diffstats[path]

  # Public: Retrieves the line diffs comparing the `HEAD` version of the given
  # path and the given text.
  #
  # * `path` The {String} path relative to the repository.
  # * `text` The {String} to compare against the `HEAD` contents
  #
  # Returns an {Array} of hunk {Object}s with the following keys:
  #   * `oldStart` The line {Number} of the old hunk.
  #   * `newStart` The line {Number} of the new hunk.
  #   * `oldLines` The {Number} of lines in the old hunk.
  #   * `newLines` The {Number} of lines in the new hunk
  getLineDiffs: (path, text) ->
      hash = crypto.createHash('md5').update(text).digest('hex')
      if @linediffs[path]?.hash == hash
          console.log 'hg', 'getLineDiffs', 'cash hit', path, hash if @devMode
          return @linediffs[path].hunks
      else 
          setImmediate () =>
              @repo.cat path, (err, out) =>
                  base = @parsers.raw out
                  diffdata = jsdiff.structuredPatch path, path, base, text, null, null, {context: 0}
                  for hunk in diffdata.hunks
                      delete hunk.lines
                  @linediffs[path] = { hash, hunks: diffdata.hunks }
                  @emitter.emit 'did-change-status', { path, pathStatus: @statuses[path] }
                  console.log 'hg', 'getLineDiffs', 'cache miss', path, hash if @devMode

  ###
  Section: Checking Out
  ###

  # Public: Restore the contents of a path in the working directory and index
  # to the version at `HEAD`.
  #
  # This is essentially the same as running:
  #
  # ```sh
  #   git reset HEAD -- <path>
  #   git checkout HEAD -- <path>
  # ```
  #
  # * `path` The {String} path to checkout.
  #
  # Returns a {Boolean} that's true if the method was successful.
  checkoutHead: (path) -> null

  # Public: Checks out a branch in your repository.
  #
  # * `reference` The {String} reference to checkout.
  # * `create`    A {Boolean} value which, if true creates the new reference if
  #   it doesn't exist.
  #
  # Returns a Boolean that's true if the method was successful.
  checkoutReference: (reference, create) -> null

  ###
  Section: Private
  ###

 # Subscribes to buffer events.
  subscribeToBuffer: (buffer) ->
    getBufferPathStatus = =>
      console.log 'hg', 'getBufferPathStatus' if @devMode
      if path = buffer.getPath()
        @getPathStatus(path)

    bufferSubscriptions = new CompositeDisposable
    bufferSubscriptions.add buffer.onDidSave(getBufferPathStatus)
    bufferSubscriptions.add buffer.onDidReload(getBufferPathStatus)
    bufferSubscriptions.add buffer.onDidChangePath(getBufferPathStatus)
    bufferSubscriptions.add buffer.onDidDestroy =>
      bufferSubscriptions.dispose()
      @subscriptions.remove(bufferSubscriptions)
    @subscriptions.add(bufferSubscriptions)
    return

  # Subscribes to editor view event.
  checkoutHeadForEditor: (editor) -> null

  # Reread the index to update any values that have changed since the
  # last time the index was read.
  refreshIndex: -> 
      return new Promise (resolve, reject) =>
          @repo.tags (err, out) =>
              @tags = @parsers.tags(out)
              resolve()

  # Refreshes the current hg status in an outside process and asynchronously
  # updates the relevant properties.
  refreshStatus: ->
      console.log 'hg', 'refreshStatus' if @devMode
      p_status = new Promise (resolve, reject) =>
          @repo.status (err, out) =>
              newstatuses = {}
              for p, s of @parsers.status(out)
                  newstatuses[nPath.join(@repo.path, p)] = s
              resolve(newstatuses)

      p_diffstats = new Promise (resolve, reject) =>
          @repo.diff "--stat", (err, out) =>
              newdiffstats = {}
              for p, s of @parsers.diffstat out
                  newdiffstats[nPath.join(@repo.path, p)] = s
              resolve(newdiffstats)

      Promise.all([ p_status, p_diffstats ])
      .then (results) =>
          [ newstatuses, newdiffstats ] = results
          statuses_change = !deepEqual(newstatuses, @statuses)
          diffstats_change = !deepEqual(newdiffstats, @diffstats)
          if statuses_change
              @statuses = newstatuses
          if diffstats_change
              @diffstats = newdiffstats
          if statuses_change || diffstats_change
              @emitter.emit 'did-change-statuses'

