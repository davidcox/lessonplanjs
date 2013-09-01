#<< lessonplan/properties
#<< lessonplan/util

class lessonplan.InteractiveSVG extends lessonplan.ViewModel

    constructor: (@svgFileName) ->


    # Main initialization function; triggered after the SVG doc is
    # loaded
    svgDocumentReady: (xml, cb) ->

        # Attach the SVG to the DOM in the appropriate place
        importedNode = document.importNode(xml.documentElement, true)

        # hollow out the 'interactive' node to remove anything there previously
        $('#interactive').empty()

        d3.select('#interactive').node().appendChild(importedNode)
        d3.select('#interactive').transition().style('opacity', 1.0).duration(1000)

        @svg = d3.select(importedNode)
        @svg.attr('width', '100%')
        @svg.attr('height', '100%')

        @init()

        cb() if cb?

    play: () ->

    stop: () ->

    init: () ->

    showElement: (s) ->
        console.log('showing ' + s)
        util.showElement(@svg.select(s), 250)

    hideElement: (s) ->
        console.log('hiding ' + s)
        util.hideElement(@svg.select(s), 250)

    show: ->
        console.log('showing interactive: ' + @svgFileName)

        # raise the house lights
        util.showBackdrop(false)

        # Hide the video
        # TODO: necessary?
        $('#video').css('opacity', 0.0)


        dfrd = $.Deferred()
        util.indicateLoading(true)

        # d3.xml(@svgFileName, 'image/svg+xml', (xml) => @svgDocumentReady(xml, cb1))
        $.ajax(
            url: @svgFileName
            dataType: 'xml'
        ).success((xml) =>
            @svgDocumentReady(xml)
            d3.select('#interactive').style('display', 'inline')
                .transition()
                .style('opacity', 1.0)
                .duration(1000)
                .each(->
                    # console.log('finished loading interactive onto stage')
                    util.indicateLoading(false)
                    dfrd.resolve()
                )
        ).fail( ->
            alert('SVG would not load: ' + @svgFileName)
        )

        return dfrd


    hide: ->
        dfrd = $.Deferred()

        @runSimulation = false
        d3.select('#interactive').transition()
            .style('opacity', 0.0)
            .duration(1000)
            .each('end', ->
                d3.select('#interactive').style('display', 'none')
                dfrd.resolve()
            )

        $('#interactive').empty()

        return dfrd

    reset: ->
        @hide()

