#<< lessonplan/properties
#<< lessonplan/util

window.interactiveSVGCounter = 0

class lessonplan.InteractiveSVG extends lessonplan.ViewModel

    constructor: (@svgFileName) ->
        super()

        @svg = undefined
        @svgId = 'svg' + interactiveSVGCounter
        interactiveSVGCounter += 1

        @svgDiv = undefined


    # Main initialization function; triggered after the SVG doc is
    # loaded
    svgDocumentReady: (xml, cb) ->

        # Attach the SVG to the DOM in the appropriate place
        importedNode = document.importNode(xml.documentElement, true)


        # hollow out the 'interactive' node to remove anything there previously
        # $('#interactive').empty()
        if not @svgDiv?
            @svgDiv = d3.select('#interactive').append('div').attr('id', @svgId)

        $(@svgDiv.node()).empty()

        @svgDiv.node().appendChild(importedNode)

        # d3.select('#interactive').transition().style('opacity', 1.0).duration(1000)

        @svg = d3.select(importedNode)
        @svg.attr('width', '100%')
        @svg.attr('height', '100%')

        @svgDiv.style('display', 'none')
        @svgDiv.style('opacity', 0.0)
        @svgDiv.style('position', 'absolute')
        @svgDiv.style('width', '100%')
        @svgDiv.style('height', '100%')

        stdDeviation = 5
        colorMatrix = '0 0 0 1.0 0 0 0 0 0 0.2 0 0 0 0 0.2 0 0 0 1 0'

        defs = @svg.append('defs')

        filter = defs.append('filter')
            .attr('id', 'glow')
            .attr('x', '-20%')
            .attr('y', '-20%')
            .attr('width', '140%')
            .attr('height', '140%')
            .call(->
                this.append('feColorMatrix')
                    .attr('type', 'matrix')
                    .attr('values', colorMatrix)
                this.append('feGaussianBlur')
                    .attr('stdDeviation', stdDeviation)
                    .attr('result', 'coloredBlur')
            )

        filter.append('feMerge')
            .call(->
                this.append('feMergeNode')
                    .attr('in', 'coloredBlur')
                this.append('feMergeNode')
                    .attr('in', 'SourceGraphic')
            )


        @init()

        cb() if cb?

    play: () ->

    stop: () ->

    init: () ->

    showElement: (s) ->
        try
            util.showSVGElement(@svg.select(s), 250)
        catch error
            console.log 'Could not show SVG element ' + s

    hideElement: (s) ->
        try
            util.hideSVGElement(@svg.select(s), 250)
        catch error
            console.log 'Could not hide SVG element ' + s

    hideAllElements: (s) ->
        console.log 'hiding all elements'
        svgNode = @svg.node()
        window.svgNode = svgNode

        children = @svg.node().children
        if not children?
            children = @svg.node().childNodes

        console.log children

        util.hideSVGElement(d3.select(child)) for child in children


    transitionGroups: (gsel1, gsel2, duration) ->

        console.log '[ transitioning ' + gsel1 + ' to ' + gsel2 + ' ]'
        g1 = @svg.select('#' + gsel1)
        g2 = @svg.select('#' + gsel2)

        if not g1?
            console.log 'ERROR: bad transitionGroup:'
            console.log 'Invalid selector: ' + gsel1
            return

        if not g2?
            console.log 'ERROR: bad transitionGroup:'
            console.log 'Invalid selector: ' + gsel2
            return

        return util.transitionGroups(g1, g2, duration)

    glowElement: (s) ->
        console.log 'Glowing ' + s
        # @svg.select(s).classed('glowing', true)
        @svg.select(s).style('filter', 'url(#glow)')

        # HACK
        glowFilter = @svg.select('filter#glow')
        glowFilter.attr('id', 'glow1')
        glowFilter.attr('id', 'glow')

    unglowElement: (s) ->
        # @svg.select(s).classed('glowing', false)
        @svg.select(s).style('filter', '')


    boxAroundElement: (s, color) ->
        el = @svg.select(s)

        try
            r = el.node().getBBox()
        catch error
            r = el.node().getBoundingClientRect()


        if el.parent?
            p = el.parent
        else
            p = @svg

        margin = 5

        p.append('rect').attr('x', r.x - margin)
                           .attr('y', r.y - margin)
                           .attr('width', r.width + 2*margin)
                           .attr('height', r.height + 2*margin)
                           .style('fill', 'none')
                           .style('stroke-width', 2)
                           .style('stroke', color)
                           .attr('id', s[1..] + '-highlight-box')

    unboxElement: (s) ->
        @svg.select(s + '-highlight-box').remove()


    xHighlightElement: (s) ->
        el = @svg.select(s)

        try
            r = el.node().getBBox()
        catch error
            r = el.node().getBoundingClientRect()


        if el.parent?
            p = el.parent
        else
            p = @svg

        margin = 5

        p.append('text').attr('x', Math.abs(r.x + r.width/2.0)-15)
                        .attr('y', Math.abs(r.y + r.height/2.0)+18)
                        .style('font-family', 'Lato, sans-serif')
                        .style('font-size', '40px')
                        .style('font-weight','700')
                        .attr('fill', '#a00')
                           # .attr('width', r.width + 2*margin)
                           # .attr('height', r.height + 2*margin)
                           # .style('fill', 'none')
                           # .style('stroke-width', 2)
                           # .style('stroke', color)
                        .attr('id', s[1..] + '-highlight-x')
                        .text('X')

    xUnhighlightElement: (s) ->
        console.log 'removing: ' + s + '-highlight-x'
        @svg.select(s + '-highlight-x').remove()


    # Reveal the interactive SVG, loading as needed
    show: ->

        dfrd = $.Deferred()

        # raise the house lights
        util.showBackdrop(false)

        # @svg should exist if the doc is loaded; otherwise
        # load the svg
        if not @svg?
            loaded = @loadSvg()
        else
            loaded = true

        $.when(loaded)
         .then(=>
            @svgDiv.style('display', 'inline')
                .transition()
                .style('opacity', 1.0)
                .duration(1000)
                .each(->
                    dfrd.resolve()
                )
        )

        return dfrd


    loadSvg: ->

        dfrd = $.Deferred()
        # util.indicateLoading(true)

        # d3.xml(@svgFileName, 'image/svg+xml', (xml) => @svgDocumentReady(xml, cb1))
        $.ajax(
            url: @svgFileName
            dataType: 'xml'
        ).success((xml) =>
            @svgDocumentReady(xml, ->
                dfrd.resolve()
            )
        ).fail( =>
            alert('SVG would not load: ' + @svgFileName)
        )

        return dfrd


    hide: ->

        dfrd = $.Deferred()

        @runSimulation = false
        if @svgDiv?
            @svgDiv.transition()
                .style('opacity', 0.0)
                .duration(1000)
                .each('end', =>
                    @svgDiv.style('display', 'none')
                    dfrd.resolve()
                )
        else
            dfrd.resolve()

        # $('#interactive').empty()

        return dfrd

    reset: ->

        dfrd = $.Deferred()
        $.when(@loadSvg()).then(=>
            return @hide()
        ).then(=>
            dfrd.resolve()
        )

        return dfrd


    attr: (n, v) ->
        this[n] = v
