#<< lessonplan/util
#<< lessonplan/milestones
#<< lessonplan/status

# A series of object for defining guided-interactive
# educational scripts.

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
module_path = root.module_id + '/' + root.lesson_id + '/' + root.segment_id
audioRoot = root.audio_base_url + '/' + module_path
soundtrackRoot = root.audio_base_url + '/soundtracks'




# Lesson Elements
# These are the objects that the DSL will actually build
# They are organized hierarchically with a "Scene" at the
# top level, with story "beats" below
# This code is a bit of a mess at the moment, but it is
# basically functional

# Base LessonElement
class lessonplan.LessonElement

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
        # console.log('adding ' + child.elementId + ' to ' + @elementId)
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
        # console.log('currentChild = ' + @currentChild)

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

    resume: ->

    finish: ->

    ready: -> true


    # Cleanup any persisting affects of having run
    # No guarantee that the element will still work
    # after this operation
    cleanup: ->
        for child in @children
            child.cleanup()


LessonElement = lessonplan.LessonElement


# Top-level "Scene"
class lessonplan.Scene extends LessonElement
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
        console.log('scene[' + @elementId + ']')

        @init()
        return $.when(util.indicateLoading(false))
                .then(=> util.showTitleBanner(@title, 5000.0))
                .then(=> super())


# An "interactive" element; e.g. an animated SVG that can
# be marionetted
class lessonplan.Interactive extends LessonElement

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
        @soundtrackAudio = new buzz.sound(soundtrackRoot + '/' + s,
            preload:true
            loop: true
        )

    finish: ->
        @soundtrackAudio.stop() if @soundtrackAudio?

        # hide the stage
        @stageObj.hide() if @stageObj? and @stageObj.hide?


    playSoundtrack: ->
        @soundtrackAudio.load()
        @soundtrackAudio.play().setVolume(8)

    run: () ->
        console.log('running interactive')

        @playSoundtrack() if @hasSoundtrack

        if @stageObj?
            return @stageObj.show()

        return super()

    reset: ->
        @soundtrackAudio.stop() if @soundtrackAudio?
        @stage().stop() if (@stage() and @stage().stop?)

        @stage().reset() if (@stage() and @stage().reset?)
        super()

    stop: ->
        console.log('>>>>>>>> stop audio')
        @soundtrackAudio.stop() if @soundtrackAudio?
        @stage().stop() if (@stage() and @stage().stop?)
        super()




# A helper for running a sequence of deferred actions
# in order

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

class lessonplan.Line extends LessonElement

    constructor: (@audioFile, @text) ->
        super()

    init: ->
        @loadAudio(@audioFile)
        @subtitleContainer = $('#subtitle-container')
        super()

    loadAudio: (af) ->
        console.log('loading: ' + af)
        @audio = new buzz.sound(audioRoot + '/' + af,
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
            @subtitleContainer.empty()
            # $('.interactive-subtitle').remove()
            return @parent.nextAfterChild(this)
        else
            return undefined

    run: ->
        childDeferred = true

        # If there are child actions, we'll run these in
        # tandem with the line/voiceover
        if @children? and @children.length

            childDeferred = runChained(@children)


        audioDeferred = $.Deferred()

        @audio.bind('ended', =>
            audioDeferred.resolve()
        )

        console.log('playing audio: ' + audioRoot + '/' + @audioFile)
        @audio.load()
        @audio.play()

        @subtitleContainer.append('<div class="interactive-subtitle">' + @text + '</div>')

        # return a deferred object that is contingent on
        # both the audio and the children
        return $.when(audioDeferred, childDeferred)



# Show an element in an interactive svg
class lessonplan.ShowAction extends LessonElement

    constructor: (@selectors)  ->
        super()

    run: ->
        stage = @parent.stage()
        stage.showElement('#' + s) for s in @selectors


# Hide an element in an interactive svg
class lessonplan.HideAction extends LessonElement

    constructor: (@selectors)  ->
        super()

    run: ->
        stage = @parent.stage()
        stage.hideElement('#' + s) for s in @selectors


# Set a variable / property on an interactive svg
# (e.g. simulation parameter)
class lessonplan.SetAction extends LessonElement

    constructor: (@property, @value)  ->
        super()

    run: ->
        stage = @parent.stage()
        stage[@property](@value)


# Communicate with a backend API to register the completion
# of a milestone
class lessonplan.MilestoneAction extends LessonElement

    constructor: (@name) ->
        super()

    run: ->
        # post the milestone
        path = root.module_id + '/' + root.lesson_id + '/' + root.segment_id
        console.log 'calling completeMilestone'
        # milestones.completeMilestone(path, @name)


# "Play" an interactive (if it has a notion of playing and stopping)
class lessonplan.PlayAction extends LessonElement
    constructor: (@stageId) ->
        super()

    run: ->
        @parent.stage().play()


class lessonplan.StopAndResetAction extends LessonElement

    constructor: (@stageId) ->
        super()

    run: ->
        @parent.stage().stop()


# Wait a fixed time before proceeding
class lessonplan.WaitAction extends LessonElement
    constructor: (@delay) ->
        super()

    run: ->
        console.log('waiting ' + @delay + ' ms...')
        @dfrd = $.Deferred()
        cb = =>
            @dfrd.resolve()

        setTimeout(cb, @delay)
        return @dfrd


# Wait for an observable (e.g. KnockOut.js binding) to
# change state before resuming

class lessonplan.WaitForChoice extends LessonElement
    constructor: (@observableName) ->
        super()

    run: ->

        s = @parent.stage()
        obs = @parent.stage()[@observableName]

        console.log('stage = ' + s + ', obs = ' + obs)
        console.log(s)

        console.log('installing waitForChoice subscription on ' + @observableName)
        @dfrd = $.Deferred()

        @subs = obs.subscribe( =>
            console.log('waitForChoice yielding')
            @subs.dispose()
            @dfrd.resolve()
        )

        return @dfrd



# A finite state machine
# The idea here is to have a simple state machine so
# that simple interactive goals can be easily defined
class lessonplan.FSM extends LessonElement

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
            dsl.pushCurrent(actionObj)
            if v.action?
                v.action()
            dsl.popCurrent()


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



