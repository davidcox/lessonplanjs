#<< common/sim/hh_rk
HHSimulationRK4 = common.sim.HHSimulationRK4

class common.sim.LinearCompartmentModel

	constructor: (@nCompartments) ->

		@cIDs = [0..@nCompartments-1]
		@compartments = ((new HHSimulationRK4()) for c in @cIDs)

		@t = @compartments[0].t

		@R_a = 10.0

		@v = (0.0 for c in @cIDs)
		@I = (0.0 for c in @cIDs)


		@unpackArrays()

	# a hack to make bindings easier
	unpackArrays: ->
		for c in @cIDs
			this['v' + c] = @v[c]
			this['I' + c] = @I[c]

	reset: ->
		if @compartments?
			s.reset() for s in @compartments

	step: ->

		console.log('R_a: ' + @R_a)
		Iexts = []

		v_rest = @compartments[0].V_rest

		for c in @cIDs
			I = 0.0

			if c > 0
				I += @compartments[c - 1].v / @R_a
			else
				I += v_rest / @R_a

			if c < @nCompartments - 1
				I += @compartments[c + 1].v / @R_a
			else
				I += v_rest / @R_a

			I -= 2 * @compartments[c].v / @R_a

			@compartments[c].I_a = I

		compartment.step() for compartment in @compartments

		@t = @compartments[0].t

		for c in @cIDs
			@v[c] = @compartments[c].v
			@I[c] = @compartments[c].I_ext

		@unpackArrays()

root.LinearCompartmentModel = LinearCompartmentModel