

class common.Timeline

    constructor: (selector, @scene) ->
        @orderedSegments = []
        @segmentLookup = {}

        @div = d3.select(selector)

        @scene.currentTime.subscribe( (v) =>
            @update(@scene.currentSegment(), v)
        )

        @svg = @div.append('svg').attr('id', 'timeline-svg')

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


        # Show / Hide the timline on mmouseover
        @div.on('mouseover', ->
            d3.select(this).transition()
                .style('opacity', 1.0)
                .duration(250)
        )

        @div.on('mouseout', ->
            d3.select(this).transition()
                .style('opacity', 0.0)
                .duration(250)
        )

    setupTiming: ->

        runningTime = 0.0
        for beat in @scene.children
            segId = beat.elementId
            duration = beat.duration()
            @segmentLookup[segId].duration = duration
            @segmentLookup[segId].start = runningTime
            runningTime += duration

        @totalDuration = runningTime

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

        $('.timeline-segment-marker').tipsy(
            #gravity: $.fn.tipsy.autoNS
            gravity:'sw'
            title: ->
                console.log(this)
                d3.select(this).attr('timelinetooltip')
        )

    update: (segId, t) ->
        if not @tScale?
            return

        console.log(segId)
        @currentTime = t
        newWidth = @tScale(@segmentLookup[segId].start + @currentTime)
        # console.log(newWidth)
        @progressbar.attr('width', newWidth + '%')





