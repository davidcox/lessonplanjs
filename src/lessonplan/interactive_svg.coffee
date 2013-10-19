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

        @init()

        cb() if cb?

    play: () ->

    stop: () ->

    init: () ->

    showElement: (s) ->
        util.showElement(@svg.select(s), 250)

    hideElement: (s) ->
        util.hideElement(@svg.select(s), 250)

    glowElement: (s) ->
        console.log 'Glowing ' + s
        @svg.select(s).classed('glowing', true)

    unglowElement: (s) ->
        @svg.select(s).classed('glowing', false)

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


