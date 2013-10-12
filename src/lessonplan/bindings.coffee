#<< lessonplan/util

logInteraction = (type, target, value) ->

    data =
        type: type
        target: target
        value: value

    $.ajax(
        url: '/log-interaction'
        type: 'POST'
        data: JSON.stringify(data)
        dataType: 'json'
        contentType: 'application/json'
    )


# A knockout jquery-ui handler
ko.bindingHandlers.slider =

    init: (element, valueAccessor, allBindingsAccessor)  ->
        console.log element
        console.log valueAccessor
        console.log allBindingsAccessor

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
                util.showElement(el, duration)
            else
                util.hideElement(el, duration)

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

        bbox = el.node().getBBox()

        if centered
            center = [bbox.x + bbox.width/2.0, bbox.y + bbox.height/2.0]
            origTransform = el.attr('transform')
            recenter = (el) ->
                newbbox = el.node().getBBox()
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
            d3.select(s).on('click', ->
                observable(!observable())
                try
                    logInteraction('toggle', {'on': onSelector, 'off': offSelector}, observable())
                catch e
                    console.log 'unable to log interaction'
            )

    bindAsMomentaryButton: (svg, onSelector, offSelector, observable) ->

        selectorMap = {}
        selectorMap[onSelector] = true
        selectorMap[offSelector] = false

        # bind the selectorMap to the observable
        @bindMultiState(svg, selectorMap, observable)

        for s in Object.keys(selectorMap)
            d3.selectAll(s).on('mousedown', ->
                observable(true)
                try
                    logInteraction('momentary-down', {'on': onSelector, 'off': offSelector}, observable())
                catch e
                    console.log 'unable to log interaction'
            )
            d3.selectAll(s).on('mouseup', ->
                observable(false)
                try
                    logInteraction('momentary-up', {'on': onSelector, 'off': offSelector}, observable())
                catch e
                    console.log 'unable to log interaction'
            )

    bindMultipleChoice: (svg, selectorMap, observable) ->

        for k in Object.keys(selectorMap)
            el = svg.select(k)
            v = selectorMap[k]
            el.on('click', ->
                observable(undefined)
                observable(v)
                try
                    logInteraction('multiple-choice', {'selectors': selectorMap}, observable())
                catch e
                    console.log 'unable to log interaction'
            )


    bindSlider: (svg, knobSelector, boxSelector, orientation, observable, mapping) ->

        if mapping is undefined
            mapping = d3.scale.linear().domain([0,1]).range([0,1])

        box = svg.select(boxSelector)

        if not box?
            console.log("Couldn't find " + boxSelector)

        window.box = box

        if orientation is 'h'
            minCoord = 0 # box.node().x.animVal.value
            maxCoord = minCoord + box.node().width.animVal.value

            normalizedScale = d3.scale.linear()
                .domain([minCoord, maxCoord])
                .range([0.0, 1.0]).clamp(true)

        else
            maxCoord = 0 # box.node().y.animVal.value
            minCoord = - box.node().height.animVal.value
            #minCoord = - box.node().getBBox().height

            normalizedScale = d3.scale.linear()
                .domain([maxCoord, minCoord])
                .range([0.0, 1.0]).clamp(true)


        # create a drag "behavior" in d3
        drag = d3.behavior.drag()
            .origin(Object)
            .on("drag", (d,i) ->
                if orientation is 'h'
                    d.x += d3.event.dx
                    console.log d.x
                    if d.x > maxCoord
                        d.x = maxCoord
                    if d.x < minCoord
                        d.x = minCoord
                    observable(mapping(normalizedScale(d.x)))
                else
                    d.y += d3.event.dy
                    if d.y > maxCoord
                        d.y = maxCoord
                    if d.y < minCoord
                        d.y = minCoord
                    observable(mapping(normalizedScale(d.y)))

                d3.select(this).attr("transform", (d2,i) ->
                    return "translate(" + [ d2.x, d2.y ] + ")"
                )
            )


        svg.select(knobSelector)
            .data([ {'x' : 0, 'y': 0}])
            .call(drag)


    bindScale: (svg, selector, observable, scaleMapping, anchorType) ->


        bbox = svg.select(selector).node().getBBox()

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