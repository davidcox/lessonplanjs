#<< mcb80x/util

root = window ? exports

root.registry = []
root.scenes = {}
root.stages = []


# Some basic infrastructure for uniquely ID'ing elements
elementCounter = -1
uniqueElementId = ->
    elementCounter += 1
    'element_assigned_id_' + elementCounter

cbCounter = -1
uniqueCbId = ->
    cbCounter += 1
    return cbCounter

soundReady = false
audioRoot = '/audio/'
svgRoot = '/svg/'
videoRoot = '/video/'
videoPlayerDivSelector = '#video'
interactiveDivSelector = '#interactive'



# A simple controller that implements a run loop to poke its
# head up periodically to check whether something needs to be
# done

class mcb80x.SceneController

    constructor: (@scene) ->

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

        @currentElement = @scene

        @runLoopActive = true

        # knockout.js bindings, inherited from the scene
        # object
        @currentSegment = @scene.currentSegment
        @currentTime = @scene.currentTime

        @interval = 100


    end: ->
        @runLoopActive = false

    begin: ->
        setTimeout(@runLoop, 0)


    punt: (t) ->
        t = @interval if not t
        rl = => @runLoop
        setTimeout(rl, t)

    runLoop: ->

        if not @runLoopActive
            return # bail

        # test for stopping
        if @shouldStop
            @shouldStop = false
            @stopping = true
            # tell the system to stop, get a promise back
            @stopDfrd = $.when(=> @scene.stop())
                         .then(=> @scene.reset())

        if @stopping
            if $.when(@stopDfrd).isResolved()
                @stopping = false
                @stopped = true
                @running = false
            else
                @punt()

        # test for pausing
        if @shouldPause
            @shouldPause = false
            @pausing = true
            @pauseDfrd = @currentElement.pause()

        if @pausing
            if $.when(@pauseDfrd).isResolved()
                @paused = true
                @pausing = false
            else
                @punt()

        # test for seeking
        if @shouldSeek
            @shouldSeek = false

            @seekDfrd = $.when(=> @scene.stop())
                         .then(=>
                            @currentElement = @targetSegment
                            @currentElement.seek(@targetTime)
                        ).then(=>
                            @shouldRun = true
                        )

            @seeking = true

        if @seeking
            if $.when(@seekDfrd).isResolved()
                @seeking = false
            else
                @punt()

        if @shouldRun
            @shouldRun = false
            @running = true
            @runningDfrd = @advance()

        # check for completion
        if @running
            if $.when(@runningDfrd).isResolved()

                @running = false
                @runningDfrd = @advance()
                @running = true
                @punt(0)
            else
                @punt()

        @punt()


    advance: ->
        return @currentElement.run()

    seek: (seg, t) ->
        @shouldSeek = true
        @targetSegment = seg
        @targetTime = t


    pause: ->
        @shouldPause = true

    run: ->
        @shouldRun = true

    stop: ->
        @shouldRun = false
        @shouldStop = true



