

class mcb80x.PropsEnabled

    prop: (defaultVal, cb) ->
        owner = this

        obs = ko.observable(defaultVal)

        if cb?
            obs.subscribe(cb)

        obs.bindVisisble = (sel) -> bindVisisble

        f = (newVal) ->
            if newVal?
                # if its another observable, replace the
                # current observable with this one
                if newVal.subscribe?
                    obs = newVal
                    if cb?
                        obs.subscribe(cb)
                else
                    obs(newVal)
                return owner
            else
                return obs()
        f.observable = obs
        f.subscribe = (f2) -> obs.subscribe(f2)
        return f

    defineProps: (names, defaultVal) ->
        for name in names
            this[name] = @prop(defaultVal)


class mcb80x.ViewModel extends mcb80x.PropsEnabled
    constructor: ->

    inheritProperties: (target, keys) ->
        if not keys?
            keys = (k for k,v of target when v.subscribe?)

        if not $.isArray(keys)
            keys = [keys]

        for k in keys
            targetVal = target[k]

            if not $.isFunction(targetVal)
                throw "Unsupported parameter to inherit: " + k

            # is it a ko binding (or equivalent?)
            if targetVal.observable?
                this[k] = targetVal.observable
            else
                console.log('here')
                this[k] = ko.computed({
                            read: ->
                                targetVal()
                            write: (newVal) ->
                                targetVal(newVal)
                          })


class mcb80x.InteractiveSVG extends mcb80x.ViewModel

    constructor: (@svgFileName) ->


    # Main initialization function; triggered after the SVG doc is
    # loaded
    svgDocumentReady: (xml, cb) ->

        # transition out the video if it's visible
        # d3.select('#video').transition().style('opacity', 0.0).duration(1000)

        # Attach the SVG to the DOM in the appropriate place
        importedNode = document.importNode(xml.documentElement, true)

        # hollow out the 'art' node to remove anything there previously
        $('#art').empty()

        d3.select('#art').node().appendChild(importedNode)
        d3.select('#art').transition().style('opacity', 1.0).duration(1000)

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

    show: (cb) ->
        console.log('showing interactive: ' + @svgFileName)

        cb1 = ->
            d3.select('#interactive').transition()
                .style('opacity', 1.0)
                .duration(1000)
                .each('end', cb)

        d3.xml(@svgFileName, 'image/svg+xml', (xml) => @svgDocumentReady(xml, cb1))


    hide: (cb) ->
        @runSimulation = false
        d3.select('#interactive').transition()
            .style('opacity', 0.0)
            .duration(1000)
            .each('end', cb)
