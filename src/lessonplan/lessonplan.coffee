#<< lessonplan/util
#<< lessonplan/milestones
#<< lessonplan/status
#<< lessonplan/bindings

# A series of object for defining guided-interactive
# educational scripts.

root = window ? exports

root.registry = []
root.scenes = {}
root.stages = {}

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


    stage: (s) ->
        if not s?
            if @parent? and @parent != this
                return @parent.stage()

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
        @soundtrackAudio.play().setVolume(6)
        # @soundtrackAudio.play().setVolume(0)

    show: ->
        $('#interactive').css('z-index', 100)

    run: (seeking=false) ->

        # If we're in seeking mode, just blast through without
        # running anything.
        if seeking
            return true

        # @playSoundtrack() if @hasSoundtrack

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
        $.when(dfrd).then ->
            # check if the sequence deferred has been rejected
            # from outside
            if sdfrd.state() != 'rejected'
                chainIt(a)
            else
                console.log 'rejected'

    chainIt(actionsCopy)

    # return the "sequence" deferred
    return sdfrd



# A "line" is a bit of audio + text that can be played
# over-top some demo.  If audio is disabled, it will
# display a modal dialog box (audio not yet enabled)

class lessonplan.Line extends LessonElement

    constructor: (@audioFile, @text) ->
        @errorState = 0
        super()

    init: ->
        @loadAudio(@audioFile)
        @subtitleContainer = $('#subtitle-container')
        super()

    loadAudio: (af) ->
        console.log('loading: ' + af)

        if af[0] is '/'
            audioPath = root.audio_base_url + af
            console.log 'here: ' + audioPath
        else
            audioPath = audioRoot + '/' + af

        @audio = new buzz.sound(audioPath,
            preload: true
        )
        @audio.bind('empty error', =>
            console.log('Audio error [' + @audioFile + ']: ' + @audio.getErrorMessage())
            @errorState = @audio.getErrorCode()
        )
        @audio.load()

    reset: ->
        $.when(@stop()).then =>
            if @childDeferred
                @childDeferred = undefined
            super()

    stage: ->
        return @parent.stage()

    pause: ->

        deferreds = []

        if @childDeferred?
            @childDeferred.reject()

            $.when(@childDeferred).then =>
                for child in @children
                    dfrd = child.reset()
                    deferreds.push(dfrd)

                # child.reset() for child in @children

        if @children? and @children.length and @audio?
            # if there are subordinate actions, then just stop the
            # audio so we can restart from a fresh state
            deferreds.push(@audio.stop())
        else
            deferreds.push(@audio.pause())

        return $.when.apply($, deferreds)


    resume: ->
        if @children? and @children.length
            console.log 'restart line'
            $.when(@reset()).then =>
                @run()
        else
            @audio.play() if @audio

    stop: ->
        @audio.stop() if @audio
        @audio.unbind('ended')
        super()

    next: ->
        # don't navigate children normally (as in super()); they will run
        # concurrent with the line
        if @parent?
            if @text?
                @subtitleContainer.empty()
            # $('.interactive-subtitle').remove()
            return @parent.nextAfterChild(this)
        else
            return undefined

    run: (seeking=false) ->


        @childDeferred = $.Deferred().resolve()

        # If there are child actions, we'll run these in
        # tandem with the line/voiceover
        if @children? and @children.length

            @childDeferred = lessonplan.runChained(@children, seeking)

        if seeking
            return true

        audioDeferred = $.Deferred()


        if @errorState == 0 and @audio.getNetworkStateCode() != 3

            @audio.bind('empty.run error.run', =>
                console.log 'Audio error [' + @audioFile + ']: ' + @audio.getErrorMessage()
                @errorState = @audio.getErrorCode()
                audioDeferred.resolve()
            )

            @audio.bind('ended', ->
                audioDeferred.resolve()
            )

        else
            console.log 'Audio [' + @audioFile + '] will not play'
            audioDeferred.resolve()

        @audio.bind('ended', =>
            audioDeferred.resolve()
        )

        console.log('playing audio: ' + audioRoot + '/' + @audioFile)
        @audio.load()
        @audio.play()

        if @text?
            @subtitleContainer.append('<div class="interactive-subtitle">' + @text + '</div>')

        # return a deferred object that is contingent on
        # both the audio and the children
        return $.when(audioDeferred, @childDeferred)



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


class lessonplan.HideAllAction extends LessonElement

    constructor:  ->
        super()

    run: (seeking=false) ->
        stage = @parent.stage()
        stage.hideAllElements()


class lessonplan.GlowAction extends LessonElement
    constructor: (@selectors)  ->
        super()

    run: (seeking=false) ->
        stage = @parent.stage()
        stage.glowElement('#' + s) for s in @selectors


class lessonplan.UnglowAction extends LessonElement
    constructor: (@selectors)  ->
        super()

    run: (seeking=false) ->
        stage = @parent.stage()
        stage.unglowElement('#' + s) for s in @selectors


class lessonplan.BoxHighlightAction extends LessonElement
    constructor: (@color, @selectors)  ->
        super()

    run: (seeking=false) ->
        stage = @parent.stage()
        stage.boxAroundElement('#' + s, @color) for s in @selectors


