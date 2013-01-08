

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


class mcb80x.ViewModel

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
