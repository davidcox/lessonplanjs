#<< lessonplan/util

# Convenience methods for interacting with the backend REST api
# (possibly should be factored out of this library at some point)

progress =

	getStatus: (path, cb) ->
		url = window.app_base_url + '/status/' + path
		$.ajax(
			url: url,
			type: 'GET',
			success: (result) ->
				console.log('get status[' + path + ' ]')
				if (result == 1)
					cb('available')
				else if (result == 0)
					cb('blocked')
				else
					cb('unavailable')
		)

	getProgress: (path, cb) ->
		url = window.app_base_url + '/progress/' + path
		$.ajax(
			url: url,
			type: 'GET',
			success: (result) ->
				console.log('get progress[' + path + ' ]')
				cb(result)

		)


root = window ? exports
root.progress = progress
