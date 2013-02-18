#<< mcb80x/util

root = window ? exports

root.registry = []
root.scenes = {}
root.stages = []

# Infrastructure for managing the 'current' object
# in our little imperative DSL
currentStack = []
currentObj = undefined

pushCurrent = (obj) ->
    currentStack.push(currentObj)
    currentObj = obj

popCurrent = ->
    currentObj = currentStack.pop()

elementCounter = -1
uniqueElementId = ->
    elementCounter += 1
    'element_assigned_id_' + elementCounter


soundReady = false
audioRoot = '/audio/'
svgRoot = '/svg/'
videoRoot = '/video/'
videoSelector = '#vid'
videoDivSelector = '#video'
interactiveDivSelector = '#interactive'


# initSound = (cb) ->

#     soundManager.setup(
#         preferFlash: false,
#         url: '/swf/',
#         flashVersion: 9,
#         useFlashBlock: false,
#         useHTML5Audio: true,
#         onready: ->
#             soundReady = true
#             cb()
#     )

# Lesson Elements
# These are the objects that the DSL will actually build
# They are organized hierarchically with a "Scene" at the
# top level, with story "beats" below
# This code is a bit of a mess at the moment, but it is
# basically functional

# Base LessonElement
class mcb80x.LessonElement

    constructor: (@elementId) ->

        @holds = []

        @stopping = false

        if not @elementId?
            @elementId = uniqueElementId()
        registry[@elementId] = this
        @children = []
        @childIndexLookup = {}
        @childLookup = {}
        @parent = undefined

        @parentScene = undefined

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
    resumeAfterChild: (child) ->
        console.log('resumeAfterChild (stopping = ' + @stopping + ')')
        if @stopping
            return
        childId = child.elementId
        console.log('resumeAfter: ' + childId)

        if not @children? or @children.length is 0
            @yield()
        childIndex = @childIndexLookup[childId]
        @resumeAfterIndex(childIndex)

    resumeAfterIndex: (childIndex) ->
        console.log('resumeAfterIndex')
        nextIndex = childIndex + 1
        if @children[nextIndex]?
            @children[nextIndex].run()
        else
            @yield()

    # run starting from one of this element's children
    # this call allows recursive function call chaining
    runChildrenStartingAtIndex: (index, cb) ->
        console.log('runStartingAtIndex index: ' + index)

        # if there is no next child, just yield
        if index > @children.length - 1
            @yield()
            return

        # otherwise, run the child node
        @children[index].run()

    setCurrent: ->
        @parentScene.currentSegment(this) if @parentScene

    yield: ->
        console.log('yield')
        console.log('stopping = ' + @stopping)
        if @holds.length > 0
            @holds.pop()

        if @holds.length > 0
            # something else still not finished
            console.log('waiting on more holds')
            return

        # @stop()

        if @parent?
            console.log('going to resume after child')
            @parent.resumeAfterChild(this)
        else
            console.log('no parent:')
            console.log(this)

    checkIfPaused: ->
        if @paused()
            runit = =>
                console.log('checking if paused')
                @checkIfPaused()
            setTimeout(runit, 1000)
        return


    # Run through this element and all of its children
    run: ->
        @setCurrent()
        @checkIfPaused()

        @stopping = false

        console.log('running with children: ' + @children)
        # If this node doesn't have any children, yield
        # back up to the parent
        if not @children?
            if @stopping
                return
            else
                @yield()
        else
            # start running the child nodes
            @runChildrenStartingAtIndex(0)

    paused: ->
        if @parentScene?
            return @parentScene.paused()
        else
            return @parent.parentScene.paused() if @parent?

        return false

    reset: ->
        console.log('reseting')
        @holds = []
        @stopping = false

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

    stop: (cb) ->
        @stopping = true

        for child in @children
            if child? and child.stop?
                child.stop()

        cb() if cb

    pause: ->
        console.log('base pause')

    resume: ->

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
        super()

    reset: ->
        @paused(false)
        super()

    paused: (isit) ->
        if isit
            @isPaused = isit
        else
            return @isPaused

    pause: ->
        @isPaused = true
        @currentSegment().pause()

    resume: ->
        @isPaused = false
        @currentSegment().resume()



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
            preload:true)

    yield: ->
        # hide the stage before yielding to parent
        @stageObj.hide() if @stageObj? and @stageObj.hide?
        super()


    playSoundtrack: ->
        @soundtrackAudio.loop().play()

    run: () ->
        console.log('running interactive')
        @checkIfPaused()

        @playSoundtrack() if @hasSoundtrack

        # show the stage and announce the current
        # segment
        @parent.currentSegment(this)

        console.log('stage: ' + @stageObj)
        if @stageObj?
            @stageObj.show(=> super())
        else
            # iterate through the child nodes, as usual
            super()

    stop: (cb) ->
        @soundtrackAudio.stop() if @soundtrackAudio?
        super(cb)

    scene: ->
        return @parent

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

    run: (cb) ->

        @checkIfPaused()

        @load()

        console.log('playing video')

        @parent.currentSegment(this)
        @show()

        scene = @parent
        console.log(scene)


        updateTimeCb = ->
            t = @currentTime()
            scene.currentTime(t)
        @pop.on('timeupdate', updateTimeCb)

        cb = =>
            console.log('popcorn triggered cb')
            console.log(cb)
            @pop.off('ended', cb)
            @pop.off('updatetime', updateTimeCb)
            @hide()
            @yield()

        # yield when the view has ended
        @pop.on('ended', cb)

        #@playWhenReady()
        console.log(@pop)
        @pop.play()

    pause: ->
        @pop.pause() if @pop

    resume: ->
        @pop.play() if @pop

    stop: (cb) ->
        @pop.pause() if @pop
        @hide()
        super(cb)