class mcb80x.SceneControllerOld

    constructor: (@scene) ->

        @paused = ko.observable(false)

        # a flag to inform the callback chain to
        # abort and stop
        @stopping = false

        # a flag to indicate that the scene has
        # successfully parked
        @stopped = false

        @currentElement = @scene

        # knockout.js bindings, inherited from the scene
        # object
        @currentSegment = @scene.currentSegment
        @currentTime = @scene.currentTime

        # a callId object to keep track of
        # different run invokations
        @currentCallId = undefined

        # a flag to prevent multiple runAtSegment
        # calls from piling up.
        @runAtSegmentInvoked = false

    run: (t) ->
        console.log('Scene controller: running...')

        # unset the stop flags
        @stopping = false
        @stopped = false

        # get a unique ID for this stream of
        # run execution
        @currentCallId = uniqueCbId()

        # set the scene in motion
        @advance(@currentCallId, t)


    runAtSegment: (seg, t) ->
        console.log('Running from segment: ')
        console.log('t = ' + t)

        if @runAtSegmentInvoked
            # already working on one these
            console.log('WARNING: multiple invocations of runAtSegment')
            # TODO: stop the existing invocation
            # return

        @runAtSegmentInvoked = true

        if seg == @currentElement
            $.when(@currentElement.pause())
             .then(=>
                @runAtSegmentInvoked = false
                @run(t)
            )

        else
            # dim the stage lights right away to
            # let the user know the click registered
            $.when(util.indicateLoading(true).promise()).then(=>
                console.log('waiting for stop')
                return @stop().promise()
            ).then(=>
                console.log('reseting...')
                return @reset().promise()
            ).then(=>
                return util.indicateLoading(false).promise()
            ).then(=>
                console.log('running scene')
                @currentElement = seg
                @runAtSegmentInvoked = false
                @run(t)
            )


    advance: (cbId, t) ->

        console.log('advance: callId = ' + cbId)

        if not @currentElement?
            # no element to run
            return

        if cbId != @currentCallId
            # another call chain has been initated, bail on this one
            console.log('bailing')
            return

        if @stopping
            # a stop request issued
            @stopping = false
            @stopped = true
            return


        console.log('Scene controller: running ' + @currentElement.elementId)
        console.log(@currentElement)
        @currentTime(undefined)
        @currentSegment(@currentElement)

        dfrd = undefined

        if t?
            @runAtSegmentInvoked = false  # TODO: ?
            dfrd = $.when(@currentElement.seek(t))
                    .then(=> @currentElement.run())
        else
            # Run it. dfrd is a jQuery deferred object
            dfrd = @currentElement.run()

        console.log('waiting for element to finish running')
        checkForCompletion = =>

            if @stopping
                @stopped = true
                @stopping = false
                # fall out
                console.log('stopping is true')
                return

            if $.when(dfrd).state() == 'pending' or @paused()
                # schedule another pass
                setTimeout(checkForCompletion, 100)
                return

            else

                if cbId != @currentCallId
                    # another call chain has been initated, bail on this one
                    console.log('bailing 2')
                    return

                console.log('Scene controller: finishing ' + @currentElement.elementId)

                if @currentElement.willYieldOnNext() or @stopping
                    @currentElement.finish()

                if @stopping
                    @stopping = false
                    @stopped = true
                    return

                @currentElement = @currentElement.next()
                console.log('Scene controller: next element is ' + @currentElement)
                @advance(cbId)

        checkForCompletion()

    pause: ->
        # set up a deferred pause
        # @deferredPause = $.Deferred()

        @paused(true)

        # freeze execution of the current element
        @currentElement.pause()


    resume: ->

        @paused(false)

        # resume the current element
        @currentElement.resume()

        # release the pause deferred
        # @deferredPause.resolve()

    stop: ->

        # set the stopping flag
        @stopping = true
        @paused(false)

        # reject the pause deferred, this will cause any
        # execution waiting on the pause deferred to
        # fall through and go away
        # console.log('rejecting deferredPause')
        # @deferredPause.reject()
        # console.log('rejected')

        deferredStopped = $.Deferred()

        # instruct all elements in the scene to stop
        deferredSceneStop = $.Deferred()

        stopit = =>
            @scene.stop()
            deferredSceneStop.resolve()

        setTimeout(stopit, 0)

        checkStopped = =>
            if @stopped
                @stopping = false
                deferredStopped.resolve()
                return
            setTimeout(checkStopped, 100)

        setTimeout(checkStopped, 100)

        return $.when(deferredStopped, deferredSceneStop)

    reset: ->
        @currentElement = @scene

        dfrd = $.Deferred()
        resetEverything = =>
            @currentElement.reset()
            dfrd.resolve()

        setTimeout(resetEverything, 0)

        return dfrd



# Lesson Elements
# These are the objects that the DSL will actually build
# They are organized hierarchically with a "Scene" at the
# top level, with story "beats" below
# This code is a bit of a mess at the moment, but it is
# basically functional

