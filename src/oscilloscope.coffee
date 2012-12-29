# A d3.js-based oscilloscope

# A more d3-ish implementation
oscilloscope = (svgSelector, frameSelector) ->
    svg = d3.select(svgSelector)
    frame = d3.select(frameSelector)

    dataBuffer = []

    # Domain defaults
    minX = 0.0
    maxX = 10.0
    minY = -90.0
    maxY = 50
    dataXOffset = 0.0

    # Display defaults
    margin = {top: 5.0, right: 5.0, bottom: 5.0, left: 5.0}

    xScale = undefined
    yScale = undefined
    width = 0
    height = 0

    setScales = ->
        frameXOffset = Number(frame.attr('x'))
        frameYOffset = Number(frame.attr('y'))
        width = Number(frame.attr('width')) - margin.left - margin.right
        height = Number(frame.attr('height')) - margin.top - margin.bottom

        xScale = d3.scale.linear()
                    .domain([minX, maxX])
                    .range([frameXOffset+margin.left, frameXOffset+margin.left+width])

        yScale = d3.scale.linear()
                    .domain([minY, maxY])
                    .range([frameYOffset + height + margin.top, frameYOffset + margin.top])

    setScales()

    line = d3.svg.line()
                .x((d,i) -> xScale(d[0]))
                .y((d,i) -> yScale(d[1]))


    plot = svg.insert('g', '#oscope')

    path = plot.append('path')
        .data([dataBuffer])
        .attr('class', 'line')
        .attr('d', line)


    # a proxy object to pass around d3-style
    proxy = {}

    proxy.setScales = setScales

    base = this
    addProperty = (name, cb) ->
        f = (val) ->
            if val?
                base[name] = val
                cb() if cb?
                return proxy
            else
                return base[name]

        proxy[name] = f


    addProperty(name, proxy.setScales) for name in ['minX', 'maxX', 'minY', 'maxY']

    addProperty(name) for name in ['margin', 'width']

    proxy.reset = ->
        dataBuffer.pop() for t in dataBuffer
        dataBuffer.pop()
        dataXOffset = 0.0
        setScales()

        return proxy

    dataFn = -> undefined

    proxy.data = (d) ->
        console.log('data() got: ' + d)
        if not d?
            return dataFn
        else if $.isFunction(d)
            dataFn = d
        else
            dataFn = -> d

        return proxy

    proxy.plot = ->

        # get one data point
        [x, y] = dataFn()

        # Handle the xoffset / sweep of the scope
        xval = x - dataXOffset

        if xval > maxX
            dataBuffer.pop() for t in dataBuffer
            dataBuffer.pop()
            dataXOffset = x
            xval = 0.0

        # Push the new value onto the dataBuffer
        dataBuffer.push([xval, y])

        # Instruct d3 to redraw the line
        path.data([dataBuffer]).attr('d', line)

        return proxy

    return proxy




root = window ? exports
root.oscilloscope = oscilloscope
