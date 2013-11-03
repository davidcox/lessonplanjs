# An object controlling the appearance and UI on the unified
# video / interactive / etc. timeline
#

class lessonplan.Timeline

    constructor: (selector, @sceneController) ->

        # Player state bindings
        @paused = @sceneController.pausedObservable
        @playing = @sceneController.playingObservable


        @self = ko.observable(this)

        # Look and Feel parameters
        @markerSmall = '5'
        @markerLarge = '7'

        @progressbarTop = '30%'
        @progressbarHeight = '35%'
        @progressbarCenter = '50%'

        # DOM elements
        @parentDiv = d3.select(selector)
        @markers = undefined
        @submarkers = undefined

        @div = @parentDiv.select('#timeline')

        @svg = @div.append('svg').attr('id', 'timeline-svg').attr('class', 'timeline-svg')

        # Add a cross-hatch pattern to the svg defs
        defs = @svg.append('svg:defs')
        defs.append('svg:pattern')
                .attr('id', 'patstripes')
                .attr('width', 15)
                .attr('height', 15)
                .attr('x', 0)
                .attr('y', 0)
                .attr('patternUnits', 'userSpaceOnUse')
            .append('svg:image')
                .attr('width', 15)
                .attr('height', 15)
                .attr('x', 0)
                .attr('y', 0)
                .attr('xlink:href', static_base_url + '/images/stripes.png')

        # The background rectangle of the timeline
        @bgRect = @svg.append('rect')
            .attr('width', '100%')
            .attr('height', '100%')
            .attr('class', 'timeline-background-rect')

        # A background for the unfilled portion of the timeline
        @progressbarBackground = @svg.append('rect')
            .attr('width', '100%')
            .attr('height', @progressbarHeight)
            .attr('x', '0')
            .attr('y', @progressbarTop)
            .attr('class', 'timeline-progressbar-background')

        # The progress bar
        @progressbar = @svg.append('rect')
            .attr('width', 0.0)
            .attr('height', @progressbarHeight)
            .attr('x', '0')
            .attr('y', @progressbarTop)
            .attr('class', 'timeline-progressbar')

        # A cross-hatched progress bar to fill a variable-time region
        @activebar = @svg.append('rect')
            .attr('width', 0.0)
            .attr('height', @progressbarHeight)
            .attr('x', '0')
            .attr('y', @progressbarTop)
            .attr('class', 'timeline-activebar')
            .attr('fill', 'url(#patstripes)')
            # .attr('fill', '#666')

        @sceneIndicatorDiv = d3.select('#scene-indicator')
        @sceneIndicatorSVG = @sceneIndicatorDiv.append('svg').attr('class', 'scene-indicator-group')


        # Setup timeline bindings

        @currentTime = 0.0

        # The scene controller keeps a time variable that is manipulated by videos
        # but which holds at 0.0 all other times.
        # It shall be assumed to refer to the currentLessonElement (below)
        @sceneController.currentTime.subscribe( (v) =>
            @update(@sceneController.currentElement, v)
        )


        # Current Lesson Element hold the current lessonplan.LessonElement
        # from the scene controller
        @sceneController.currentLessonElement.subscribe( (v) =>
            console.log @sceneController.currentTime
            console.log @sceneController.currentTime()
            if @sceneController.currentTime?
                @update(@sceneController.currentElement, @sceneController.currentTime())
        )


        # Handle segment changes in the segment selector

        # currentScene holds the lessonplan.LessonElement object for the scene
        # This is where the setup of the timeline (spacing etc.) is kicked off
        @sceneController.currentScene.subscribe( (v) =>
            @loadScene(v)
            @setupTiming()
            @setupSceneIndicator()
        )

        # currentSceneIndex holds the numeric index of where the segment sits in order
        @sceneController.currentSceneIndex.subscribe( (v) =>
            @updateSceneIndicator(v)
        )


        # register a click handler for the timeline
        timeline = this
        @svg.on('click', ->
            console.log('timeline click')
            # seek to the appropriate place in the timeline
            [x, y] = d3.mouse(this)

            # it's up to seekToX to figure out an appropriate behavior
            timeline.seekToX(x)
        )

        # Connect Knockout.js bindings between the timeline object and the
        # html UI.  This will let us control the play/pause state, etc.
        ko.applyBindings(this, @parentDiv.node())


    loadScene: (@scene) ->

        # clear the internal account of subsegment

        # all subsegments (major divisions) in order
        # these are dictionaries with id, title, duration, and object
        @orderedSubsegments = []

        # a dictionary to lookup seg entries... do we need this?
        @subsegmentLookup = {}

        # a global lookup for info about milestones, which lie one level
        # below the subsegments
        @allMilestones = []
        @milestoneLookup = {}

        # setup each subsegment and the markers/milestones within
        for subsegment in @scene.children

            # Find milestones in the subsegment, if there are any
            if subsegment.findMilestones?
                milestones = subsegment.findMilestones()
            else
                milestones = []

            # We have a bit of a challenge, in that we don't yet know
            # how long some of the subsegments will be -- need to load
            # the video and ask first!
            # Thus, we'll defer that decision and keep re-calling setupTiming
            # every time we get a new bit of info about the lengths
            duration = 0.0
            totalDuration = 0.0

            # some objects will have a duration observable that we can subscribe to (videos)
            # others will have a method we can ask for approx time (interactives)
            if subsegment.duration.subscribe?
                subsegment.duration.subscribe(=> @setupTiming())
            else
                if milestones.length
                    # this is a hack
                    duration = 0
                    totalDuration = subsegment.duration()
                else
                    duration = subsegment.duration()
                    totalDuration = duration


            subsegId = subsegment.elementId

            subsegEntry =
                id: subsegId
                title: subsegId
                duration: duration
                obj: subsegment
                milestones: []

            @orderedSubsegments.push(subsegEntry)
            @subsegmentLookup[subsegId] = subsegEntry

            # collect up milestones so that they can be added to the
            # timeline as well
            if subsegment.findMilestones?
                milestones = subsegment.findMilestones()
                for m in milestones

                    milestoneId = m.elementId

                    # For now, just evenly space the milestones
                    # in the future could possibly query
                    milestoneEntry =
                        id: milestoneId
                        title: m.title
                        duration: totalDuration / milestones.length
                        obj: m
                        parent: subsegment

                    # add this milestone entry to the subsegment entry
                    # it belongs to
                    subsegEntry.milestones.push(milestoneEntry)

                    @allMilestones.push(milestoneEntry)
                    @milestoneLookup[milestoneId] = milestoneEntry

        # by this point, we should have an ordered list of subsegment entries,
        # each containing a duration, title, id and a list of milestones within it
        # Also: a milestone lookup, where we can find out details about a milestone
        # from it's elementId


    # Given the currently loaded scene, translate durations, etc.
    # into a visual timeline
    # This may be called many times in a row, as new info about video
    # duration, etc. is obtained from the network
    setupTiming: ->
        console.log('[timeline]: adjusting timing...')

        subsegmentRunningTime = 0.0

        for subsegEntry in @orderedSubsegments

            # update the duration
            subsegEntry.duration = subsegEntry.obj.duration()

            # this is where it should start on the timeline
            subsegEntry.startTime = subsegmentRunningTime

            subsegmentRunningTime += subsegEntry.duration

            nMilestones = subsegEntry.milestones.length
            milestoneDuration = subsegEntry.duration / nMilestones

            milestoneRunningTime = 0.0

            console.log 'subsegment'
            console.log subsegEntry

            for milestoneEntry in subsegEntry.milestones
                # in theory, this is where we'd update milestone durations from external info
                # milestoneEntry.duration = milestoneEntry.obj.duration() if milestoneEntry.obj.duration?
                milestoneEntry.duration = milestoneDuration

                milestoneEntry.startTime = milestoneRunningTime
                milestoneEntry.absoluteStartTime = milestoneEntry.startTime + subsegEntry.startTime

                milestoneRunningTime += milestoneEntry.duration

                console.log 'milestone:'
                console.log milestoneEntry


        ## This is the previous, slightly insane version
        # for subsegment in @scene.children
        #     segId = subsegment.elementId
        #     console.log('setting up ' + segId)
        #     duration = beat.duration()
        #     @segmentLookup[segId].obj = beat
        #     @segmentLookup[segId].duration = duration
        #     segmentStart = runningTime
        #     @segmentLookup[segId].start = segmentStart
        #     runningTime += duration

        #     if beat.findMilestones?
        #         milestones = beat.findMilestones()
        #         for m, i in milestones
        #             # subSegId = segId + '/' + m.name
        #             subSegId = m.elementId
        #             milestoneDuration = duration / (milestones.length + 1)
        #             @segmentLookup[subSegId].obj = beat
        #             @segmentLookup[subSegId].duration = milestoneDuration
        #             @segmentLookup[subSegId].start = segmentStart + (i+1)*milestoneDuration
        #             @segmentLookup[subSegId].subtarget = m.name

        @totalDuration = subsegmentRunningTime

        console.log('[timeline]: total duration = ' + @totalDuration)

        console.log('[timeline]: drawing timeline...')

        @tScale = d3.scale.linear()
            .domain([0.0, @totalDuration])
            .range([0.0, 100.0])


        @markers = @svg.selectAll('.timeline-subsegment-marker')
                        .data(@orderedSubsegments)
                        # .attr('cx', (d) =>
                        #     console.log('marker at: ' + @tScale(d.startTime))
                        #     @tScale(d.startTime) + '%'
                        # )

        @markers.enter()
                .append('circle')
                .attr('cy', @progressbarCenter)  # vert centering
                .attr('cx', (d) =>
                    console.log('marker at: ' + @tScale(d.startTime))
                    @tScale(d.startTime) + '%'
                )
                .attr('r', @markerSmall)
                .attr('class', 'timeline-subsegment-marker')
                .attr('timelinetooltip', (d) -> d.title)

        @markers.exit().remove()

        # Marker mouseover effects

        ms = @markerSmall
        ml = @markerLarge

        # this one makes you bigger
        @markers.on('mouseover', (d) ->
            d3.select(this).transition()
                .attr('r', ml)
                .duration(250)
        )

        # this one makes you smaller
        @markers.on('mouseout', (d) ->
            d3.select(this).transition()
                .attr('r', ms)
                .duration(250)
        )

        console.log('[timeline]: installing click handlers...')

        # Marker click action -- SEEK!
        @markers.on('click', (d) =>
            console.log('marker click: ' + d.title)
            @sceneController.seek(d.obj, 0)
            d3.event.stopPropagation()
            )

        console.log('Installing tooltips...')

        $('.timeline-segment-marker').tipsy(
            #gravity: $.fn.tipsy.autoNS
            gravity:'sw'
            title: ->
                d3.select(this).attr('timelinetooltip')
        )


        # Milestone Markers

        @milestoneMarkers = @svg.selectAll('.timeline-milestone-marker')
                .data(@allMilestones)
                # .attr('cx', (d) =>
                #     console.log d
                #     console.log('subseg marker at: ' + @tScale(d.start))
                #     @tScale(d.start) + '%'
                # )

        @milestoneMarkers.enter()
                .append('circle')
                .attr('cy', @progressbarCenter)
                .attr('cx', (d) =>
                    console.log d
                    console.log('milestone marker at: ' + @tScale(d.absoluteStartTime))
                    @tScale(d.absoluteStartTime) + '%'
                )
                .attr('r', @markerSmall)
                .attr('class', 'timeline-milestone-marker')
                .attr('timelinetooltip', (d) -> d.title)

        @milestoneMarkers.exit().remove()

        # Marker mouseover effects

        # embiggen
        @milestoneMarkers.on('mouseover', (d) ->
            d3.select(this).transition()
                .attr('r', ml)
                .duration(250)
        )

        # shrinkify
        @milestoneMarkers.on('mouseout', (d) ->
            d3.select(this).transition()
                .attr('r', ms)
                .duration(250)
        )


        # Marker click action
        @milestoneMarkers.on('click', (d) =>

            obj = d.obj # @segmentLookup[d.segId].obj
            if d.parent?
                t = d.name
            else
                # something is wrong... just bail. Better to do nothing here.
                return
            @sceneController.seek(obj, t)
            d3.event.stopPropagation()
        )


        # tooltips on subsegment markers
        #
        $('.timeline-milestone-marker').tipsy(
            #gravity: $.fn.tipsy.autoNS
            gravity:'sw'
            title: ->
                d3.select(this).attr('timelinetooltip')
        )


        console.log('Done setting up timeline.')


    setupSceneIndicator: ->

        # setup scene display
        nscenes = @sceneController.sceneList.length

        @sceneMarkers = []

        @sceneBlockWidth = .02
        @sceneBlockHeight = 1.0
        @sceneBlockSpacing = .005
        @sceneBlockLineHeight = 0.2

        # connector line
        @sceneIndicatorSVG.append('rect')
            .attr('width', 100 * (nscenes*@sceneBlockWidth + (nscenes-1)*@sceneBlockSpacing) + '%')
            .attr('height', 100 * @sceneBlockLineHeight + '%')
            .attr('y', (0.5 - @sceneBlockLineHeight/2.0) * 100 + '%')
            .attr('x', '0%')
            .attr('class', 'scene-indicator-inactive')

        for s in [0..nscenes-1]
            m = @sceneIndicatorSVG.append('rect')
                .attr('width', @sceneBlockWidth * 100 + '%')
                .attr('height', @sceneBlockHeight * 100 + '%')
                .attr('y', '0%')
                .attr('x', s * (@sceneBlockWidth + @sceneBlockSpacing) * 100 + '%')
                .attr('class', 'scene-indicator-inactive')
            @sceneMarkers[s] = m
            do (m, s) =>
                m.on('click', =>
                    # @sceneController.selectScene(s)
                    # hack this to work differently
                    window.location.href = '/course/' + [module_id, lesson_id, @sceneController.sceneList[s].name].join('/')
                )

                title = @sceneController.sceneList[s].title

                $(m.node()).tipsy(
                    #gravity: $.fn.tipsy.autoNS
                    gravity:'sw'
                    title: -> title
                )


    updateSceneIndicator: (currentScene) ->

        for m in @sceneMarkers
            m.attr('class', 'scene-indicator-inactive')

        @sceneMarkers[currentScene].attr('class', 'scene-indicator-active')



    # Update the current timeline display
    # This event gets fired whenever the current element or time changes
    update: (subsegment, t) ->
        if not subsegment?
            console.log('[timeline]: warning: empty segment in timeline')
            return

        if isNaN(t)
            t = undefined

        segId = subsegment.elementId

        timelineSegment = @subsegmentLookup[segId]

        if not timelineSegment?
            console.log 'segment lookup failed: '
            console.log subsegment
            console.log segId
            console.log @segmentLookup

            @currentTime = undefined
            return
        else
            @displayedSegment = timelineSegment


        if not @tScale?
            console.log('[timeline]: no time scale defined')
            return

        @currentTime = t

        if not @displayedSegment?
            console.log('warning: no segment to display')
            return

        if not @currentTime?
            # this is an interactive?
            progressWidth = @tScale(@displayedSegment.startTime)
            activebarWidth = @tScale(@displayedSegment.duration)
            @progressbar.attr('width', progressWidth + '%')
            @activebar.attr('x', progressWidth + '%')
            @activebar.attr('width', activebarWidth + '%')
            console.log 'setting activebar width: ' + activebarWidth + '%'
        else
            # this is a video
            newWidth = @tScale(@displayedSegment.startTime + @currentTime)
            @progressbar.attr('width', newWidth + '%')
            @activebar.attr('x', '0%')
            @activebar.attr('width', '0%')

    seekToX: (x) ->

        if not @tScale?
            console.log('[timeline]: no time scale defined')
            return

        svgWidth = @svg.node().getBBox().width
        console.log(svgWidth)
        t = @tScale.invert(100 * (x / svgWidth))

        thisSeg = undefined
        for s in @orderedSegments
            if s.startTime > t
                break

            if s.startTime < t
                thisSeg = s

        if not thisSeg?
            console.log('[timeline]: no sensible segment to match')

        relT = t - thisSeg.start
        console.log('[timeline]: seeking to ' + thisSeg.segId + ':' + relT)

        # if this segment has a list of seekables, then we should seek to one
        # of them.
        if thisSeg.seekables?
            thisSeekable = undefined
            for s in thisSeg.seekables
                if s.startTime > relT
                    break

                if s.startTime < t
                    thisSeekable = s

            relT = thisSeekable.id


        @update(thisSeg, relT)
        @sceneController.seek(thisSeg.obj, relT)

    play: ->
        console.log('[timeline]: play')
        # @playing(true)
        # @paused(false)
        @sceneController.resume()

    pause: ->
        console.log('[timeline]: pause')
        # @playing(false)
        # @paused(true)
        @sceneController.pause()