# Base LessonElement
class mcb80x.LessonElement

    constructor: (@elementId) ->

        if not @elementId?
            @elementId = uniqueElementId()

        registry[@elementId] = this

        @children = []
        @childIndexLookup = {}
        @childLookup = {}

        @parent = undefined
        @parentScene = undefined

        @currentChild = 0

    addChild: (child) ->
        console.log('adding ' + child.elementId + ' to ' + @elementId)
        child.parent = this
        child.parentScene = @parentScene
        @children.push(child)

        if @childIndexLookup[child.elementId]?
            alert('Dupicate script element name.  Unpredictable behavior will ensue')
        @childIndexLookup[child.elementId] = @children.length - 1
        @childLookup[child.elementId] = child

    # Init is called after the DOM is fully available
    init: ->
        if @children?
            child.init() for child in @children


    # methods for picking up after a child node
    # has yielded
    nextAfterChild: (child) ->

        childId = child.elementId

        # if by some weirdness there are no children, return
        # undefined
        if not @children? or @children.length is 0
            console.log('weirdness')
            return undefined

        # Look up the index of child
        childIndex = @childIndexLookup[childId]
        return @nextAfterIndex(childIndex)

    nextAfterIndex: (childIndex) ->

        nextIndex = childIndex + 1
        console.log(nextIndex)
        console.log(@children[nextIndex])
        if @children[nextIndex]?
            return @children[nextIndex]
        else if @parent?
            return @parent.nextAfterChild(this)
        else
            console.log('nextAfterIndex: no parent to yield to...')
            console.log(this)
            return undefined

    seek: (t) ->
        # do nothing
        dfrd = $.Deferred().resolve()
        return dfrd

    willYieldOnNext: ->
        if not (@children? and @children.length and @currentChild < @children.length)
            return true
        else
            return false

    next: ->
        console.log('currentChild = ' + @currentChild)

        if @children? and @children.length
            if @currentChild < @children.length
                @currentChild += 1
                return @children[@currentChild-1]

        if @parent?
            return @parent.nextAfterChild(this)
        else
            console.log('no parent, yielding undefined')
            return undefined


    # Run through this element and all of its children
    run: ->
        return true


    reset: (t) ->
        @currentChild = 0

        for child in @children
            child.reset()


    stop: ->
        for child in @children
            child.stop()

    pause: ->
        console.log('base pause')

    resume: ->
        console.log('base resume')

    finish: ->
        console.log('base finish')


LessonElement = mcb80x.LessonElement


# Top-level "Scene"
class mcb80x.Scene extends LessonElement
    constructor: (@title, elId) ->
        if not elId?
            elId = @title

        super(elId)

        # register this scene in the global registry
        scenes[elId] = this
        @parentScene = this

        @currentSegment = ko.observable(undefined)
        @currentTime = ko.observable(undefined)

    run: ->
        @init()
        util.indicateLoading(false)
        console.log('scene[' + @elementId + ']')
        return super()


class mcb80x.Interactive extends LessonElement

    constructor: (elId) ->
        @duration = ko.observable(1.0)
        @soundtrackFile = undefined
        @soundtrackLoaded = false
        @hasSoundtrack = false
        super(elId)

    stage: (s) ->
        if s?
            @stageObj = s
        else
            return @stageObj

    soundtrack: (s) ->
        if s?
            @soundtrackFile = s
            @hasSoundtrack = true
        else
            return @soundtrackFile

        # if not soundReady
        #     initSound(=> @loadSoundtrack(s))
        # else
        @loadSoundtrack(s)

    loadSoundtrack: (s) ->
        @soundtrackAudio = new buzz.sound(audioRoot + s,
            preload:true
            loop: true
        )

    finish: ->
        @soundtrackAudio.stop() if @soundtrackAudio?

        # hide the stage
        @stageObj.hide() if @stageObj? and @stageObj.hide?


    playSoundtrack: ->
        @soundtrackAudio.load()
        @soundtrackAudio.play().setVolume(10)

    run: () ->
        console.log('running interactive')

        @playSoundtrack() if @hasSoundtrack

        console.log('stage: ' + @stageObj)
        if @stageObj?
            return @stageObj.show()

        return super()

    reset: ->
        # @stage().reset() if (@stage() and @stage().reset?)
        super()

    stop: ->
        @soundtrackAudio.stop() if @soundtrackAudio?
        @stage().stop() if (@stage() and @stage().stop?)
        super()


