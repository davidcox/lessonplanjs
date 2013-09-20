# An object controlling the appearance and UI on the unified
# video / interactive / etc. timeline
#

class lessonplan.Timeline

    constructor: (selector, @sceneController) ->

        # Player state bindings
        @paused = ko.observable(false)
        @playing = ko.observable(true)
        @self = ko.observable(this)


        # Look and Feel parameters
        @markerSmall = '5'
        @markerLarge = '7'

        @progressbarTop = '30%'
        @progressbarHeight = '35%'
        @progressbarCenter = '50%'

        # Visual elements
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

        @sceneController.currentTime.subscribe( (v) =>
            @update(@sceneController.currentElement, v)
        )

        @sceneController.currentSegment.subscribe( (v) =>
            @update(@sceneController.currentElement, @sceneController.currentTime)
        )


        @sceneController.currentScene.subscribe( (v) =>
            @loadScene(v)
            @setupTiming()
            @setupSceneIndicator()
        )

        @sceneController.currentSceneIndex.subscribe( (v) =>
            @updateSceneIndicator(v)
        )


        timeline = this
        @svg.on('click', ->
            console.log('timeline click')
            # seek to the appropriate place in the timeline
            [x, y] = d3.mouse(this)
            timeline.seekToX(x)
        )


        # Connect Knockout.js bindings between the timeline object and the
        # html UI.  This will let us control the play/pause state, etc.
        ko.applyBindings(this, @parentDiv.node())


    loadScene: (@scene) ->

        @orderedSegments = []
        @segmentLookup = {}

        @subsegments = []

        @displayedSegment = undefined


        for beat in @scene.children
            console.log(beat)

            console.log beat.findMilestones
            if beat.findMilestones?
                milestones = beat.findMilestones()
                console.log '============= MILESTONES =================='
                console.log milestones
            else
                milestones = []

            duration = 0.0
            totalDuration = 0.0
            if beat.duration.subscribe?
                beat.duration.subscribe(=> @setupTiming())
            else
                if milestones.length
                    duration = 0
                    totalDuration = beat.duration()
                else
                    duration = beat.duration()
                    totalDuration = duration


            segId = beat.elementId

            segment =
                segId: segId
                title: segId
                duration: duration

            console.log(segment)
            @orderedSegments.push(segment)
            @segmentLookup[segId] = segment


            # collect up milestones so that they can be added to the
            # timeline as well
            if beat.findMilestones?
                milestones = beat.findMilestones()
                for m in milestones
                    # subSegId = segId + '/' + m.name
                    subSegId = m.elementId
                    subsegment =
                        segId: subSegId
                        title: ''
                        duration: totalDuration / milestones.length

                    @subsegments.push(subsegment)
                    @segmentLookup[subSegId] = subsegment


    setupTiming: ->
        console.log('[timeline]: adjusting timing...')
        runningTime = 0.0
        for beat in @scene.children
            segId = beat.elementId
            console.log('setting up ' + segId)
            duration = beat.duration()
            @segmentLookup[segId].obj = beat
            @segmentLookup[segId].duration = duration
            segmentStart = runningTime
            @segmentLookup[segId].start = segmentStart
            runningTime += duration

            if beat.findMilestones?
                milestones = beat.findMilestones()
                for m, i in milestones
                    # subSegId = segId + '/' + m.name
                    subSegId = m.elementId
                    milestoneDuration = duration / (milestones.length + 1)
                    @segmentLookup[subSegId].obj = beat
                    @segmentLookup[subSegId].duration = milestoneDuration
                    @segmentLookup[subSegId].start = segmentStart + (i+1)*milestoneDuration
                    @segmentLookup[subSegId].subtarget = m.name

        @totalDuration = runningTime

        console.log('[timeline]: total duration = ' + @totalDuration)


        console.log('[timeline]: drawing timeline...')

        @tScale = d3.scale.linear()
            .domain([0.0, @totalDuration])
            .range([0.0, 100.0])


        @markers = @svg.selectAll('.timeline-segment-marker')
                        .data(@orderedSegments)
                        .attr('cx', (d) =>
                            console.log('marker at: ' + @tScale(d.start))
                            @tScale(d.start) + '%'
                        )

        @markers.enter()
                .append('circle')
                .attr('cy', @progressbarCenter)
                .attr('cx', (d) =>
                    console.log('marker at: ' + @tScale(d.start))
                    @tScale(d.start) + '%'
                )
                .attr('r', @markerSmall)
                .attr('class', 'timeline-segment-marker')
                .attr('timelinetooltip', (d) -> d.title)

        @markers.exit().remove()

        # Marker mouseover effects
        console.log('[timeline]: installing mouseovers...')

        ms = @markerSmall
        ml = @markerLarge
        @markers.on('mouseover', (d) ->
            d3.select(this).transition()
                .attr('r', ml)
                .duration(250)
        )
        @markers.on('mouseout', (d) ->
            d3.select(this).transition()
                .attr('r', ms)
                .duration(250)
        )

        console.log('[timeline]: installing click handlers...')

        # Marker click action
        @markers.on('click', (d) =>
            console.log('marker click: ' + d.title)
            obj = @segmentLookup[d.title].obj
            @sceneController.seek(obj, 0)
            d3.event.stopPropagation()
            )

        console.log('Installing tooltips...')

        $('.timeline-segment-marker').tipsy(
            #gravity: $.fn.tipsy.autoNS
            gravity:'sw'
            title: ->
                d3.select(this).attr('timelinetooltip')
        )


        # Subsegment Markers
        console.log ')))))))))))'
        console.log @subsegments
        console.log @submarkers

        @submarkers = @svg.selectAll('.timeline-subsegment-marker')
                .data(@subsegments)
                .attr('cx', (d) =>
                    console.log d
                    console.log('subseg marker at: ' + @tScale(d.start))
                    @tScale(d.start) + '%'
                )

        @submarkers.enter()
                .append('circle')
                .attr('cy', @progressbarCenter)
                .attr('cx', (d) =>
                    console.log d
                    console.log('subseg marker at: ' + @tScale(d.start))
                    @tScale(d.start) + '%'
                )
                .attr('r', @markerSmall)
                .attr('class', 'timeline-subsegment-marker')
                .attr('timelinetooltip', (d) -> d.title)

        @submarkers.exit().remove()

        # Marker mouseover effects
        console.log('[timeline]: installing mouseovers...')

        @submarkers.on('mouseover', (d) ->
            d3.select(this).transition()
                .attr('r', ml)
                .duration(250)
        )
        @submarkers.on('mouseout', (d) ->
            d3.select(this).transition()
                .attr('r', ms)
                .duration(250)
        )

        console.log('[timeline]: installing click handlers...')

        # Marker click action
        @submarkers.on('click', (d) =>

            console.log('marker click: ' + d.obj + ', to target: ' + d.subtarget)
            obj = d.obj # @segmentLookup[d.segId].obj
            if d.subtarget?
                t = d.subtarget
            else
                t = 0
            @sceneController.seek(obj, t)
            d3.event.stopPropagation()
            )


        # No tooltips on subsegment markers yet
        #
        # $('.timeline-subsegment-marker').tipsy(
        #     #gravity: $.fn.tipsy.autoNS
        #     gravity:'sw'
        #     title: ->
        #         d3.select(this).attr('timelinetooltip')
        # )


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
                    @sceneController.selectScene(s)
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
    update: (segment, t) ->
        # console.log('[timeline]: updating timeline')
        if not segment?
            console.log('[timeline]: warning: empty segment in timeline')
            return

        if isNaN(t)
            t = undefined

        segId = segment.elementId

        timelineSegment = @segmentLookup[segId]

        if not @tScale?
            console.log('[timeline]: no time scale defined')
            return

        @currentTime = t

        if not timelineSegment?
            @currentTime = undefined
        else
            @displayedSegment = timelineSegment


        if not @displayedSegment?
            console.log('warning: no segment to display')
            return

        if not @currentTime?
            progressWidth = @tScale(@displayedSegment.start)
            activebarWidth = @tScale(@displayedSegment.duration)
            @progressbar.attr('width', progressWidth + '%')
            @activebar.attr('x', progressWidth + '%')
            @activebar.attr('width', activebarWidth + '%')
        else
            newWidth = @tScale(@displayedSegment.start + @currentTime)
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
            if s.start > t
                break

            if s.start < t
                thisSeg = s

        if not thisSeg?
            console.log('[timeline]: no sensible segment to match')

        relT = t - thisSeg.start
        console.log('[timeline]: seeking to ' + thisSeg.segId + ':' + relT)

        @update(thisSeg.segId, relT)
        @sceneController.seek(thisSeg.obj, relT)

    play: ->
        console.log('[timeline]: play')
        @playing(true)
        @paused(false)
        @sceneController.resume()

    pause: ->
        console.log('[timeline]: pause')
        @playing(false)
        @paused(true)
        @sceneController.pause()





