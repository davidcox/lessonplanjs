#<< lessonplan/lessonplan
#<< lessonplan/video

root = window ? exports

# TODO: unify placement of defines like this
svgRoot = root.static_base_url + '/slides'


# Imperative Domain Specific Language bits
# Some slightly abused coffescript syntax to make
# the final script read more like an outline or
# "script" in the lines-in-a-documentary sense of the
# word

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

root.m4v = (f) ->
    dsl.currentObj.media('m4v', f)
root.mp4 = (f) ->
    dsl.currentObj.media('mp4', f)
root.webm = (f) ->
    dsl.currentObj.media('webm', f)
root.ogv = (f) ->
    dsl.currentObj.media('ogv', f)
root.vimeo = (f) ->
    dsl.currentObj.media('vimeo', f)
root.youtube = (f) ->
    dsl.currentObj.media('youtube', f)


root.video = (name) ->
    videoObj = new lessonplan.Video(name)
    dsl.currentObj.addChild(videoObj)

    (f) ->
        dsl.pushCurrent(videoObj)
        f()
        dsl.popCurrent()

root.subtitles = (f) ->
    dsl.currentObj.subtitles(f)

root.duration = (t) ->
    dsl.currentObj.duration(t) if dsl.currentObj.duration?


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

root.fsm = goal

root.dsl = dsl