# A somewhat hacked up video object
class mcb80x.Video extends LessonElement
    constructor: (elId) ->
        @preferredFormat = 'mp4'
        # @preferredFormat = 'youtube'
        @duration = ko.observable(1.0)
        @mediaUrls = {}

        @playerReady = $.Deferred()
        super(elId)


    media: (fileType, url) ->
        if url?
            @mediaUrls[fileType] = url
        else
            return @mediaUrls[fileType]

    mediaTypes: ->
        return [k for k of @mediaUrls]

    subtitles: (f) ->
        # fill me in


    # init is called after the DOM is ready
    init: ->

        # f = @media(@preferredFormat)

        # # Load the media on the player object
        # if @preferredFormat == 'vimeo'
        #     f = 'http://player.vimeo.com/video/' + f

        # console.log('video parent: ' + @parent)
        # if not globalPop?
        #     if @preferredFormat is 'vimeo'
        #         globalPop = Popcorn.vimeo(videoPlayerDivSelector, f)
        #     else
        #         globalPop = Popcorn.smart(videoPlayerDivSelector, f)

        # @pop = globalPop

        # hide the video player by default
        $(videoPlayerDivSelector).attr('style', 'opacity: 0.0;')

        @playerSelector = undefined

        @load()

        super()

    reset: (t) ->
        console.log('Resetting video')
        t = 0.0 if not t?
        @seek(t)
        # @finish()
        @hide()

        super()

    seek: (t) ->
        console.log('seeking video to ' + t)
        @pop.pause()
        @pop.currentTime(t)

        dfrd = $.Deferred()

        checkIfSeeking = =>
            if not @pop.seeking()
                dfrd.resolve()
            else
                setTimeout(checkIfSeeking, 100)

        checkIfSeeking()
        return dfrd

    show: ->

        @playerNode.setAttribute('style', 'display: inline; opacity: 1.0;')

        d3.select('#interactive').transition().style('opacity', 0.0).duration(1000)
        d3.select(videoPlayerDivSelector).style('display', 'inline')
        d3.select(videoPlayerDivSelector).transition().style('opacity', 1.0).duration(1000)

    hide: ->
        d3.select(videoPlayerDivSelector).transition().style('opacity', 0.0).duration(1000)
        #d3.select(videoPlayerDivSelector).style('display', 'none')
        @playerNode.setAttribute('style', 'opacity: 0.0;') if @playerNode?

    # playWhenReady: ->
    #     if @pop.readyState() >= 4
    #         @pop.play(0)

    #     else
    #         playit = =>
    #             console.log('buffering... ' + @pop.readyState())
    #             @playWhenReady()
    #         setTimeout(playit, 1000)

    load: ->

        f = @media(@preferredFormat)

        # Load the media on the player object
        if @preferredFormat == 'vimeo' or @preferredFormat == 'youtube'

            if @preferredFormat == 'vimeo'
                url = 'http://player.vimeo.com/video/' + f
                console.log('f: ' + f)
                # @pop.url = f
                @pop = Popcorn.vimeo(videoPlayerDivSelector, url)
            else
                url = 'http://www.youtube.com/embed/' + f + '?controls=0&enablejsapi=1&modestbranding=1&showinfo=0&rel=0'
                @pop = Popcorn.youtube(videoPlayerDivSelector, url)

            #  Need to do some machinations to get our hands on the correct iframe node
            console.log(videoPlayerDivSelector + ' iframe')

            preparePlayer = =>
                console.log('preparing player')
                iframes = $(videoPlayerDivSelector + ' iframe')

                console.log(iframes)
                window.iframes = iframes
                iframes.each( (i, v) =>
                    console.log('iframe')
                    console.log(v)
                    src = v.getAttribute('src')
                    r = new RegExp(f, 'g')
                    window.r = r
                    window.src = src
                    console.log('src: ' + src + ', f: ' + f)
                    m = src.match(r)
                    if m? and m.length > 0
                        console.log('found correct iframe')
                        console.log(v)
                        @playerNode = v
                )

                if not @playerNode?
                    setTimeout(preparePlayer, 100)
                    return

                # @playerNode.setAttribute('style', 'display:none;')

                if @preferredFormat is 'youtube'
                    @youtubePreload()
                else
                    @playerReady.resolve()

            # this must run as a separate evt since the
            # injected player won't be available until after this
            # function ends
            setTimeout(preparePlayer, 0)

        else
            @pop = Popcorn.smart(videoPlayerDivSelector, f)

            @playerNode = @pop.video
            if @playerNode.hasAttribute('controls')
                @playerNode.removeAttribute('controls')

            @playerNode.setAttribute('style', 'opacity: 0;')
            # @playerNode.setAttribute('style', 'display:none;')

            @playerReady.resolve()

        console.log('loading ' + f)

        @pop.on('durationchange', =>
            console.log('duration changed!:' + @pop.duration())
            dur = @pop.duration()
            @duration(dur)
        )

        @pop.load()


    youtubePreload: ->

        console.log('preloading youtube')

        @playerNode.setAttribute('style', 'opacity: 0; display: inline')
        @pop.mute()
        @pop.play()

        checkReady = =>
            if @pop.readyState() is 4
                @pop.pause(0)
                @pop.unmute()
                # @playerNode.setAttribute('style', 'opacity:1.0;')
                @playerNode.setAttribute('style', 'opacity:0.0;')
                console.log('youtube video loaded')
                @playerReady.resolve()
            else
                console.log(@pop.readyState())
                setTimeout(checkReady, 500)

        checkReady()


    finish: ->
        # unregister callbacks
        console.log('unregistering callbacks on video')
        @pop.off('ended', @yieldCb) if @yieldCb
        @pop.off('updatetime', @updateTimeCb) if @updateTimeCb

        # hide the video
        @hide()

    run: ->

        console.log('video run called')
        dfrd = $.Deferred()

        $.when(@playerReady).done( =>

            console.log('playing video')

            @show()

            @updateTimeCb = =>
                t = @pop.currentTime()
                @parentScene.currentTime(t)
            @pop.on('timeupdate', @updateTimeCb)


            # yield when the view has ended
            @yieldCb = ->
                console.log('video finished')
                console.log('parent: ' + @parent)
                dfrd.resolve()
            @pop.on('ended', @yieldCb)

            # @pop.currentTime(0)
            @pop.play()
        )

        return dfrd

    pause: ->
        @pop.pause() if @pop

    resume: ->
        @pop.play() if @pop

    stop: ->
        @pop.pause() if @pop
        @hide()
        super()


