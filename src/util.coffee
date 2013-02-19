
resizeHandlers = []

$(window).resize( ->
    f() for f in resizeHandlers
)


util =

    dimLights: (v) ->
        veil = $('#veil')
        if v
            console.log('showing veil')
            veil.show()
        else
            console.log('hiding veil')
            veil.hide()

    hideElement: (el, duration) ->
        if duration is undefined
            el.attr('opacity', 0.0)
            el.attr('display', 'none')
        else
            el.transition()
              .attr('opacity', 0.0)
              .duration(duration)
              .each('end', -> el.attr('display', 'none'))

    showElement: (el, duration) ->
        el.attr('opacity', 0.0)
        el.attr('visibility', 'visible')
        el.attr('display', 'inline')
        console.log('el: ' + el)
        console.log('display: ' + el.attr('display'))
        if duration is undefined
            el.attr('opacity', 1.0)
        else
            el.transition().attr('opacity', 1.0).duration(duration)

    # Float a div element over top of an SVG rect element
    floatOverRect: (svgSelector, rectSelector, divSelector) ->

        svg = d3.select(svgSelector).node()
        rect = d3.select(rectSelector).node()
        div = d3.select(divSelector)
        div.style('position', 'absolute')

        d3.select(rectSelector).attr('opacity', 0.0)

        # trick from http://stackoverflow.com/questions/5834298/getting-the-screen-pixel-coordinates-of-a-rect-element
        pt  = svg.createSVGPoint()
        resizeIt = () ->
            corners = {}
            matrix  = rect.getScreenCTM()
            pt.x = rect.x.animVal.value
            pt.y = rect.y.animVal.value
            corners.nw = pt.matrixTransform(matrix)
            pt.x += rect.width.animVal.value
            corners.ne = pt.matrixTransform(matrix)
            pt.y += rect.height.animVal.value
            corners.se = pt.matrixTransform(matrix)
            pt.x -= rect.width.animVal.value
            corners.sw = pt.matrixTransform(matrix)

            div.style('width', corners.ne.x - corners.nw.x)
            div.style('height', corners.se.y - corners.ne.y)
            div.style('top', corners.nw.y)
            div.style('left', corners.nw.x)


        resizeHandlers.push(resizeIt)
        f() for f in resizeHandlers


root = window ? exports
root.util = util