
hideElement = (el) ->
    el.attr('opacity', 0.0)

showElement = (el) ->
    el.attr('opacity', 1.0)

# A knockout jquery-ui handler
ko.bindingHandlers.slider =

    init: (element, valueAccessor, allBindingsAccessor)  ->
        options = allBindingsAccessor().sliderOptions || {}
        $(element).slider(options)
        ko.utils.registerEventHandler(element, 'slidechange', (event, ui) ->
            observable = valueAccessor()
            observable(ui.value)
        )

        ko.utils.domNodeDisposal.addDisposeCallback(element, () ->
            $(element).slider('destroy')
        )

        ko.utils.registerEventHandler(element, 'slide', (event, ui) ->
            observable = valueAccessor()
            observable(ui.value)
        )

    update: (element, valueAccessor) ->
        value = ko.utils.unwrapObservable(valueAccessor())
        if (isNaN(value))
            value = 0
        $(element).slider('value', value)




@manualOutputBindings = []

svgbind =

    bindVisible: (selector, observable) ->
        el = d3.select(selector)

        thisobj = this
        setter = (newVal) ->
            if newVal
                showElement(el)
            else
                hideElement(el)

        observable.subscribe(setter)
        setter(observable())


    bindAttr: (selector, attr, observable, mapping) ->

        el = d3.select(selector)

        setter = (newVal) ->
            el.attr(attr, mapping(newVal))

        observable.subscribe(setter)
        setter(observable())

    bindText: (selector, observable, centered) ->
        el = d3.select(selector)

        bbox = el.node().getBBox()
        console.log(bbox)

        if centered
            center = [bbox.x + bbox.width/2.0, bbox.y + bbox.height/2.0]
            recenter = (el) ->
                newbbox = el.node().getBBox()
                newcenter = [ newbbox.x + newbbox.width/2.0, newbbox.y + newbbox.height/2.0]
                transform = ''
                transform += 'translate(' + center[0] + ', ' + center[1] + ') '
                transform += 'translate(' + (-1*newcenter[0]) + ', ' + (-1*newcenter[1]) + ') '
                el.attr('transform', transform)
                console.log(transform)
                console.log(center)
                console.log(newcenter)
        else
            recenter = (el) ->

        console.log(recenter)

        setter = (newVal) ->
            el.text(newVal)
            #recenter(el)

        observable.subscribe(setter)
        setter(observable())

    bindMultiState: (selectorMap, observable) ->
        keys = Object.keys(selectorMap)
        values = (selectorMap[k] for k in keys)
        elements = (d3.select(s) for s in keys)

        setter = (val) ->
            # hide all of the alternatives
            hideElement(el) for el in elements

            matchSelectors = (keys[i] for i in [0 .. keys.length] when values[i] == val)
            matchElements = (d3.select(s) for s in matchSelectors)
            showElement(el) for el in matchElements

        observable.subscribe(setter)

        setter(observable())


    bindScale: (selector, observable, scaleMapping, anchorType) ->


        bbox = d3.select(selector).node().getBBox()

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

        @bindAttr(selector, 'transform', observable, transformFn)

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