# a helper
runChained = (actions) ->
    # a deferred to return for the whole sequence
    sdfrd = $.Deferred()

    # copy the actions list so that we can alter it
    actionsCopy = actions.slice(0)

    # a function to all recursively
    chainIt = (a) ->
        # resolve the "sequence" deferred when the
        # list is empty
        if a.length == 0
            sdfrd.resolve()
            return

        dfrd = a.shift().run()
        $.when(dfrd).then(-> chainIt(a))

    chainIt(actionsCopy)

    # return the "sequence" deferred
    return sdfrd



# A "line" is a bit of audio + text that can be played
# over-top some demo.  If audio is disabled, it will
# display a modal dialog box (audio not yet enabled)

class mcb80x.Line extends LessonElement

    constructor: (@audioFile, @text) ->
        super()

    init: ->
        @loadAudio(@audioFile)
        super()

    loadAudio: (af) ->
        console.log('loading: ' + af)
        @audio = new buzz.sound(audioRoot + af,
            preload: true
        )
        @audio.load()

    reset: ->
        @stop()
        super()

    stage: ->
        return @parent.stage()

    pause: ->
        @audio.pause() if @audio

    resume: ->
        @audio.play() if @audio

    stop: ->
        @audio.stop() if @audio
        @audio.unbind('ended')
        super()

    next: ->
        # don't navigate children normally (as in super()); they will run
        # concurrent with the line
        if @parent?
            return @parent.nextAfterChild(this)
        else
            return undefined

    run: ->
        console.log('Running line...')

        childDeferred = true

        # If there are child actions, we'll run these in
        # tandem with the line/voiceover
        if @children? and @children.length

            childDeferred = runChained(@children)
            # # copy the array of children
            # childrenCopy = @children.slice(0)

            # # take off the first child and start it running
            # childDeferred = childrenCopy.shift().run()

            # # chain together run methods of subsequent children
            # # using deferred's and $.when
            # for child in childrenCopy
            #     childDeferred = $.when(childDeferred).done(->
            #         child.run()
            #     )

        audioDeferred = $.Deferred()

        @audio.bind('ended', =>
            audioDeferred.resolve()
        )

        console.log('playing audio')
        console.log(@audio)
        @audio.load()
        @audio.play()

        # return a deferred object that is contingent on
        # both the audio and the children
        return $.when(audioDeferred, childDeferred)

        # for now, just enable audio; we'll need to figure
        # out how to accomodate text
        # else

        #     @div.text(@text)
        #     @div.dialog(
        #         dialogClass: 'noTitleStuff'
        #         resizable: true
        #         title: null
        #         height: 300
        #         modal: true
        #         buttons:
        #             'continue': ->
        #                 $(this).dialog('close')
        #                 cb()
        #     )


