# << lessonplan/util

# Convenience methods for interacting with the
# milestones REST api.

milestones =

	setMilestone: (path, name, value) ->

		if not value?
			value = 1.0

		url = window.app_base_url + '/progress/' + path

		$.ajax(
			url: url
			type: 'PUT'
			data: 'value=' + value
			success: -> console.log('boogie')
			failure: -> console.log('failed to set milestone')
		)

	completeMilestone: (path, name) ->
		console.log 'called completeMilstone[' + path + ' , ' + name + ']'
		return @setMilestone(path, name, 1.0)

	resetMilestone: (path, name) ->
		return @setMilestone(path, name, 0.0)


root = window ? exports
root.lessonplan.milestones = milestones