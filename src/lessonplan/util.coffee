# Assorted utilities that didn't obviously
# belong anywhere else.

resizeHandlers = []


util =

    showBackdrop: (flag) ->
        if flag
            $('.backdrop').css('opacity', 1.0)
        else
            $('.backdrop').css('opacity', 0.0)

    showTitleBanner: (title, duration) ->

        $('.lower-third-title').text(title)

        # show it
        $('#title-banner').show('slide', direction: 'down')

        # schedule hiding
        hideit = ->
            $('#title-banner').hide('slide', direction: 'down')

        setTimeout(hideit, duration)


    bringToFront: (selector) ->
        console.log 'bringToFront'
        console.log selector
        $(selector).css('z-index', 100)
        $(selector).siblings().css('z-index', 50)

    indicateLoading: (v, duration) ->
        if not duration?
            duration = 1000

        veil = $('#loading-indicator')

        dfrd = $.Deferred()
        resolve = ->
            if not v
                veil.css('display', 'none')
            dfrd.resolve()

        if v
            console.log('showing veil')
            veil.css('display', 'inline')
            veil.fadeIn(duration, resolve)
        else
            console.log('hiding veil')
            veil.fadeOut(duration, resolve)

        return dfrd

    indicateLoadFail: (v, duration) ->
        if not duration?
            duration = 1000

        veil = $('#load-fail-indicator')

        dfrd = $.Deferred()
        resolve = ->
            if not v
                veil.css('display', 'none')
            dfrd.resolve()

        if v
            veil.css('display', 'inline')
            veil.fadeIn(duration, resolve)
        else
            veil.fadeOut(duration, resolve)

        return dfrd

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
        # el.attr('opacity', 0.0)
        el.attr('visibility', 'visible')
        el.attr('display', 'inline')
        if duration is undefined
            el.attr('opacity', 1.0)
        else
            el.transition().attr('opacity', 1.0).duration(duration)

    transitionGroups: (gsel1, gsel2, duration) ->
        console.log gsel1
        console.log gsel2
        g1 = d3.select('#' + gsel1)
        g2 = d3.select('#' + gsel2)

        root.g1 = g1
        g1Children = [d3.select(node) for node in g1[0][0].childNodes when node.nodeType != 3][0]
        g2Children = [d3.select(node) for node in g2[0][0].childNodes when node.nodeType != 3][0]

        root.g1Children = g1Children

        g1ChildIds = ['#' + el.attr('id') for el in g1Children when (el? and el.attr?)][0]
        g2ChildIds = ['#' + el.attr('id') for el in g2Children when (el? and el.attr?)][0]

        g1ChildIdStems = [elId.split('-')[0] for elId in g1ChildIds][0]
        g2ChildIdStems = [elId.split('-')[0] for elId in g2ChildIds][0]

        console.log g2ChildIdStems

        for childId, i in g1ChildIdStems
            console.log 'Child ID: '
            g1Child = d3.select(g1ChildIds[i])
            console.log childId
            if childId in g2ChildIdStems
                g2ChildId = g2ChildIds[g2ChildIdStems.indexOf(childId)]
                g2Child = d3.select(g2ChildId)

                console.log 'move ' + childId
                console.log g2Child.attr('id')
                console.log g1Child.attr('id')

                # if it has a transform attribute, it'll be easy sailing
                if g1Child.attr('transform')
                    g2Child.attr('display', 'none')
                    g1Child.transition().duration(1000).attr('transform', g2Child.attr('transform'))
                else
                    bbox1 = g1Child[0][0].getBBox()
                    bbox2 = g2Child[0][0].getBBox()

                    dx = bbox2.x - bbox1.x
                    dy = bbox2.y - bbox1.y

                    sw = bbox2.width / bbox1.width
                    sh = bbox2.height / bbox1.height

                    identityTransform = 'translate(0 0) scale(1 1)'
                    targetTransform =  'translate(' + (bbox2.x) + ' ' + (bbox2.y) + ') scale(' + sw + ' ' + sh + ') translate(' + (-bbox1.x) + ' ' + (-bbox1.y) + ')'

                    g2Child.attr('display', 'none')
                    g1Child.attr('transform', identityTransform)
                    g1Child.transition().duration(1000).attr('transform', targetTransform)

            else
                console.log 'fade out ' + childId
                g1Child.transition().duration(1000).attr('opacity', 0.0)


        g2.attr('opacity', 0.0)
        g2.attr('display', 'inline')
        g2.transition().duration(1000).attr('opacity', 1.0)

        # for childId, i in g2ChildIdStems

        #     if childId not in g1ChildIdStems
        #         console.log 'fade in ' + childId
        #         g2Child = d3.select(g2ChildIds[i])
        #         g2Child.attr('opacity', 0.0)
        #         g2Child.transition().duration(1000).attr('opacity', 1.0)




    # Float a div element over top of an SVG rect element
    floatOverRect: (svgSelector, rectSelector, divSelector) ->

        svg = d3.select(svgSelector).node()
        rect = d3.select(rectSelector).node()
        div = d3.select(divSelector)
        div.style('position', 'fixed')

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

    maintainAspect: (evt) ->
        target = 16.0 / 9.0

        width = window.innerWidth + 0
        height = window.innerHeight + 0

        current_aspect = width / height

        width -= 20
        height -= 20

        console.log(target)
        console.log(width)
        console.log(width / target)
        console.log(current_aspect)

        if current_aspect < target
            # height constrains
            $('#stage').width(width)
            $('#stage').height(width / target)
        else
            $('#stage').width(height * target)
            $('#stage').height(height)

            offset =
                top: 0
                left: (width - height * target) / 2.0

            $('#stage').offset(offset)


    loadScript: (url, callback) ->
        console.log 'Loading external script from URL: ' + url

        script = document.createElement("script")
        script.type = "text/javascript"
        script.id = "sceneCode"

        if (script.readyState)  # IE
            script.onreadystatechange = ->
                if (script.readyState == "loaded" ||
                        script.readyState == "complete")
                    script.onreadystatechange = null
                    callback()

        else  # Others
            script.onload = ->
                callback()


        console.log('setting script src')
        script.src = url
        console.log('set script src')
        document.getElementsByTagName("head")[0].appendChild(script)


root = window ? exports
root.util = util

window.onresize = ->
    util.maintainAspect()
    f() for f in resizeHandlers