class mcb80x.ShowAction extends LessonElement

    constructor: (@selectors)  ->
        super()

    run: ->
        stage = @parent.stage()
        stage.showElement('#' + s) for s in @selectors

    # reset: ->
    #     stage = @parent.stage()
    #     stage.hideElement('#' + s) for s in @selectors

class mcb80x.HideAction extends LessonElement

    constructor: (@selectors)  ->
        super()

    run: ->
        stage = @parent.stage()
        stage.hideElement('#' + s) for s in @selectors

    # reset: ->
    #     stage = @parent.stage()
    #     stage.showElement('#' + s) for s in @selectors



class mcb80x.SetAction extends LessonElement

    constructor: (@property, @value)  ->
        super()

    run: ->
        stage = @parent.stage()
        stage[@property](@value)


# Actions to "instruct" a demo to do something
class mcb80x.PlayAction extends LessonElement
    constructor: (@stageId) ->
        super()

    run: ->
        console.log('running play action')
        @parent.stage().play()


class mcb80x.StopAndResetAction extends LessonElement

    constructor: (@stageId) ->
        super()

    run: ->
        @parent.stage().stop()


class mcb80x.WaitAction extends LessonElement
    constructor: (@delay) ->
        super()

    run: ->
        console.log('waiting ' + @delay + ' ms...')
        @dfrd = $.Deferred()
        cb = =>
            @dfrd.resolve()

        setTimeout(cb, @delay)
        return @dfrd



class mcb80x.WaitForChoice extends LessonElement
    constructor: (@observableName) ->
        super()

    run: ->

        obs = @parent.stage()[@observableName]

        # console.log('clearing ' + @observableName)
        # obs(undefined)

        console.log('installing waitForChoice subscription on ' + @observableName)
        @dfrd = $.Deferred()

        @subs = obs.subscribe( =>
            console.log('waitForChoice yielding')
            @subs.dispose()
            @dfrd.resolve()
        )

        return @dfrd

    # stop: ->
    #     @subs.dispose() if @subs?
    #     @dfrd.resolve() if @dfrd?



# A finite state machine
# The idea here is to have a simple state machine so
# that simple interactive goals can be easily defined
class mcb80x.FSM extends LessonElement

    constructor: (@states) ->

        super()

        # start out in the 'initial' state
        @currentState = 'initial'
        @delay = 500
        @startTime = undefined

        @statesDfrd = $.Deferred()
        @stopping = false

        # convert DSL imperative action definitions
        # to objects
        for k, v of @states
            actionObj = new LessonElement()
            pushCurrent(actionObj)
            if v.action?
                v.action()
            popCurrent()


            @states[k].action = actionObj

            # add the action object to the 'children'
            # member to ensure it is init'd correctly
            @addChild(actionObj)

            # this is a bit arcane: basically,
            # we're forcing the action to call its callback
            # rather than riding back up the hierarchy
            # actionObj.parent = undefined

    init: ->
        @stage = @parent.stage()
        console.log('got stage = ' + @stage)
        super()

    getElapsedTime: ->
        now = new Date().getTime()
        return now - @startTime

    transitionState: (state) ->

        if @stopping
            @stopping = false
            @statesDfrd = undefined
            return

        stateObj = @states[state]

        # pin some values to the object to make the DSL work
        # as if by magic (sort of)
        stateObj.elapsedTime = @getElapsedTime()
        stateObj.stage = @stage

        transitionTo = stateObj.transition()

        if transitionTo?
            if transitionTo is 'continue'
                console.log('yielding...')
                @statesDfrd.resolve()
            else
                @runState(transitionTo)
        else
            t = => @transitionState(state)
            setTimeout(t, @delay)

    runState: (state, cb) ->
        console.log('ACTION: state: ' + state)
        @startTime = new Date().getTime()

        dfrd = $.Deferred().resolve()

        if @states[state].action? and @states[state].action.children.length
            dfrd = runChained(@states[state].action.children)

        dfrd.done(=> @transitionState(state))

    next: ->
        # override regular next-children behavior
        if @parent?
            return @parent.nextAfterChild(this)
        else
            return undefined

    run: ->
        @statesDfrd = $.Deferred()
        # start = => @runState('initial')
        # setTimeout(start, 0)

        @runState('initial')

        return @statesDfrd

    stop: ->
        @stopping = true


