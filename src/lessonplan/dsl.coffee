#<< lessonplan/lessonplan
#<< lessonplan/video


# Imperative Domain Specific Language bits
# Some slightly abused coffescript syntax to make
# the final script read more like an outline or
# "script" in the lines-in-a-documentary sense of the
# word

root = window ? exports

# TODO: unify placement of defines like this
svgRoot = root.static_base_url + '/slides'


# Infrastructure for managing the 'current' object
# in our little imperative DSL
# TODO: worry about namespace collisions

dsl =
    currentStack: []
    currentObj: undefined

dsl.pushCurrent = (obj) ->
    dsl.currentStack.push(dsl.currentObj)
    dsl.currentObj = obj

dsl.popCurrent = ->
    dsl.currentObj = dsl.currentStack.pop()


root.scene = (sceneId, title) ->
    sceneObj = new lessonplan.Scene(sceneId, title)

    (f) ->
        dsl.currentObj = sceneObj
        f()

root.message = (msg) ->

    consoleObj = new lessonplan.Message(msg)

    dsl.currentObj.addChild(consoleObj)


root.interactive = (beatId) ->
    #register the id
    beatObj = new lessonplan.Interactive(beatId)

    dsl.currentObj.addChild(beatObj)

    (f) ->
        dsl.pushCurrent(beatObj)
        f()
        dsl.popCurrent()

root.stage = (name, propertiesMap) ->

    if stages[name]?
        console.log('loading registered interactive svg object: ' + name)
        s = stages[name]()
    else
        fpath = svgRoot + '/' + name
        console.log('loading interactive svg by filename: ' + fpath)
        s = new lessonplan.InteractiveSVG(fpath)

    console.log('name: ' + name)
    console.log('propertiesMap: ' + propertiesMap)

    if propertiesMap?
        for k in Object.keys(propertiesMap)
            console.log('setting ' + k + ' on ' + s + ' to ' + propertiesMap[k])
            if s[k]?
                s[k](propertiesMap[k])

    dsl.currentObj.stage(s)


root.soundtrack = (s) ->
    dsl.currentObj.soundtrack(s)

root.line = (text, audio, actions) ->
    lineObj = new lessonplan.Line(text, audio)

    if actions?
        dsl.pushCurrent(lineObj)
        actions()
        dsl.popCurrent()

    dsl.currentObj.addChild(lineObj)


root.lines = line

root.show = (selectors...) ->
    showObj = new lessonplan.ShowAction(selectors)

    dsl.currentObj.addChild(showObj)

root.hide = (selectors...) ->
    hideObj = new lessonplan.HideAction(selectors)

    dsl.currentObj.addChild(hideObj)

root.set_property = (property, value) ->
    setObj = new lessonplan.SetAction(property, value)

    dsl.currentObj.addChild(setObj)

root.m4v = (f, quality='default') ->
    dsl.currentObj.media('m4v', f, quality)
root.mp4 = (f, quality='default') ->
    dsl.currentObj.media('mp4', f, quality)
root.webm = (f, quality='default') ->
    dsl.currentObj.media('webm', f, quality)
root.ogv = (f, quality='default') ->
    dsl.currentObj.media('ogv', f, quality)
root.vimeo = (f, quality='default') ->
    dsl.currentObj.media('vimeo', f, quality)
root.youtube = (f, quality='default') ->
    dsl.currentObj.media('youtube', f, quality)


root.video = (name) ->
    videoObj = new lessonplan.Video(name)
    dsl.currentObj.addChild(videoObj)

    (f) ->
        dsl.pushCurrent(videoObj)
        f()
        dsl.popCurrent()

root.subtitles = (f) ->
    console.log('adding subtitles: ' + f)
    dsl.currentObj.subtitles(f)

root.duration = (t) ->
    dsl.currentObj.duration(t) if dsl.currentObj.duration?

root.cue = (t, actions) ->

    cueObj = new lessonplan.LessonElement()
    if actions?
        dsl.pushCurrent(cueObj)
        actions()
        dsl.popCurrent()

    dsl.currentObj.cue(t, cueObj)

root.at = (t) ->
    newContext = (t1) ->
        return (a) -> root.cue(t1, a)

    return newContext(t)

root.milestone = (name) ->
    milestoneObj = new lessonplan.MilestoneAction(name)

    dsl.currentObj.addChild(milestoneObj)

root.play = (name) ->
    runObj = new lessonplan.PlayAction(name)
    dsl.currentObj.addChild(runObj)


root.wait = (delay) ->
    waitObj = new lessonplan.WaitAction(delay)
    dsl.currentObj.addChild(waitObj)

root.stop_and_reset = (name) ->
    stopResetObj = new lessonplan.StopAndResetAction(name)
    dsl.currentObj.addChild(stopResetObj)

root.goal = (f) ->
    goalObj = new lessonplan.FSM(f())
    dsl.currentObj.addChild(goalObj)

root.choice = (o) ->
    choiceObj = new lessonplan.WaitForChoice(o)
    dsl.currentObj.addChild(choiceObj)

    subf = (options) ->
        if options?
            dsl.pushCurrent(choiceObj)
            options()
            dsl.popCurrent()

    return subf

root.option = (v...) ->
    optionObj = new lessonplan.LessonElement()
    optionObj.value = v

    if dsl.currentObj.addOption?
        dsl.currentObj.addOption(optionObj)

    subf = (actions) ->
        if actions?
            dsl.pushCurrent(optionObj)
            actions()
            dsl.popCurrent()

    return subf

root.glow = (targets...) ->
    glowObj = new lessonplan.GlowAction(targets)
    dsl.currentObj.addChild(glowObj)

root.unglow = (targets...) ->
    unglowObj = new lessonplan.UnglowAction(targets)
    dsl.currentObj.addChild(unglowObj)

root.transition = (groupFrom, groupTo) ->
    transitionObj = new lessonplan.GroupTransitionAction(groupFrom, groupTo)
    console.log '-------======'
    console.log transitionObj
    dsl.currentObj.addChild(transitionObj)

root.fsm = goal

root.dsl = dsl