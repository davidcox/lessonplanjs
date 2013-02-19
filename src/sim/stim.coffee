#<< mcb80x/properties


class mcb80x.sim.SquareWavePulseSim extends mcb80x.PropsEnabled

	constructor: ->
		@interval = @prop 5.0			# mS
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


class mcb80x.sim.CurrentPulseSim extends mcb80x.PropsEnabled

	constructor: ->
		@amplitude = @prop 15			# uA
		@I_stim = @prop 0.0				# uA
		@stimOn = @prop false
		@minDuration = @prop 5.0		# ms

		@stimLocked = @prop false
		@stimLockTime = 0.0

		@t = @prop 0.0, => @update()


	update: ->
		if @stimLocked() and (@t() - @stimLockTime) > @minDuration()
			@stimLocked(false)
			console.log('unlocked')

		if @stimOn() or @stimLocked()
			if not @stimLocked()
				@stimLocked(true)
				@stimLockTime = @t()
				console.log('locked')
			@I_stim(@amplitude())
		else
			@I_stim(0.0)



mcb80x.sim.CurrentPulse = -> new mcb80x.sim.CurrentPulseSim()