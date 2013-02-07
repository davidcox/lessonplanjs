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
initSound = (cb) ->

    soundManager.setup(
        url: '/swf',
        flashVersion: 9, # optional: shiny features (default = 8)
        useFlashBlock: false, # optionally, enable when you're ready to dive in/**
        onready: ->
            soundReady = true
            cb()
    )

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

    addChild: (child) ->
        child.parent = this
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
        childId = child.elementId
        console.log('resumeAfter: ' + childId)

        if not @children? or @children.length is 0
            @yield()
        childIndex = @childIndexLookup[childId]
        @resumeAfterIndex(childIndex)

    resumeAfterIndex: (childIndex) ->
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

    yield: ->
        if @parent?
            @parent.resumeAfterChild(this)
        else
            console.log('no parent:')
            console.log(this)

    # Run through this element and all of its children
    run: ->

        # If this node doesn't have any children, yield
        # back up to the parent
        if not @children?
            @yield()
        else
            # start running the child nodes
            @runChildrenStartingAtIndex(0)


    runAtSegment: (path) ->
        if path is ''
            return @run()

        splitPath = path.split(':')

        head = splitPath.shift()

        @childLookup[head].runAtSegment(splitPath.join(':'))

    stop: ->
        child.stop() if child.stop? for child in @children

LessonElement = mcb80x.LessonElement

# Top-level "Scene"
class mcb80x.Scene extends LessonElement
    constructor: (@title, elId) ->
        if not elId?
            eleId = @title

        super(elId)

        # register this scene in the global registry
        scenes[elId] = this

        @currentSegment = ko.observable(undefined)
        @currentTime = ko.observable(undefined)

    run: ->
        @init()
        console.log('scene[' + @elementId + ']')
        super()



class mcb80x.Interactive extends LessonElement

    constructor: (elId) ->
        @duration = ko.observable(1.0)
        super(elId)

    stage: (s) ->
        if s?
            @stageObj = s
        else
            return @stageObj


    soundtrack: (s) ->
        if s?
            @soundtrackFile = s
        else
            return @soundtrackFile

        if not soundReady
            initSound(=> @loadSoundtrack(s))
        else
            @loadSoundtrack(s)

    loadSoundtrack: (s) ->
        @soundtrackAudio = soundManager.createSound(
            id: s
            url: audioRoot + s
            autoLoad: true
            autoPlay: false
            onload: =>
                @soundtrackLoaded = true
        )

    yield: ->
        # hide the stage before yielding to parent
        @stageObj.hide() if @stageObj? and @stageObj.hide?
        super()


    playSoundtrack: ->
        @soundtrackAudio.play(
            volume: 50
            onfinish: => @playSoundtrack()
        )

    run: () ->

        if @soundtrackLoaded?
            console.log('playing soundtrack')
            @playSoundtrack()
        else
            runit = => @run()
            setTimeout(runit, 100)
            return

        # show the stage and announce the current
        # segment
        @parent.currentSegment(@elementId)
        @stageObj.show() if @stageObj?

        # iterate through the child nodes, as usual
        super()

    scene: ->
        return @parent

# A somewhat hacked up video object
class mcb80x.Video extends LessonElement
    constructor: (elId) ->
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

    init: ->
        if not @pop?
            @pop = Popcorn.smart('#vid', @media('mp4'))

        @pop.on('durationchange', =>
            console.log('duration changed!:' + @pop.duration())
            @duration(@pop.duration())
        )

        console.log('Loading: ' + @media('mp4'))
        @pop.load(@media('mp4'))

        super()

    show: ->
        d3.select('#video').transition().style('opacity', 1.0).duration(1000)

    hide: ->
        d3.select('#video').transition().style('opacity', 0.0).duration(1000)

    run: (cb) ->

        @parent.currentSegment(@elementId)
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
        @pop.play(0)

    stop: ->
        @pop.pause()
        @hide()


# A "line" is a bit of audio + text that can be played
# over-top some demo.  If audio is disabled, it will
# display a modal dialog box (audio not yet enabled)

class mcb80x.Line extends LessonElement

    constructor: (@audioFile, @text, @state) ->
        super()

    init: ->
        #@div = d3.select('#prompt_overlay')
        @div = $('#prompt_overlay')
        @div.hide()

        if not soundReady
            initSound(=> @loadAudio(@audioFile))
        else
            @loadAudio(@audioFile)

        super()

    loadAudio: (af) ->
        @audio = soundManager.createSound(
            id: af
            url: audioRoot + af
            autoLoad: true
            autoPlay: false
            onload: =>
                @audioLoaded = true
        )

    run: ->
        cb = =>
            @yield()

        for k,v of @state
            console.log('setting ' + k + ' to ' + v)
            console.log(@parent.stage())
            p = @parent.stage()[k]
            console.log(p)
            p(v)

            console.log(p(v))

        if not @audioLoaded
            console.log('waiting for audio load')
            runit = => @run()
            setTimeout(runit, 100)
            return

        @audio.play(
            onfinish: -> cb()
        )

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

        @yield()

class mcb80x.HideAction extends LessonElement

    constructor: (@selectors)  ->
        super()

    run: ->
        stage = @parent.stage()
        stage.hideElement('#' + s) for s in @selectors

        @yield()


# Actions to "instruct" a demo to do something

class mcb80x.PlayAction extends LessonElement
    constructor: (@stageId) ->
        super()

    run: ->
        console.log('running play action')
        @parent.stage().play()
        @yield()

class mcb80x.StopAndResetAction extends LessonElement

    constructor: (@stageId) ->
        super()

    run: ->
        @parent.stage().stop()
        @yield()


class mcb80x.WaitAction extends LessonElement
    constructor: (@delay) ->
        super()

    run: ->
        console.log('waiting ' + @delay + ' ms...')
        cb = => @yield()
        setTimeout(cb, @delay)


class mcb80x.WaitForChoice extends LessonElement
    constructor: (@observableName) ->
        super()

    run: ->
        obs = @parent.stage()[@observableName]
        @subs = obs.subscribe( =>
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
        console.log('running fsm')
        @stopping = false
        @runState('initial')

    stop: ->
        @stopping = true
        super()


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

root.stage = (name) ->
    s = stages[name]
    currentObj.stage(s)

root.soundtrack = (s) ->
    currentObj.soundtrack(s)

root.line = (text, audio, state) ->
    lineObj = new mcb80x.Line(text, audio, state)

    currentObj.addChild(lineObj)

root.lines = line

root.show = (selectors...) ->
    showObj = new mcb80x.ShowAction(selectors)

    currentObj.addChild(showObj)

root.hide = (selectors...) ->
    hideObj = new mcb80x.HideAction(selectors)

    currentObj.addChild(hideObj)


root.video = (name) ->
    videoObj = new mcb80x.Video(name)
    currentObj.addChild(videoObj)

    (f) ->
        pushCurrent(videoObj)
        f()
        popCurrent()

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
