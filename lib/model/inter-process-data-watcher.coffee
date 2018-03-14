{CompositeDisposable, Emitter} = require 'atom'
fs = require 'fs-plus'
ReadWriteLock = require 'rwlock';

# Defer requiring
InterProcessData = null

module.exports =
  class InterProcessDataWatcher
    constructor: (@filePath) ->
      @justCommittedData = false
      @emitter = new Emitter
      @disposables = new CompositeDisposable
      @promisedData = new Promise((resolve, reject)=>)
      @fsTimeout = undefined
      @configLock = new ReadWriteLock

      fs.open(@filePath, 'a', "0644", =>
        @promisedData = @load()
        @watcher()
      )


    watcher: ->
      fs.watch(@filePath, ((event, filename) =>
        if @fsTimeout is undefined and (event is 'change' or event is 'rename')
          @fsTimeout = setTimeout((() => @fsTimeout = undefined; @reloadIfNecessary(); @watcher()), 2000)
        )
      )


    reloadIfNecessary: ->
      # if we just committed... flip and return
      if @justCommittedData is true
        @justCommittedData = false
        return

      # ... here justCommittedData is false
      @data?.destroy()
      @data = undefined
      @promisedData = @load()


    # Should return InterProcessData object
    getData: ->
      return new Promise((resolve, reject) =>
        if @data is undefined
          @promisedData.then (resolvedData) =>
            @data = resolvedData
            @disposables.add @data.onDidChange => @commit()
            resolve(@data)
        else
          resolve(@data)
      )


    destroy: ->
      @disposables.dispose()
      @emitter.dispose()
      @data?.destroy()


    load: ->
      # return a native promise
      return new Promise((resolve, reject) =>
        @configLock.readLock((release) =>
          fs.readFile(@filePath, 'utf8', (err, data) =>
            release()
            InterProcessData ?= require './inter-process-data'
            throw err if err?

            # default value
            interProcessData = new InterProcessData([])

            # Try to read... if we fail, just use the default value
            if data.length > 0
              try
                interProcessData = InterProcessData.deserialize(JSON.parse(data))
              catch e
                console.debug 'Could not parse serialized remote-edit data! Creating an empty InterProcessData object!'
                console.debug e

            @emitter.emit 'did-change'

            # we have already handled error above
            return resolve(interProcessData);
          )
        )
      )


    commit: ->
      @justCommittedData = true

      @configLock.writeLock((release) =>
        fs.writeFile(@filePath, JSON.stringify(@data.serialize()), (err) -> throw err if err?)
        @emitter.emit 'did-change'
        release()
      )

    onDidChange: (callback) ->
      @emitter.on 'did-change', callback
