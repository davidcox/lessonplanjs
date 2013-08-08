# Utilities and syntactic sugar for making bindings
# more seamless.
#
# A prop object wraps the Knockout.js low-level
# bindings API, reproducing the functionality of the
# KO bindings, but also allowing a prop to assigned
# to another prop, binding them together.
#
# Convenience functions for inheriting all properties
# from another object, and for defining them en-masse
# are also provided.

class lessonplan.PropsEnabled

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


class lessonplan.ViewModel extends lessonplan.PropsEnabled
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
                this[k] = ko.computed({
                            read: ->
                                targetVal()
                            write: (newVal) ->
                                targetVal(newVal)
                          })


