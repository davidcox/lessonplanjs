# << lessonplan/util


milestones =

	setMilestone: (path, name, value) ->

		if not value?
			value = 1.0

		url = lessonplanConfig.apiBaseUrl + '/' + path + '/' + name
		$.ajax(
			url: url,
			type: 'PUT',
			data: 'value=' + value,
			success: -> console.log('boogie')
		)

	completeMilestone: (path, name) ->
		console.log 'called completeMilstone[' + path + ' , ' + name ']'
		return setMilestone(path, name, 1.0)

	resetMilestone: (path, name) ->
		return setMilestone(path, name, 0.0)