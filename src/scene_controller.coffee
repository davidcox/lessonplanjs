#<< mcb80x/lesson_plan

# A simple controller that implements a run loop to poke its
# head up periodically to check whether something needs to be
# done

class mcb80x.SceneController

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

        @shouldRun = false
        @running = false
        @runningDfrd = undefined

        @currentElement = undefined

        @runLoopActive = true

        @sceneIndex = 0
        @selectedSceneIndex = 0

        # Knockout.js bindings for intra-app comms
        @currentSegment = ko.observable(undefined)
        @currentTime = ko.observable(undefined)
        @currentScene = ko.observable(undefined)
        @currentSceneIndex = ko.observable(undefined)

        # The current scene
        @scene = @loadScene(@sceneIndex)

        @interval = 100

        # Hard-coded for now... should probably
        # show some kind of outro
        @exitTarget = 'http://mcb80x.org/map'



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
            @stopDfrd = $.when(=> @scene.stop())
                         .then(=> @scene.reset())
                         .then(=>
                            @stopping = false
                            @stopped = true
                            @running = false)

        if @stopping
            console.log('[ stopping ]')
            @punt()
            return

        # test for pausing
        if @shouldPause
            console.log('[ shouldPause ]')
            @shouldPause = false
            @pausing = true
            @pauseDfrd = @currentElement.pause()

        if @pausing
            console.log('[ pausing ]')
            $.when(@pauseDfrd)
             .then(=>
                @paused = true
                @pausing = false
            )

            @punt()
            return

        # test for seeking
        if @shouldSeek
            console.log('[ shouldSeek ]')
            @shouldSeek = false

            @seeking = true
            @seekDfrd = $.when(=>
                            l '> stopping...'
                            if @targetSegment != @currentElement
                                return @scene.stop()
                            else
                                return @currentElement.pause()
                        ).then(=>
                            l '> resetting'
                            if @targetSegment != @currentElement
                                return @scene.reset()
                        ).then(=>
                            l '> seeking...'
                            @currentElement = @targetSegment
                            @currentSegment(@currentElement)
                            console.log(@currentElement)
                            @currentElement.seek(@targetTime)
                        ).then(=>
                            @seeking = false
                            @shouldRun = true
                        )

        if @seeking
            console.log('[ seeking ]')
            @punt()
            return

        if @shouldRun
            console.log('[ shouldRun ]')
            @shouldRun = false
            @running = true
            @runningDfrd = @currentElement.run()

            @punt()
            return

        if @shouldAdvanceScene

            @sceneIndex += 1
            if @sceneIndex > @sceneList.length
                @stopped = true
                window.location = @exitTarget
                return

            @advancingSceneDfrd = @loadScene(@sceneIndex)
            @shouldAdvanceScene = false
            @advancingScence = true

        if @shouldSelectScene
            @advancingSceneDfrd = @loadScene(@selectedSceneIndex)
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

                @currentSegment(@currentElement)
                @currentTime(0.0)
                @runningDfrd = @currentElement.run()
                @running = true

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
        @shouldRun = true

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


    loadScene: (index) ->

        name = @sceneList[index].name

        @unloadScene()

        l = window.location;
        base_url = l.protocol + "//" + l.host + "/" + l.pathname.split('/')[1];
        url = base_url + '/scenes/' + name + '.js'
        return $.when($.ajax(url))
                .then( (data, textStatus, jqXHR) =>
                    $('body').append('<script id="sceneCode">' + data + '</script>')
                    @scene = window.scenes[name]
                ).then(=>
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