# A "line" is a bit of audio + text that can be played
# over-top some demo.  If audio is disabled, it will
# display a modal dialog box (audio not yet enabled)

class mcb80x.Line extends LessonElement

    constructor: (@audioFile, @text, @state) ->
        super()

    init: ->
        @div = $('#prompt_overlay')
        @div.hide()

        # if not soundReady
        #     initSound(=> @loadAudio(@audioFile))
        # else
        @loadAudio(@audioFile)

        super()

    loadAudio: (af) ->
        console.log('loading: ' + af)
        @audio = new buzz.sound(audioRoot + af,
            preload: true
        )
        # @audio.bind('canplay', =>
        #     console.log(af + ' can play')
        #     @audioLoaded = true
        # )
        # @audio.load()

        # soundManager.createSound(
        #     id: af
        #     url: audioRoot + af
        #     autoLoad: true
        #     autoPlay: false
        #     onload: =>
        #         @audioLoaded = true
        # )

    stage: ->
        return @parent.stage()

    stop: (cb) ->
        console.log('line stop')
        @audio.stop() if @audio
        super(cb)

    run: ->
        console.log('Running line...')
        @setCurrent()
        @checkIfPaused()

        for k,v of @state
            console.log('setting ' + k + ' to ' + v)
            console.log(@parent.stage())
            p = @parent.stage()[k]
            console.log(p)
            p(v)

            console.log(p(v))

        # if not @audioLoaded
        #     console.log('waiting for audio load')
        #     runit = => @run()
        #     setTimeout(runit, 100)
        #     return

        # put two "holds" on the advance of the lesson.
        # both the audio *and* the children (if there are any)
        # hae to call yield to proceed
        @holds.push('audio')
        @holds.push('default')

        @audio.bind('ended', =>
                console.log('on finish yield')
                @yield()
        )

        @audio.play()

        super()

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
        @setCurrent()
        @checkIfPaused()

        stage = @parent.stage()
        stage.showElement('#' + s) for s in @selectors

        @yield()

class mcb80x.HideAction extends LessonElement

    constructor: (@selectors)  ->
        super()

    run: ->
        @setCurrent()
        @checkIfPaused()

        stage = @parent.stage()
        stage.hideElement('#' + s) for s in @selectors

        @yield()

class mcb80x.SetAction extends LessonElement

    constructor: (@property, @value)  ->
        super()

    run: ->
        @setCurrent()
        @checkIfPaused()

        stage = @parent.stage()
        stage[@property](@value)

        @yield()


# Actions to "instruct" a demo to do something

class mcb80x.PlayAction extends LessonElement
    constructor: (@stageId) ->
        super()

    run: ->
        @setCurrent()
        @checkIfPaused()

        console.log('running play action')
        @parent.stage().play()
        @yield()

class mcb80x.StopAndResetAction extends LessonElement

    constructor: (@stageId) ->
        super()

    run: ->
        @checkIfPaused()

        @parent.stage().stop()
        @yield()


class mcb80x.WaitAction extends LessonElement
    constructor: (@delay) ->
        super()

    run: ->
        @setCurrent()
        @checkIfPaused()

        console.log('waiting ' + @delay + ' ms...')
        cb = => @yield()
        setTimeout(cb, @delay)


class mcb80x.WaitForChoice extends LessonElement
    constructor: (@observableName) ->
        super()

    run: ->
        @setCurrent()
        @checkIfPaused()

        console.log('installing waitForChoice subscription on ' + @observableName)
        obs = @parent.stage()[@observableName]
        console.log(obs)
        @subs = obs.subscribe( =>
            console.log('waitForChoice yielding')
            @subs.dispose()
            @yield()
        )

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
                @yield()
            else
                @runState(transitionTo)
        else
            t = => @transitionState(state)
            setTimeout(t, @delay)

    runState: (state, cb) ->
        console.log('ACTION: state: ' + state)
        @startTime = new Date().getTime()

        if @states[state].action?
            @states[state].action.yield = => @transitionState(state)
            @states[state].action.run()
        else
            @transitionState(state)

    run: ->
        @setCurrent()
        @checkIfPaused()

        console.log('running fsm')
        @stopping = false
        @runState('initial')


# Imperative Domain Specific Language bits
# Some slightly abused coffescript syntax to make
# the final script read more like an outline or
# "script" in the lines-in-a-documentary sense of the
# word

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
