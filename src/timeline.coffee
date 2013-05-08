

class mcb80x.Timeline

    constructor: (selector, @sceneController) ->

        @paused = ko.observable(false)
        @playing = ko.observable(true)
        @self = ko.observable(this)

        @parentDiv = d3.select(selector)
        @markers = undefined


        @markerSmall = '5'
        @markerLarge = '7'

        @progressbarTop = '30%'
        @progressbarHeight = '35%'
        @progressbarCenter = '50%'


        @div = @parentDiv.select('#timeline')

        @svg = @div.append('svg').attr('id', 'timeline-svg')

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
                .attr('xlink:href', 'images/stripes.png')

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

        # Show / Hide the timeline on mmouseover
        # @parentDiv.on('mouseover', ->
        #     d3.select(this).transition()
        #         .style('opacity', 1.0)
        #         .duration(250)
        # )

        # @parentDiv.on('mouseout', ->
        #     d3.select(this).transition()
        #         .style('opacity', 0.0)
        #         .duration(250)
        # )

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

        @displayedSegment = undefined

        @orderedSegments = []
        @segmentLookup = {}

        for beat in @scene.children
            console.log(beat)

            duration = 1.0
            if beat.duration.subscribe?
                beat.duration.subscribe(=> @setupTiming())
            else
                duration = beat.duration()

            segId = beat.elementId

            segment =
                segId: segId
                title: segId
                duration: duration

            console.log(segment)
            @orderedSegments.push(segment)
            @segmentLookup[segId] = segment

    setupTiming: ->
        console.log('[timeline]: adjusting timing...')
        runningTime = 0.0
        for beat in @scene.children
            segId = beat.elementId
            console.log('setting up ' + segId)
            duration = beat.duration()
            @segmentLookup[segId].obj = beat
            @segmentLookup[segId].duration = duration
            @segmentLookup[segId].start = runningTime
            runningTime += duration

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



    updateSceneIndicator: (currentScene) ->

        for m in @sceneMarkers
            m.attr('class', 'scene-indicator-inactive')

        @sceneMarkers[currentScene].attr('class', 'scene-indicator-active')



    # Update the current timeline display
    update: (segment, t) ->
        console.log('[timeline]: updating timeline')
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