class lessonplan.BoxUnhighlightAction extends LessonElement
    constructor: (@selectors)  ->
        super()

    run: (seeking=false) ->
        stage = @parent.stage()
        for s in @selectors
            console.log s
            stage.unboxElement('#' + s)


class lessonplan.XHighlightAction extends LessonElement
    constructor: (@selectors)  ->
        super()

    run: (seeking=false) ->
        stage = @parent.stage()
        console.log 'x-ing!'
        stage.xHighlightElement('#' + s) for s in @selectors


class lessonplan.XUnhighlightAction extends LessonElement
    constructor: (@selectors)  ->
        super()

    run: (seeking=false) ->
        stage = @parent.stage()
        console.log 'un-x-ing!'
        stage.xUnhighlightElement('#' + s) for s in @selectors


class lessonplan.GroupTransitionAction extends LessonElement
    constructor: (@fromSel, @toSel) ->
        super()

    run: (seeking=false) ->
        stage = @parent.stage()

        if seeking
            console.log 'Hiding: #' + @fromSel
            stage.hideElement('#' + @fromSel)
            stage.showElement('#' + @toSel)

        else
            util.transitionGroups(@fromSel, @toSel)

class lessonplan.MultipleChoiceQuestion extends LessonElement
    constructor: (@varname) ->
        @observable = ko.observable 'none'
        super()

    mapping: (m) ->

        @map = {}
        for k in Object.keys(m)
            @map['#' + k] = m[k]


    run: (seeking=false) ->
        stage= @parent.stage()

        stage[@varname] = @observable

        svgbind.bindMultipleChoice(stage.svg, @map, @observable)


# Set a variable / property on an interactive svg
# (e.g. simulation parameter)
class lessonplan.SetAction extends LessonElement

    constructor: (@property, @value, @time)  ->
        super()

    run: (seeking=false) ->
        stage = @parent.stage()

        if @time == 0
            stage[@property](@value)
        else
            start =
                v: stage[@property]()
            end =
                v: @value
            prop = stage[@property]
            $(start).animate(end,
                duration: @time
                step: ->
                    prop(this.v)
            )



# Communicate with a backend API to register the completion
# of a milestone
class lessonplan.MilestoneAction extends LessonElement

    constructor: (@name, @title) ->
        if not @title?
            @title = @name
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
        lessonplan.milestones.completeMilestone(path, @name)


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
        @options = []

    addOption: (opt) ->
        opt.parent = this
        @options.push(opt)

    init: ->
        for opt in @options
            opt.init()
        super()


    reset: ->
        @children = []

    run: (seeking=false) ->

        if seeking
            return

        s = @parent.stage()
        obs = @parent.stage()[@observableName]

        console.log('stage = ' + s + ', obs = ' + obs)
        console.log(s)

        console.log('installing waitForChoice subscription on ' + @observableName)
        @dfrd = $.Deferred()

        @subs = obs.subscribe( (v) =>
            console.log('waitForChoice yielding')
            console.log v
            @subs.dispose()

            for opt in @options
                console.log opt
                if v in opt.value
                    console.log 'opt.value = ' + opt
                    console.log opt
                    if opt.children?
                        # attach the children of the option to
                        # item so that the scene controller will run them
                        @children = opt.children

                        @dfrd.resolve()

                        # opt.stage = => @parent.stage()
                        # option_dfrd = lessonplan.runChained(opt.children)
                        # $.when(option_dfrd).then(=>
                        #     @dfrd.resolve()
                        # )
                        return
                    else
                        break

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

        @statesDfrd = $.Deferred().resolve()
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
        super()

    getElapsedTime: ->
        now = new Date().getTime()
        return now - @startTime

    run: (seeking=false) ->

        if seeking
            return true

        # This dfrd will only be resolved on exiting the
        # state system
        @statesDfrd = $.Deferred()

        # start the state system
        go = => @runState('initial')
        setTimeout(go, 0)

        return @statesDfrd


    runState: (state, cb) ->
        console.log('ACTION: state: ' + state)
        @startTime = new Date().getTime()

        dfrd = $.Deferred()

        dfrd.done =>
            console.log 'runState'
            @transitionState(state)

        if @states[state].action? and @states[state].action.children.length
            $.when(lessonplan.runChained(@states[state].action.children)).then ->
                dfrd.resolve()
        else
            dfrd.resolve()

    transitionState: (state) ->
        console.log 'transitionState: ' + state

        if @stopping
            console.log 'stopping'
            @stopping = false
            @statesDfrd.resolve()
            return

        stateObj = @states[state]

        # pin some values to the object to make the DSL easier
        # to use
        stateObj.elapsedTime = @getElapsedTime()
        stateObj.stage = @stage()

        transitionTo = stateObj.transition()
        console.log 'transitionTo: '
        console.log transitionTo

        if transitionTo?
            if transitionTo is 'continue'
                console.log('yielding...')
                @statesDfrd.resolve()
            else
                @runState(transitionTo)
        else
            t = => @transitionState(state)
            setTimeout(t, @delay)

    next: ->
        # override regular next-children behavior
        if @parent?
            return @parent.nextAfterChild(this)
        else
            return undefined

    stop: ->
        if @statesDfrd.state() == 'pending'
            @stopping = true



