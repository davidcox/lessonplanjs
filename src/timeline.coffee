

class mcb80x.Timeline

    constructor: (selector, @sceneController) ->

        @scene = @sceneController.scene

        @paused = ko.observable(false)
        @playing = ko.observable(true)
        @self = ko.observable(this)

        @orderedSegments = []
        @segmentLookup = {}

        @displayedSegment = undefined

        @parentDiv = d3.select(selector)

        console.log('parentdiv = ' + @parentDiv)

        @div = @parentDiv.select('#timeline')

        @scene.currentTime.subscribe( (v) =>
            @update(@sceneController.currentElement, v)
        )

        @svg = @div.append('svg').attr('id', 'timeline-svg')
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


        @bgRect = @svg.append('rect')
            .attr('width', '100%')
            .attr('height', '100%')
            .attr('class', 'timeline-background-rect')

        @progressbar = @svg.append('rect')
            .attr('width', 0.0)
            .attr('height', '30%')
            .attr('x', '0')
            .attr('y', '35%')
            .attr('class', 'timeline-progressbar')

        @activebar = @svg.append('rect')
            .attr('width', 0.0)
            .attr('height', '30%')
            .attr('x', '0')
            .attr('y', '35%')
            .attr('class', 'timeline-activebar')
            .attr('fill', 'url(#patstripes)')
            # .attr('fill', '#666')

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

        @currentTime = 0.0

        @setupTiming()


        # Show / Hide the timeline on mmouseover
        @parentDiv.on('mouseover', ->
            d3.select(this).transition()
                .style('opacity', 1.0)
                .duration(250)
        )

        @parentDiv.on('mouseout', ->
            d3.select(this).transition()
                .style('opacity', 0.0)
                .duration(250)
        )

        controller = this
        @svg.on('click', ->
            # seek to the appropriate place in the timeline
            [x, y] = d3.mouse(this)
            controller.seek(x)
        )


        # Connect Knockout.js bindings between the timeline object and the
        # html UI.  This will let us control the play/pause state, etc.
        ko.applyBindings(this, @parentDiv.node())

    setupTiming: ->
        console.log('adjusting timeline timing...')
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

        console.log('total duration = ' + @totalDuration)


        console.log('Drawing timeline...')

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
                .attr('cy', '50%')
                .attr('cx', (d) =>
                    console.log('marker at: ' + @tScale(d.start))
                    @tScale(d.start) + '%'
                )
                .attr('r', 5)
                .attr('class', 'timeline-segment-marker')
                .attr('timelinetooltip', (d) -> d.title)

        # Marker mouseover effects
        console.log('Installing mouseovers...')

        @markers.on('mouseover', (d) ->
            d3.select(this).transition()
                .attr('r', 7)
                .duration(250)
        )
        @markers.on('mouseout', (d) ->
            d3.select(this).transition()
                .attr('r', 5)
                .duration(250)
        )

        console.log('Installing click handlers...')

        # Marker click action
        @markers.on('click', (d) =>
            obj = @segmentLookup[d.title].obj
            @sceneController.runAtSegment(obj))

        console.log('Installing tooltips...')

        $('.timeline-segment-marker').tipsy(
            #gravity: $.fn.tipsy.autoNS
            gravity:'sw'
            title: ->
                d3.select(this).attr('timelinetooltip')
        )

        console.log('Done setting up timeline.')

    update: (segment, t) ->
        console.log('updating timeline')
        if not segment?
            console.log('Warning: empty segment in timeline')
            return

        segId = segment.elementId

        timelineSegment = @segmentLookup[segId]

        if not @tScale?
            console.log('No time scale defined')
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

    seek: (x) ->
        console.log('x: ' + x)

        if not @tScale?
            console.log('No time scale defined')

            return

        svgWidth = @svg.node().getBBox().width
        console.log(svgWidth)
        t = @tScale.invert(100 * (x / svgWidth))

        console.log('t: ' + t)

        thisSeg = undefined
        for s in @orderedSegments
            if s.start > t
                break

            if s.start < t
                thisSeg = s

        if not thisSeg?
            console.log('No sensible segment to match')

        relT = t - thisSeg.start
        console.log('Seeking to ' + thisSeg.segId + ':' + relT)

        @update(thisSeg.segId, relT)
        @sceneController.runAtSegment(thisSeg.obj, relT)

    play: ->
        console.log('play')
        @playing(true)
        @paused(false)
        @sceneController.resume()

    pause: ->
        console.log('pause')
        @playing(false)
        @paused(true)
        @sceneController.pause()





