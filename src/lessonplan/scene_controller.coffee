#<< lessonplan/lessonplan
#<< lessonplan/util
#<< lessonplan/logging

root = window ? exports

# A simple controller that implements a run loop to poke its
# head up periodically to check whether something needs to be
# done.  This object ultimately governs movement through the
# lessons finite state machine.

class lessonplan.SceneController

    constructor: (@sceneList) ->

        # state variables
        @shouldSeek = false
        @seeking = false
        @targetSegment = undefined
        @targetTime = undefined

        @shouldStop = false
        @stopping = false
        @stopped = true
        @stopDfrd = undefined

        @shouldPause = false
        @pausing = false
        @paused = true
        @pauseDfrd = undefined

        @shouldResume = false

        @shouldBuffer = false
        @buffering = false

        @shouldRun = false
        @running = false
        @runningDfrd = undefined

        @stallCount = 0
        @stallCountThreshold = 30

        @currentElement = undefined

        @runLoopActive = true

        @sceneIndex = 0
        @selectedSceneIndex = 0

        # Knockout.js bindings for intra-app comms
        @currentLessonElement = ko.observable(undefined)
        @currentTime = ko.observable(undefined)
        @currentScene = ko.observable(undefined)
        @currentSceneIndex = ko.observable(undefined)

        @playingObservable = ko.observable(false)
        @pausedObservable = ko.observable(false)

        # check to see if we should be loading a segement
        # other than the first one
        if root.segment_id?
            for s, i in @sceneList
                if s.name is root.segment_id
                    @sceneIndex = i
                    break

        # The current scene
        @loadScene(@sceneIndex)

        @interval = 10

        # Hard-coded for now... should probably
        # show some kind of outro
        @exitTarget = '/course'



    punt: (t) ->
        t = @interval if not t
        rl = => @runLoop()
        setTimeout(rl, t)

    stopRunLoop: ->
        @runLoopActive = false

    startRunLoop: ->
        @runLoopActive = true
        @shouldRun = true
        @punt(0)

    runLoop: ->

        l = (m) -> console.log(m)

        if not @runLoopActive
            console.log('run loop inactive: ' + @runLoopActive)
            return # bail

        # test for stopping
        if @shouldStop
            console.log('[ shouldStop ]')
            @shouldStop = false
            @stopping = true
            # tell the system to stop, get a promise back
            @stopDfrd = $.when(@scene.stop()).then(=>
                            $.when(@scene.reset()).then(=>
                                @stopping = false
                                @stopped = true
                                @running = false
                            )
                        )

        if @stopping
            console.log('[ stopping ]')
            @punt()
            return


        # test for seeking
        if @shouldSeek
            console.log('[ shouldSeek ]')

            # todo, more informative logging
            logging.logInteraction('timeline', 'seek', @targetSegment.elementId)

            @shouldSeek = false
            @shouldBuffer = false
            @buffering = false

            @seeking = true

            l '> stopping...'

            stopDfrd = undefined
            if @targetSegment != @currentElement
                stopDfrd = @scene.stop()
            else
                stopDfrd = @currentElement.pause()

            @seekDfrd = $.Deferred()

            $.when(stopDfrd).then(=>
                return util.indicateLoading(true)

            ).then(=>
                l '> resetting'
                if @targetSegment == @currentElement
                    return true

                sceneResetReturn = @scene.reset()
                console.log 'srr'
                console.log sceneResetReturn
                console.log sceneResetReturn.state()
                return sceneResetReturn

            ).then(=>
                l '> seeking...'
                @currentElement = @targetSegment

                # TODO: is this needed?
                # @currentSegment(@currentElement)

                return @currentElement.seek(@targetTime)

            ).then(=>
                return util.indicateLoading(false)

            ).then(=>

                @seekDfrd.resolve()
                @seeking = false

                if not @shouldPause
                    @shouldRun = true
            )


        if @seeking
            console.log('[ seeking ]')
            @punt()
            return

        # test for pausing
        if @shouldPause
            console.log('[ shouldPause ]')
            logging.logInteraction('timeline', 'pause', true)

            @shouldPause = false
            @pausing = true
            @pauseDfrd = @currentElement.pause()

        if @pausing
            console.log('[ pausing ]')
            $.when(@pauseDfrd)
             .then(=>
                @paused = true
                @pausedObservable(true)
                @playingObservable(false)
                @pausing = false
            )

            @punt()
            return


        if @shouldBuffer
            console.log('[ shouldBuffer ]')
            @shouldBuffer = false

            @buffering = true
            $.when(=>
                console.log 'pausing to buffer'
                @currentElement.pause()
            ).then(=>
                util.indicateLoading(true)
            )


        if @buffering
            console.log('[ buffering ]')

            if @currentElement.ready()
                console.log 'buffered enough...'
                @buffering = false
                @shouldBuffer = false
                util.indicateLoading(false)
                @shouldRun = true

            @punt()
            return


        if @shouldResume
            console.log '[ shouldResume ]'
            logging.logInteraction('timeline', 'resume', true)

            @shouldResume = false

            if not @currentElement.resume?
                @shouldRun = true
            else
                @running = true

                @playingObservable(true)
                @pausedObservable(false)
                @runningDfrd = @currentElement.resume()

                @stallCount = 0
                @punt()
                return

        if @shouldRun
            console.log('[ shouldRun ]')
            logging.logInteraction('timeline', 'play', true)

            @shouldRun = false
            @running = true
            @playingObservable(true)
            @pausedObservable(false)
            @runningDfrd = @currentElement.run()
            @stallCount = 0

            @punt()
            return

        if @shouldAdvanceScene

            @sceneIndex += 1
            if @sceneIndex >= @sceneList.length
                @stopped = true
                #window.location = @exitTarget
                # window.history.back()
                return

            @advancingSceneDfrd = @loadScene(@sceneIndex, true)
            @shouldAdvanceScene = false
            @advancingScence = true

        if @shouldSelectScene

            @advancingSceneDfrd = @loadScene(@selectedSceneIndex, true)
            @shouldSelectScene = false
            @advancingScence = true

        if @advancingScene
            if $.when(@advancingSceneDfrd).state() == 'resolved'
                @advancingScene = false
                @shouldRun = true
                @punt()
                return

        # check for completion
        if @running
            # console.log('[ running ]')
            if $.when(@runningDfrd).state() == 'resolved'

                @running = false
                if @currentElement.willYieldOnNext()
                    @currentElement.finish()
                @currentElement = @currentElement.next()

                if @currentElement is undefined
                    @running = false
                    @shouldAdvanceScene = true
                    @punt()
                    return

                # update the KO bindings
                @currentTime(0.0)
                @currentLessonElement(@currentElement)
                @runningDfrd = @currentElement.run()
                @running = true
                @playingObservable(true)
                @pausedObservable(false)


            if not @currentElement.ready
                @stallCount += 1

            if @stallCount > @stallCountThreshold
                console.log('stalled')
                @running = false
                @shouldBuffer = true

            @punt()
            return

        @punt()


    advance: ->
        return @currentElement.run()

    seek: (seg, t) ->
        @shouldSeek = true
        @targetSegment = seg
        @targetTime = t


    pause: ->
        @shouldPause = true

    resume: ->
        @shouldResume = true

    run: ->
        @shouldRun = true

    stop: ->
        @shouldRun = false
        @shouldStop = true


    unloadScene: ->
        if @scene?
            $.when(=> @scene.stop())
             .then(=> @scene.cleanup())

        $('#sceneCode').remove()


    selectScene: (index) ->
        @selectedSceneIndex = index
        @shouldStop = true
        @shouldSelectScene = true


    loadScene: (index, newpage=false) ->

        name = @sceneList[index].name
        scene_path = window.module_id + '/' + window.lesson_id

        if newpage
            window.location.href = '/course/' + scene_path + '/' + name
            return

        @unloadScene()

        url = window.static_base_url + '/lesson_plans/' + scene_path + '/' + name + '.js'

        console.log 'Loading code: ' + url

        dfrd = $.Deferred()
        util.loadScript(url, ->
            console.log('... code ran successfully')
            dfrd.resolve()
        )

        return $.when(dfrd)
                .then( =>
                    @scene = window.scenes[name]

                    if not @scene?
                        console.log('Could not find scene named: ' + name)
                    # update the bindings
                    @currentElement = @scene
                    @sceneIndex = index
                    @scene.currentTime = @currentTime
                    @scene.currentSegment = @currentSegment

                    # notify bindings
                    @currentScene(@scene)
                    @currentSceneIndex(index)

                    # start things in motion
                    @startRunLoop()
                )

