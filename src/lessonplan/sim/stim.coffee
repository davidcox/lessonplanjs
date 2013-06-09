#<< lessonplan/properties


class lessonplan.sim.SquareWavePulseSim extends lessonplan.PropsEnabled

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

lessonplan.sim.SquareWavePulse = -> new lessonplan.sim.SquareWavePulseSim()


class lessonplan.sim.CurrentPulseSim extends lessonplan.PropsEnabled

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



lessonplan.sim.CurrentPulse = -> new lessonplan.sim.CurrentPulseSim()