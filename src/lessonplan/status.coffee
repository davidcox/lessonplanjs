status =

	getStatus: (path, name) ->
		url = lessonplanConfig.apiBaseUrl + '/' + path + '/' + name
		$.ajax(
			url: url,
			type: 'GET',
			success: (result) -> 
				console.log('get status[' + path + ' , ' + name + ']')
				if (result == 1)
					return 'available'
				else if (result == 0)
					return 'blocked'
				else
					return 'unavailable'
		)
