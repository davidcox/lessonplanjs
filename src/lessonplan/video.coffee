#<< lessonplan/lessonplan

# A somewhat hacked up video object / player
# designed to work as a LessonElement object
# largely, this just object coordinates a Popcorn.js
# video object, and provides hooks need by the
# SceneController, which coordinates the hybrid
# video/interactive/etc. flow.
# The UI elements for the player chrome are defined
# in timeline.coffee

root = window ? exports

videoPlayerDivSelector = '#video'
interactiveDivSelector = '#interactive'

class lessonplan.Video extends lessonplan.LessonElement
    constructor: (elId) ->
        @preferredFormat = 'mp4'
        # @preferredFormat = 'youtube'
        @duration = ko.observable(1.0)
        @mediaUrlDict = {}
        @mediaUrls = []

        @playerReady = $.Deferred()
        super(elId)


    media: (fileType, url) ->
        if url?
            @mediaUrlDict[fileType] = url
            @mediaUrls.push(url)
        else
            return @mediaUrlDict[fileType]

    mediaTypes: ->
        return [k for k of @mediaUrlDict]


    subtitles: (f) ->
        # fill me in


    # init is called after the DOM is ready
    init: ->

        # hide the video player by default
        $(videoPlayerDivSelector).attr('style', 'opacity: 0.0;')

        @playerSelector = undefined

        @load()

        super()

    reset: (t) ->
        console.log('Resetting video')
        t = 0.0 if not t?
        @seek(t)

        @hide()

        super()

    seek: (t) ->
        console.log('seeking video to ' + t)
        @pop.pause()
        @pop.currentTime(t)

        dfrd = $.Deferred()

        checkIfSeeking = =>
            if not @pop.seeking()
                dfrd.resolve()
            else
                setTimeout(checkIfSeeking, 100)

        checkIfSeeking()
        return dfrd

    show: ->

        @playerNode.setAttribute('style', 'display: inline; opacity: 1.0;')

        d3.select('#interactive').transition().style('opacity', 0.0).duration(1000)
        d3.select(videoPlayerDivSelector).style('display', 'inline')
        d3.select(videoPlayerDivSelector).transition().style('opacity', 1.0).duration(1000)

        util.showBackdrop(true)

    hide: ->
        d3.select(videoPlayerDivSelector).transition().style('opacity', 0.0).duration(1000)
        #d3.select(videoPlayerDivSelector).style('display', 'none')
        @playerNode.setAttribute('style', 'opacity: 0.0;') if @playerNode?


    cleanup: ->
        if @playerNode? and @playerNode.remove?
            @playerNode.remove()
        @playerNode = undefined

    # playWhenReady: ->
    #     if @pop.readyState() >= 4
    #         @pop.play(0)

    #     else
    #         playit = =>
    #             console.log('buffering... ' + @pop.readyState())
    #             @playWhenReady()
    #         setTimeout(playit, 1000)

    load: ->

        f = @media(@preferredFormat)

        # Load the media on the player object
        if @preferredFormat == 'vimeo' or @preferredFormat == 'youtube'

            if @preferredFormat == 'vimeo'
                url = 'http://player.vimeo.com/video/' + f
                console.log('f: ' + f)
                # @pop.url = f
                @pop = Popcorn.vimeo(videoPlayerDivSelector, url)
            else
                url = 'http://www.youtube.com/embed/' + f + '?controls=0&enablejsapi=1&modestbranding=1&showinfo=0&rel=0'
                @pop = Popcorn.youtube(videoPlayerDivSelector, url)

            #  Need to do some machinations to get our hands on the correct iframe node
            console.log(videoPlayerDivSelector + ' iframe')

            preparePlayer = =>
                console.log('preparing player')
                iframes = $(videoPlayerDivSelector + ' iframe')

                console.log(iframes)
                window.iframes = iframes
                iframes.each( (i, v) =>
                    console.log('iframe')
                    console.log(v)
                    src = v.getAttribute('src')
                    r = new RegExp(f, 'g')
                    window.r = r
                    window.src = src
                    console.log('src: ' + src + ', f: ' + f)
                    m = src.match(r)
                    if m? and m.length > 0
                        console.log('found correct iframe')
                        console.log(v)
                        @playerNode = v
                )

                if not @playerNode?
                    setTimeout(preparePlayer, 100)
                    return

                # @playerNode.setAttribute('style', 'display:none;')

                if @preferredFormat is 'youtube'
                    @youtubePreload()
                else
                    @playerReady.resolve()

            # this must run as a separate evt since the
            # injected player won't be available until after this
            # function ends
            setTimeout(preparePlayer, 0)

        else
            console.log('==============================')
            console.log(@mediaUrls)
            @pop = Popcorn.smart(videoPlayerDivSelector, @mediaUrls)
            # @pop = Popcorn.baseplayer(videoPlayerDivSelector, @mediaUrls())

            @playerNode = @pop.video
            if @playerNode.hasAttribute('controls')
                @playerNode.removeAttribute('controls')

            @playerNode.setAttribute('style', 'opacity: 0;')
            # @playerNode.setAttribute('style', 'display:none;')

            @playerReady.resolve()

        console.log('loading ' + f)

        @pop.on('durationchange', =>
            console.log('duration changed!:' + @pop.duration())
            dur = @pop.duration()
            @duration(dur)
        )

        @pop.load()


    youtubePreload: ->

        console.log('preloading youtube')

        @playerNode.setAttribute('style', 'opacity: 0; display: inline')
        @pop.mute()
        @pop.play()

        checkReady = =>
            if @pop.readyState() is 4
                @pop.pause(0)
                @pop.unmute()
                # @playerNode.setAttribute('style', 'opacity:1.0;')
                @playerNode.setAttribute('style', 'opacity:0.0;')
                console.log('youtube video loaded')
                @playerReady.resolve()
            else
                console.log(@pop.readyState())
                setTimeout(checkReady, 500)

        checkReady()


    finish: ->
        # unregister callbacks
        @pop.off('ended', @yieldCb) if @yieldCb
        @pop.off('updatetime', @updateTimeCb) if @updateTimeCb

        # hide the video
        @hide()

    run: ->

        console.log('video run called')
        dfrd = $.Deferred()

        $.when(@playerReady).done( =>

            console.log('playing video')

            @show()

            @updateTimeCb = =>
                t = @pop.currentTime()
                @parentScene.currentTime(t)
            @pop.on('timeupdate', @updateTimeCb)


            # yield when the view has ended
            @yieldCb = ->
                console.log('video finished cb')
                dfrd.resolve()
            @pop.on('ended', @yieldCb)

            # @pop.currentTime(0)
            @pop.play()
        )

        return dfrd

    pause: ->
        @pop.pause() if @pop

    resume: ->
        @pop.play() if @pop

    stop: ->
        @pop.pause() if @pop
        @hide()
        super()

    ready: ->
        if @pop?
            return (@pop.readyState() == 4)
        else
            return false

