#<< mcb80x/properties


class mcb80x.sim.SquareWavePulseSim extends mcb80x.PropsEnabled

	constructor: ->
		@interval = @prop 3.0			# mS
		@amplitude = @prop 15			# uA
		@t = @prop 0.0, => @update()	# mS
		@I_stim = @prop 0.0				# uA
		@stimOn = @prop false

	update: ->
		[s, e]  = @interval()

		if @t() > s and @t() < e
			@I_stim(@amplitude())
			@stimOn(true)
		else
			@I_stim(0.0)
			@stimOn(false)

mcb80x.sim.SquareWavePulse = -> new mcb80x.sim.SquareWavePulseSim()
