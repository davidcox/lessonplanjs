#<< common/properties


class common.sim.SquareWavePulseSim extends common.PropsEnabled

	constructor: ->
		@interval = @prop 3.0			# mS
		@amplitude = @prop 15			# uA
		@t = @prop 0.0, => @update()	# mS
		@I_stim = @prop 0.0				# uA


	update: ->
		[s, e]  = @interval()

		if @t() > s and @t() < e

			@I_stim(@amplitude())
		else
			@I_stim(0.0)

common.sim.SquareWavePulse = -> new common.sim.SquareWavePulseSim()