#<< lessonplan/util
#<< lessonplan/logging

logInteraction = logging.logInteraction


# A knockout jquery-ui handler
ko.bindingHandlers.slider =

    init: (element, valueAccessor, allBindingsAccessor)  ->

        options = allBindingsAccessor().sliderOptions || {}
        $(element).slider(options)
        ko.utils.registerEventHandler(element, 'slidechange', (event, ui) ->
            console.log 'slidechange from ko'
            observable = valueAccessor()
            observable(ui.value)
        )

        ko.utils.domNodeDisposal.addDisposeCallback(element, () ->
            console.log 'domNodeDisposal'
            $(element).slider('destroy')
        )

        ko.utils.registerEventHandler(element, 'slide', (event, ui) ->
            console.log 'slide event, from ko'
            observable = valueAccessor()
            observable(ui.value)
        )

    update: (element, valueAccessor) ->
        console.log 'called update on slide ko binding'
        value = ko.utils.unwrapObservable(valueAccessor())
        if (isNaN(value))
            value = 0
        $(element).slider('value', value)


@manualOutputBindings = []

svgbind =

    batchBindVisible: (svg, selectorMap, duration) ->
        for k in Object.keys(selectorMap)
            @bindVisible(svg, k, selectorMap, duration)

    bindVisible: (svg, selector, observable, duration) ->
        if duration is undefined
            duration = 500

        el = svg.select(selector)

        thisobj = this
        setter = (newVal) ->
            if newVal
                util.showSVGElement(el, duration)
            else
                util.hideSVGElement(el, duration)

        observable.subscribe(setter)
        setter(observable())


    bindAttr: (svg, selector, attr, observable, mapping) ->

        el = svg.select(selector)

        setter = (newVal) ->
            el.attr(attr, mapping(newVal))

        observable.subscribe(setter)
        setter(observable())

    bindText: (svg, selector, observable, centered) ->
        el = svg.select(selector)

        try
            bbox = el.node().getBBox()
        catch error
            if el.style('display') is 'none'
                el.attr('visibility', 'hidden')
                el.style('display', 'inline')
                bbox = el.node().getBBox()
            else
                # almost certainly wrong
                bbox = el.node().getBoundingClientRect()

        if centered
            center = [bbox.x + bbox.width/2.0, bbox.y + bbox.height/2.0]
            origTransform = el.attr('transform')
            recenter = (el) ->
                try
                    newbbox = el.node().getBBox()
                catch error
                    newbbox = el.node().getBoundingClientRect()

                newcenter = [ newbbox.x + newbbox.width/2.0, newbbox.y + newbbox.height/2.0]
                transform = origTransform
                transform += 'translate(' + center[0] + ', ' + center[1] + ') '
                transform += 'translate(' + (-1*newcenter[0]) + ', ' + (-1*newcenter[1]) + ') '
                el.attr('transform', transform)

        else
            recenter = (el) ->


        setter = (newVal) ->
            el.text(newVal)
            recenter(el)

        observable.subscribe(setter)
        setter(observable())

    bindMultiState: (svg, selectorMap, observable, duration) ->
        if duration is undefined
            duration = 10
        keys = Object.keys(selectorMap)
        values = (selectorMap[k] for k in keys)
        elements = (svg.select(s) for s in keys)

        setter = (val) ->
            # hide all of the alternatives
            util.hideElement(el) for el in elements

            matchSelectors = (keys[i] for i in [0 .. keys.length] when values[i] == val)
            matchElements = (svg.select(s) for s in matchSelectors)
            util.showElement(el) for el in matchElements

        observable.subscribe(setter)

        setter(observable())


    bindAsToggle: (svg, onSelector, offSelector, observable) ->
        selectorMap = {}
        selectorMap[onSelector] = true
        selectorMap[offSelector] = false

        # bind the selectorMap to the observable
        @bindMultiState(svg, selectorMap, observable)

        # register on click handles for every selector in the map
        for s in Object.keys(selectorMap)
            svg.select(s).on('click', ->
                console.log 'toggle evt: ' + s
                observable(!observable())
                logInteraction('toggle', {'on': onSelector, 'off': offSelector}, observable())
            )

    bindAsMomentaryButton: (svg, onSelector, offSelector, observable) ->

        selectorMap = {}
        selectorMap[onSelector] = true
        selectorMap[offSelector] = false

        # bind the selectorMap to the observable
        @bindMultiState(svg, selectorMap, observable)

        for s in Object.keys(selectorMap)
            svg.selectAll(s).on('mousedown', ->
                observable(true)
                logInteraction('momentary-down', {'on': onSelector, 'off': offSelector}, observable())
            )
            svg.selectAll(s).on('mouseup', ->
                observable(false)
                logInteraction('momentary-up', {'on': onSelector, 'off': offSelector}, observable())
            )

    bindMultipleChoice: (svg, selectorMap, observable) ->

        for k in Object.keys(selectorMap)
            el = svg.select(k)
            v = selectorMap[k]

            observable.extend(notify: 'always')

            # JS charm
            f = (v) ->
                el.on('click', ->
                    # observable(undefined)
                    observable(v)
                    logInteraction('multiple-choice', {'selectors': selectorMap}, observable())
                )
            f(v)


    bindSlider: (svg, knobSelector, boxSelector, orientation, observable, mapping) ->

        # value (observable coords) -> actual value (e.g. voltage)
        # Slider coords -> [0, 1] (i.e. this side to that side)
        # Svg coords -> svg pixels

        # mapping is from [0, 1] -> [observable value]
        if mapping is undefined
            mapping = d3.scale.linear().domain([0,1]).range([0,1])

        sliderCoordsToValue = mapping
        valueToSliderCoords = mapping.invert

        box = svg.select(boxSelector)

        window.box = box
        if not box?
            console.log("Couldn't find " + boxSelector)

        # build mapping from svg coords to slider coords
        if orientation is 'h'
            minCoord = 0 # box.node().x.animVal.value
            maxCoord = minCoord + box.node().width.animVal.value

            svgCoordsToSliderCoords = d3.scale.linear()
                .domain([minCoord, maxCoord])
                .range([0.0, 1.0]).clamp(true)

        else
            minCoord = 0
            maxCoord = -box.node().height.animVal.value

            svgCoordsToSliderCoords = d3.scale.linear()
                .domain([minCoord, maxCoord])
                .range([0.0, 1.0]).clamp(true)


        sliderCoordsToSvgCoords = svgCoordsToSliderCoords.invert

        svgCoordsToValue = (svgCoord) ->
            return sliderCoordsToValue(svgCoordsToSliderCoords(svgCoord))

        valueToSvgCoords = (v) ->
            return sliderCoordsToSvgCoords(valueToSliderCoords(v))

        sliderTransform = (d,i) ->

            svgCoord = valueToSvgCoords(d.value)
            coord = [0, 0]
            if orientation is 'h'
                coord[0] = svgCoord - knob.attr('r')
            else
                coord[1] = svgCoord

            return "translate(" + coord + ")"


        knob = svg.select(knobSelector)

        # create a drag "behavior" in d3
        drag = d3.behavior.drag()
            .on("drag", (d,i) ->

                if orientation is 'h'
                    svgCoord = d3.event.x - box.node().x.animVal.value
                else
                    svgCoord = (d3.event.y - box.node().y.animVal.value - box.node().height.animVal.value)

                d.value = svgCoordsToValue(svgCoord)

                observable(d.value)

                logInteraction('slider-drag', knobSelector, observable())


            )

        d = {value: observable()}


        knob.data([d])
            .attr("transform", sliderTransform)
            .call(drag)

        # subscribe to the observable
        observable.subscribe((v) ->
            knob.data([{value: v}])
                .attr("transform", sliderTransform)
                .call(drag)
        )


    bindScale: (svg, selector, observable, scaleMapping, anchorType) ->

        el = svg.select(selector)
        try
            bbox = el.node().getBBox()
        catch error
            console.log 'failed to get bbox'
            console.log el
            window.el = el
            if el.style('display') is 'none'
                el.attr('visibility', 'hidden')
                el.style('display', 'inline')
                bbox = el.node().getBBox()
            else
                # almost certainly not right
                bbox = el.node().getBoundingClientRect()

        if anchorType is 'sw'
            anchor = [bbox.x, bbox.y + bbox.height]
        else if anchorType is 'nw'
            anchor = [bbox.x, bbox.y + bbox.height]
        else if anchorType is 'ne'
            anchor = [bbox.x + bbox.width, bbox.y + bbox.height]
        else if anchorType is 'se'
            anchor = [bbox.x, bbox.y]
        else
            anchor = [bbox.x + bbox.width/2.0, bbox.y + bbox.height/2.0]

        transformFn = (val) ->
            s = scaleMapping(val)
            transform = ''
            transform += 'translate(' + anchor[0] + ', ' + anchor[1] + ') '

            transform += 'scale(' + s + ') '
            transform += 'translate(' + (-1 * anchor[0]) + ', ' + (-1 * anchor[1]) + ') '

            return transform

        @bindAttr(svg, selector, 'transform', observable, transformFn)

    # exposeOutputBindings: (sourceObj, keys, viewModel) ->
    #     @bindOutput(sourceObj, key, viewModel) for key in keys

    # bindOutput: (sourceObj, key, viewModel, key2) ->
    #     if not key2?
    #         key2 = key

    #     if viewModel[key2]?
    #         viewModel[key2](sourceObj[key])
    #     else
    #         viewModel[key2] = ko.observable(sourceObj[key])
    #     manualOutputBindings.push([sourceObj, key, viewModel[key2]])

    # update: ->
    #     obs(sourceObj[key]) for [sourceObj, key, obs] in manualOutputBindings

    # bindInput: (sourceObj, key, viewModel, key2, cb) ->
    #     if not key2?
    #         key2 = key

    #     if viewModel[key2]?
    #         viewModel[key2](sourceObj[key])
    #     else
    #         viewModel[key2] = ko.observable(sourceObj[key])

    #     viewModel[key2].subscribe((newVal) ->
    #         sourceObj[key] = newVal
    #         cb() if cb?
    #     )

    # exposeInputBindings: (sourceObj, keys, viewModel) ->
    #     @bindInput(sourceObj, key, viewModel) for key in keys


root = window ? exports
root.svgbind = svgbind