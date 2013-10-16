

root = window ? exports


logging =

    logInteraction: (type, target, value) ->

        try
            coursePathHash = root.path_hash ? '?'

            data =
                type: type
                target: target
                value: value
                path_hash: coursePathHash

            $.ajax(
                url: '/log-interaction'
                type: 'POST'
                data: JSON.stringify(data)
                dataType: 'json'
                contentType: 'application/json'
            )

        catch e
            console.log 'Unable to log interaction'

root.logging = logging