# Imperative Domain Specific Language bits
# Some slightly abused coffescript syntax to make
# the final script read more like an outline or
# "script" in the lines-in-a-documentary sense of the
# word

# Infrastructure for managing the 'current' object
# in our little imperative DSL
currentStack = []
currentObj = undefined

pushCurrent = (obj) ->
    currentStack.push(currentObj)
    currentObj = obj

popCurrent = ->
    currentObj = currentStack.pop()


root.scene = (sceneId, title) ->
    sceneObj = new mcb80x.Scene(sceneId, title)

    (f) ->
        currentObj = sceneObj
        f()

root.interactive = (beatId) ->
    #register the id
    beatObj = new mcb80x.Interactive(beatId)

    currentObj.addChild(beatObj)

    (f) ->
        pushCurrent(beatObj)
        f()
        popCurrent()

root.stage = (name, propertiesMap) ->

    if stages[name]?
        s = stages[name]()
    else
        console.log('loading interactive svg by name: ' + svgRoot + name)
        s = new mcb80x.InteractiveSVG(svgRoot + name)

    console.log('name: ' + name)
    console.log('propertiesMap: ' + propertiesMap)

    if propertiesMap?
        for k in Object.keys(propertiesMap)
            console.log('setting ' + k + ' on ' + s + ' to ' + propertiesMap[k])
            if s[k]?
                s[k](propertiesMap[k])

    currentObj.stage(s)


root.soundtrack = (s) ->
    currentObj.soundtrack(s)

root.line = (text, audio, actions) ->
    lineObj = new mcb80x.Line(text, audio)

    if actions?
        pushCurrent(lineObj)
        actions()
        popCurrent()

    currentObj.addChild(lineObj)


root.lines = line

root.show = (selectors...) ->
    showObj = new mcb80x.ShowAction(selectors)

    currentObj.addChild(showObj)

root.hide = (selectors...) ->
    hideObj = new mcb80x.HideAction(selectors)

    currentObj.addChild(hideObj)

root.set_property = (property, value) ->
    setObj = new mcb80x.SetAction(property, value)

    currentObj.addChild(setObj)

root.video = (name) ->
    videoObj = new mcb80x.Video(name)
    currentObj.addChild(videoObj)

    (f) ->
        pushCurrent(videoObj)
        f()
        popCurrent()

root.m4v = (f) ->
    currentObj.media('m4v', f)
root.mp4 = (f) ->
    currentObj.media('mp4', f)
root.webm = (f) ->
    currentObj.media('webm', f)
root.vimeo = (f) ->
    currentObj.media('vimeo', f)
root.youtube = (f) ->
    currentObj.media('youtube', f)


root.subtitles = (f) ->
    currentObj.subtitles(f)

root.duration = (t) ->
    currentObj.duration(t) if currentObj.duration?

root.play = (name) ->
    runObj = new mcb80x.PlayAction(name)
    currentObj.addChild(runObj)


root.wait = (delay) ->
    waitObj = new mcb80x.WaitAction(delay)
    currentObj.addChild(waitObj)

root.stop_and_reset = (name) ->
    stopResetObj = new mcb80x.StopAndResetAction(name)
    currentObj.addChild(stopResetObj)

root.goal = (f) ->
    goalObj = new mcb80x.FSM(f())
    currentObj.addChild(goalObj)

root.choice = (o) ->
    choiceObj = new mcb80x.WaitForChoice(o)
    currentObj.addChild(choiceObj)

root.fsm = goal
