
class SquareWavePulse

	constructor: (@interval, @amplitude) ->
		@t = 0.0
		@I_stim = 0.0


	update: ->
		if @t > @interval[0] and @t < @interval[1]

			@I_stim = @amplitude
		else
			@I_stim = 0.0

root = window ? exports
root.SquareWavePulse = SquareWavePulse