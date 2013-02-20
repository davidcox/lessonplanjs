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
videoSelector = '#vid'
videoDivSelector = '#video'
interactiveDivSelector = '#interactive'


class mcb80x.SceneController

    constructor: (@scene) ->

        # this is a jQuery deferred object for pausing
        # we'll start with one in a resolved state,
        # since we are not paused by default
        @deferredPause = $.Deferred().resolve()

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

    run: ->
        console.log('Scene controller: running...')

        # unset the pause deferred
        @deferredPause.reject()
        @deferredPause = $.Deferred().resolve()

        # unset the stop flags
        @stopping = false
        @stopped = false

        # get a unique ID for this stream of
        # run execution
        @currentCallId = uniqueCbId()

        # set the scene in motion
        @advance(@currentCallId)


    runAtSegment: (seg) ->
        console.log('Running from segment: ')

        if @runAtSegmentInvoked
            # already working on one these
            alert('shaking off repeat invokation of runAtSegment')
            return

        @runAtSegmentInvoked = true

        # dim the stage lights right away to
        # let the user know the click registered
        util.indicateLoading(true).then(=>
            console.log('waiting for stop')
            return @stop().promise()
        ).then(=>
            console.log('stopped...')
            @reset()
            return util.indicateLoading(false).promise()
        ).then(=>
            console.log('running scene')
            @currentElement = seg
            @runAtSegmentInvoked = false
            @run()
        )


    advance: (cbId) ->

        console.log('advance: callId = ' + cbId)

        if not @currentElement?
            # no element to run
            return

        if cbId != @currentCallId
            # another call chain has been initated, bail on this one
            alert('bailing')
            return

        if @stopping
            # a stop request issued
            @stopping = false
            @stopped = true
            return


        console.log('Scene controller: running ' + @currentElement.elementId)
        console.log(@currentElement)

        # Run it. dfrd is a jQuery deferred object
        dfrd = @currentElement.run()

        console.log('waiting for element to finish running')
        checkForCompletion = =>
            if @stopping
                @stopped = true
                @stopping = false
                # fall out
                return

            if $.when(dfrd).state() == 'pending'
                # schedule another pass
                setTimeout(checkForCompletion, 100)
                return

            else
                if cbId != @currentCallId
                    # another call chain has been initated, bail on this one
                    alert('bailing 2')
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
        @deferredPause = $.Deferred()

        # freeze execution of the current element
        #@currentElement.pause()

    resume: ->
        # resume the current element
        #@currentElement.resume()

        # release the pause deferred
        @deferredPause.resolve()

    stop: ->

        # set the stopping flag
        @stopping = true

        # reject the pause deferred, this will cause any
        # execution waiting on the pause deferred to
        # fall through and go away
        console.log('rejecting deferredPause')
        @deferredPause.reject()
        console.log('rejected')

        deferredStopped = $.Deferred()

        # instruct all elements in the scene to stop
        @scene.stop()

        checkStopped = =>
            if @stopped
                @stopping = false
                deferredStopped.resolve()
                return
            setTimeout(checkStopped, 100)

        setTimeout(checkStopped, 100)

        return deferredStopped

    reset: ->
        @currentElement = @scene
        @currentElement.reset()



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
        child.parent = this
        child.parentScene = @parentScene
        @children.push(child)
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
            return undefined

        # Look up the index of child
        childIndex = @childIndexLookup[childId]
        return @nextAfterIndex(childIndex)

    nextAfterIndex: (childIndex) ->

        nextIndex = childIndex + 1
        if @children[nextIndex]?
            return @children[nextIndex]
        else if @parent?
            return @parent.nextAfterChild(this)
        else
            return undefined

    # run starting from one of this element's children
    # this call allows recursive function call chaining
    # runChildrenStartingAtIndex: (index, cb) ->
    #     console.log('runStartingAtIndex index: ' + index)

    #     # if there is no next child, just yield
    #     if index > @children.length - 1
    #         @yield()
    #         return

    #     # otherwise, run the child node
    #     @children[index].run()

    # setCurrent: ->
    #     @parentScene.currentSegment(this) if @parentScene

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
            return undefined

    # checkIfPaused: ->
    #     if @paused()
    #         runit = =>
    #             console.log('checking if paused')
    #             @checkIfPaused()
    #         setTimeout(runit, 1000)
    #     return


    # Run through this element and all of its children
    run: ->
        return true

        # # If this node doesn't have any children, yield
        # # back up to the parent
        # if not @children?
        #     if @stopping
        #         return false
        #     else
        #         return $.Deferred.done(=> @yield())
        #                          .failed(=> @reset())
        # else
        #     # start running the child nodes
        #     return $.Deferred.done(=> @runChildrenStartingAtIndex(0))
        #                      .failed(=> @reset())

    # paused: ->
    #     if @parentScene?
    #         return @parentScene.paused()
    #     else
    #         return @parent.parentScene.paused() if @parent?

    #     return false

    reset: ->
        console.log('reseting children')

        @currentChild = 0

        # for child in Array::reverse.call(children)
        for child in @children
            child.reset()

    runAtSegment: (path) ->
        console.log('runAtSegment')

        cb = =>
            console.log('stopCb')
            if path is ''
                return @run()

            splitPath = path.split(':')

            head = splitPath.shift()

            @parentScene.reset()
            @childLookup[head].runAtSegment(splitPath.join(':'))


        # @parentScene.currentSegment().stop(cb)
        @parentScene.stop(cb)

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
        @stage().reset() if (@stage() and @stage().reset?)
        super()

    stop: ->
        @soundtrackAudio.stop() if @soundtrackAudio?
        super()


# A somewhat hacked up video object
class mcb80x.Video extends LessonElement
    constructor: (elId) ->
        @preferedFormat = 'mp4'
        @duration = ko.observable(1.0)
        @mediaUrls = {}
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

        if not globalPop?
            globalPop = Popcorn.smart(videoSelector)

        @pop = globalPop
        @load()

        super()

    show: ->
        d3.select('#interactive').transition().style('opacity', 0.0).duration(1000)
        d3.select('#video').style('display', 'inline')
        d3.select('#video').transition().style('opacity', 1.0).duration(1000)

    hide: ->
        d3.select('#video').transition().style('opacity', 0.0).duration(1000)

    # playWhenReady: ->
    #     if @pop.readyState() >= 4
    #         @pop.play(0)

    #     else
    #         playit = =>
    #             console.log('buffering... ' + @pop.readyState())
    #             @playWhenReady()
    #         setTimeout(playit, 1000)

    load: ->
        # Load the media on the player object
        f = @media(@preferedFormat)
        @pop.media.src = f
        console.log('loading ' + f)

        @pop.on('durationchange', =>
            console.log('duration changed!:' + @pop.duration())
            dur = @pop.duration()
            @duration(dur)
        )

        @pop.load()

    finish: ->
        # unregister callbacks
        @pop.off('ended', @yieldCb) if @yieldCb
        @pop.off('updatetime', @updateTimeCb) if @updateTimeCb

        # hide the video
        @hide()

    run: ->

        @load()

        console.log('playing video')

        @show()

        @updateTimeCb = =>
            t = @currentTime()
            scene.currentTime(t)
        @pop.on('timeupdate', @updateTimeCb)

        dfrd = $.Deferred()

        # yield when the view has ended
        @yieldCb = ->
            dfrd.resolve()
        @pop.on('ended', @yieldCb)

        @pop.play()

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
        console.log('installing waitForChoice subscription on ' + @observableName)
        obs = @parent.stage()[@observableName]

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
