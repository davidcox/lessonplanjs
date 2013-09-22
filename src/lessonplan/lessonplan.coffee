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
            # TODO: this is awkward
            @finish()
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
    run: (seeking=false)->
        return true


    reset: (t) ->
        @currentChild = 0

        deferreds = []
        for child in @children
            dfrd = child.reset()
            deferreds.push(dfrd)

        # deferreds = [child.reset() for child in @children]

        return $.when.apply($, deferreds)


    stop: ->
        return $.when.apply($, [child.stop() for child in @children])

    pause: ->

    resume: ->

    finish: ->

    ready: -> true


    # Cleanup any persisting affects of having run
    # No guarantee that the element will still work
    # after this operation
    cleanup: ->
        return $.when.apply($, [child.cleanup() for child in @children])


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

    run: (seeking=false) ->
        console.log('scene[' + @elementId + ']')

        @init()
        return $.when(util.indicateLoading(false))
                .then(=> util.showTitleBanner(@title, 5000.0))
                .then(=> super())


class lessonplan.Message extends LessonElement

    constructor: (@msg) ->
        super()

    run: () ->
        console.log @msg

# An "interactive" element; e.g. an animated SVG that can
# be marionetted
class lessonplan.Interactive extends LessonElement

    constructor: (elId) ->
        @duration = ko.observable(1.0)
        @soundtrackFile = undefined
        @soundtrackLoaded = false
        @hasSoundtrack = false
        @justSeeked = false
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

        stopPromise = true
        hidePromise = true

        # stop the simulation if appropriate
        if @stageObj? and @stageObj.stop?
            stopPromise = @stageObj.stop()

        # hide the stage
        if @stageObj? and @stageObj.hide?
            hidePromise = @stageObj.hide()

        return $.when(stopPromise, hidePromise)

    playSoundtrack: ->
        @soundtrackAudio.load()
        # @soundtrackAudio.play().setVolume(8)
        @soundtrackAudio.play().setVolume(0)

    run: (seeking=false) ->

        # If we're in seeking mode, just blast through without
        # running anything.
        if seeking
            return true

        @playSoundtrack() if @hasSoundtrack

        # this will show the interactive SVG,
        # loading the SVG itself if necessary
        # @stageObj.show() if @stageObj? and @stageObj.show?

        if @stageObj? and not @justSeeked
            return @stageObj.show()

        if @justSeeked
            @justSeeked = false

        return super()

    reset: ->
        @soundtrackAudio.stop() if @soundtrackAudio?

        stopPromise = true
        resetDfrd = $.Deferred()

        if @stage()?

            $.when(@stage().stop()).then(=>
                return @stage().reset()

            ).then(=>
                resetDfrd.resolve()
            )
        else
            console.log 'no stage'


        return $.when(resetDfrd, super())

    stop: ->

        @soundtrackAudio.stop() if @soundtrackAudio?

        stopPromise = true
        hidePromise = true
        if @stage() and @stage().stop?
            stopPromise = @stage().stop()

        if @stage() and @stage().hide?
            hidePromise = @stage().hide()
        return $.when(stopPromise, hidePromise, super())


    # Find a particular milestone and return it
    # If `seeking` is set to true, all of the elements along the
    # way will be run in "seeking" mode
    findMilestone: (name, el, seeking=false) ->
        # do a depth-first search until we find a milestone with this name

        if not el?
            el = this

        if el instanceof lessonplan.MilestoneAction and el.name is name
            return el

        if seeking
            el.run(true)  # run "silently"

        for child in el.children
            el2 = @findMilestone(name, child, seeking)
            if el2?
                return el2

        return null


    # find and return a list of all milestones
    findMilestones: (el, milestones) ->

        if not el?
            el = this

        if not milestones?
            milestones = []

        if el instanceof lessonplan.MilestoneAction
            milestones.push(el)

        for child in el.children
            @findMilestones(child, milestones)

        return milestones

    seek: (name) ->

        # don't try to seek to a milestone that
        # doesn't exist
        if not name? or not @findMilestone(name, this)
            return true

        dfrd = $.Deferred()

        if @stageObj?
            stage_dfrd = @stageObj.show()
        else
            stage_dfrd = true

        $.when(stage_dfrd).then(=>
            el = @findMilestone(name, this, true)

            # hack the current state
            if el?
                el.disarm()
                @currentChild = @children.indexOf(el)
                if not @currentChild? or @currentChild < 0
                    @currentChild = 0
            dfrd.resolve()

            @justSeeked = true
        )

        return dfrd


# A helper for running a sequence of deferred actions
# in order

lessonplan.runChained = (actions, seeking=false) ->
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

        dfrd = a.shift().run(seeking)
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
        return super()

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

    run: (seeking=false) ->


        childDeferred = true

        # If there are child actions, we'll run these in
        # tandem with the line/voiceover
        if @children? and @children.length

            childDeferred = lessonplan.runChained(@children, seeking)

        if seeking
            return true

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

    run: (seeking=false) ->
        stage = @parent.stage()

        stage.showElement('#' + s) for s in @selectors


# Hide an element in an interactive svg
class lessonplan.HideAction extends LessonElement

    constructor: (@selectors)  ->
        super()

    run: (seeking=false) ->
        stage = @parent.stage()
        stage.hideElement('#' + s) for s in @selectors


# Set a variable / property on an interactive svg
# (e.g. simulation parameter)
class lessonplan.SetAction extends LessonElement

    constructor: (@property, @value)  ->
        super()

    run: (seeking=false) ->
        stage = @parent.stage()
        stage[@property](@value)


# Communicate with a backend API to register the completion
# of a milestone
class lessonplan.MilestoneAction extends LessonElement

    constructor: (@name, @title=null) ->
        @disarmed = false
        super()

    disarm: ->
        @disarmed = true

    run: (seeking=false)  ->

        if seeking
            return true

        if @disarmed
            @disarmed = false
            return

        # post the milestone
        path = root.module_id + '/' + root.lesson_id + '/' + root.segment_id + '/' + @name
        console.log 'calling completeMilestone'
        milestones.completeMilestone(path, @name)


# "Play" an interactive (if it has a notion of playing and stopping)
class lessonplan.PlayAction extends LessonElement
    constructor: (@stageId) ->
        super()

    run: (seeking=false) ->
        @parent.stage().play()


class lessonplan.StopAndResetAction extends LessonElement

    constructor: (@stageId) ->
        super()

    run: (seeking=false) ->
        @parent.stage().stop()


# Wait a fixed time before proceeding
class lessonplan.WaitAction extends LessonElement
    constructor: (@delay) ->
        super()

    run: (seeking=false) ->

        if seeking
            return true

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

    run: (seeking=false) ->

        if seeking
            return

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
            dfrd = lessonplan.runChained(@states[state].action.children)

        dfrd.done(=> @transitionState(state))

    next: ->
        # override regular next-children behavior
        if @parent?
            return @parent.nextAfterChild(this)
        else
            return undefined

    run: (seeking=false) ->

        if seeking
            return true

        @statesDfrd = $.Deferred()
        # start = => @runState('initial')
        # setTimeout(start, 0)

        @runState('initial')

        return @statesDfrd

    stop: ->
        @stopping = true



