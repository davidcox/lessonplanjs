#<< lessonplan/lessonplan
#<< lessonplan/util

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
    constructor: (elId, @inserted=false) ->
        @preferredFormat = 'mp4'
        # @preferredFormat = 'youtube'

        # a very coarse marker of whether the video is OK or not
        @broken = false

        @duration = ko.observable(1.0)
        @mediaUrlDict = {}
        @mediaUrls = {}

        @cues = []

        @videoQuality = 'default'

        @playerReady = $.Deferred()
        super(elId)


    quality: (q) ->
        if q?
            @videoQuality = q
        else
            return @videoQuality

    qualities: () ->
        return keys(@mediaUrlDict)

    media: (fileType, url, quality='default') ->
        if url?
            if not @mediaUrls[quality]?
                @mediaUrls[quality] = []
            @mediaUrls[quality].push(url)
        else
            if @mediaUrlDict[quality]?
                return @mediaUrlDict[quality][fileType]
            else
                return null

    mediaTypes: (quality='default') ->
        if @mediaUrlDict[quality]?
            return [k for k of @mediaUrlDict[quality]]
        else
            return []

    subtitles: (f) ->
        # fill me in
        @subtitlesFile = f


    # init is called after the DOM is ready
    init: ->

        # hide the video player by default
        $(videoPlayerDivSelector).attr('style', 'opacity: 0.0;')

        @playerSelector = undefined

        $.when(@load()).fail(=>
            @broken = true
            util.indicateLoadFail(true)
        )

        super()

    reset: (t) ->
        if @broken then return

        console.log('Resetting video')

        t = 0.0 if not t?

        @seek(t)

        @hide()

        super()

    lookupMilestone: (n) ->
        for [t, actions] in @cues
            for a in actions
                if a instanceof lessonplan.Milestone and a.name is n
                    return t

        return null

    seek: (t) ->
        console.log('seeking video to ' + t)

        dfrd = $.Deferred()

        if typeof(t) != 'number'
            t = @lookupMilestone(t)
            if not t?
                dfrd.reject()
                return dfrd

        @pop.pause()
        @pop.currentTime(t)

        checkIfSeeking = =>
            if not @pop.seeking()
                dfrd.resolve()
            else
                setTimeout(checkIfSeeking, 100)

        checkIfSeeking()
        return dfrd

    show: ->

        if @inserted
            $('#interactive').css('z-index', 50)

        $(videoPlayerDivSelector).css('z-index', 100)
        @playerNode.setAttribute('style', 'display: inline; opacity: 1.0;')

        # d3.select('#interactive').transition().style('opacity', 0.0).duration(1000)
        d3.select(videoPlayerDivSelector).style('display', 'inline')
        d3.select(videoPlayerDivSelector).transition().style('opacity', 1.0).duration(1000)

        if not @inserted
            util.showBackdrop(true)

    hide: ->

        d3.select(videoPlayerDivSelector).transition().style('opacity', 0.0).duration(1000)
        #d3.select(videoPlayerDivSelector).style('display', 'none')
        @playerNode.setAttribute('style', 'opacity: 0.0; display: none') if @playerNode?

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

        dfrd = $.Deferred()

        # f = @media(@preferredFormat)

        # # Load the media on the player object


        # For the sake of cleanliness, removing the unused Vimeo/Youtube code...
        # may reinstate later...

        # if @preferredFormat == 'vimeo' or @preferredFormat == 'youtube'

        #     if @preferredFormat == 'vimeo'
        #         url = 'http://player.vimeo.com/video/' + f
        #         console.log('f: ' + f)
        #         # @pop.url = f
        #         @pop = Popcorn.vimeo(videoPlayerDivSelector, url)
        #     else
        #         url = 'http://www.youtube.com/embed/' + f + '?controls=0&enablejsapi=1&modestbranding=1&showinfo=0&rel=0'
        #         @pop = Popcorn.youtube(videoPlayerDivSelector, url)

        #     #  Need to do some machinations to get our hands on the correct iframe node
        #     console.log(videoPlayerDivSelector + ' iframe')

        #     preparePlayer = =>
        #         console.log('preparing player')
        #         iframes = $(videoPlayerDivSelector + ' iframe')

        #         console.log(iframes)
        #         window.iframes = iframes
        #         iframes.each( (i, v) =>
        #             console.log('iframe')
        #             console.log(v)
        #             src = v.getAttribute('src')
        #             r = new RegExp(f, 'g')
        #             window.r = r
        #             window.src = src
        #             console.log('src: ' + src + ', f: ' + f)
        #             m = src.match(r)
        #             if m? and m.length > 0
        #                 console.log('found correct iframe')
        #                 console.log(v)
        #                 @playerNode = v
        #         )

        #         if not @playerNode?
        #             setTimeout(preparePlayer, 100)
        #             return

        #         # @playerNode.setAttribute('style', 'display:none;')

        #         if @preferredFormat is 'youtube'
        #             @youtubePreload()
        #         else
        #             @playerReady.resolve()

        #     # this must run as a separate evt since the
        #     # injected player won't be available until after this
        #     # function ends
        #     setTimeout(preparePlayer, 0)

        # else

        if @mediaUrls[@videoQuality]?
            urls = @mediaUrls[@videoQuality]
        else if @mediaUrls['default']?
            @videoQuality = 'default'
            urls = @mediaUrls[@videoQuality]
        else
            dfrd.reject()

        console.log(urls)
        console.log videoPlayerDivSelector
        @pop = Popcorn.smart(videoPlayerDivSelector, urls)
        # @pop = Popcorn.baseplayer(videoPlayerDivSelector, @mediaUrls())

        if @subtitlesFile?
            @pop.parseJSON(@subtitlesFile)

        @playerNode = @pop.video
        if @playerNode.hasAttribute('controls')
            @playerNode.removeAttribute('controls')

        @playerNode.setAttribute('style', 'opacity: 0;')
        @playerNode.setAttribute('style', 'display:none;')

        @playerReady.resolve()

        @pop.on('durationchange', =>
            console.log('duration changed!:' + @pop.duration())
            dur = @pop.duration()
            @duration(dur)
        )

        @pop.on('canplaythrough', ->
            dfrd.resolve()
        )

        @pop.on('error', ->
            dfrd.reject()
        )

        # create new function context so the closure on
        # `a` points to the right object
        cueIt = (t, a) =>
            @pop.cue(t, ->
                console.log('running cued actions')
                lessonplan.runChained(a.children)
            )

        for [t, a] in @cues
            console.log('here')
            console.log(a)
            cueIt(t, a)

        @pop.load()
        return dfrd

    # youtubePreload: ->

    #     console.log('preloading youtube')

    #     @playerNode.setAttribute('style', 'opacity: 0; display: inline')
    #     @pop.mute()
    #     @pop.play()

    #     checkReady = =>
    #         if @pop.readyState() is 4
    #             @pop.pause(0)
    #             @pop.unmute()
    #             # @playerNode.setAttribute('style', 'opacity:1.0;')
    #             @playerNode.setAttribute('style', 'opacity:0.0;')
    #             console.log('youtube video loaded')
    #             @playerReady.resolve()
    #         else
    #             console.log(@pop.readyState())
    #             setTimeout(checkReady, 500)

    #     checkReady()


    finish: ->
        # unregister callbacks
        @pop.off('ended')
        @pop.off('timeupdate')
        @pop.off('error')
        @pop.off('canplaythrough')

        # hide the video
        @hide()

    run: (seeking=false) ->

        if seeking
            return

        if @inserted
            @show()

        console.log('video run called')
        dfrd = $.Deferred()

        $.when(@playerReady).done( =>

            if @broken
                console.log 'Unable to play video'
                dfrd.reject()
                return

            console.log('playing video')

            @show()

            if not @inserted
                @updateTimeCb = =>
                    t = @pop.currentTime()
                    @parentScene.currentTime(t)
                @pop.on('timeupdate', @updateTimeCb)


            # yield when the view has ended
            @yieldCb = ->
                console.log('video finished cb')
                dfrd.resolve()
            @pop.on('ended', @yieldCb)

            @pop.play()
        )

        if @inserted
            dfrd.done =>
                console.log 'hiding'
                @hide()

        return dfrd

    pause: ->

        dfrd = $.Deferred()

        @pop.on('pause', ->
            dfrd.resolve()
        )

        @pop.pause() if @pop

        return dfrd

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

    # store a time associated cue; these will be
    # cued against the popcorn obj when it is created
    # (in `load`)
    cue: (t, actions) ->
        @cues.push([t, actions])

