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
                            # .then(=>
                            #     l 'finishing'
                            #     @currentElement.finish())
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
                    @stopped = true
                    punt()
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
        console.log('scene[' + @elementId + ']')

        @init()
        return $.when(util.indicateLoading(false))
                .then(=> util.showTitleBanner(@title, 5000.0))
                .then(=> super())


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

        super()

    stop: ->
        console.log('>>>>>>>> stop audio')
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

        # hide the video player by default
        $(videoPlayerDivSelector).attr('style', 'opacity: 0.0;')

        @playerSelector = undefined

        @load()

        super()

    reset: (t) ->
        console.log('Resetting video')
        t = 0.0 if not t?
        @seek(t)

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
                console.log('video finished cb')
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
        childDeferred = true

        # If there are child actions, we'll run these in
        # tandem with the line/voiceover
        if @children? and @children.length

            childDeferred = runChained(@children)


        audioDeferred = $.Deferred()

        @audio.bind('ended', =>
            audioDeferred.resolve()
        )

        console.log('playing audio: ' + @audioFile)
        @audio.load()
        @audio.play()

        # return a deferred object that is contingent on
        # both the audio and the children
        return $.when(audioDeferred, childDeferred)



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
