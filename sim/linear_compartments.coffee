#<< common/sim/hh_rk
root = window ? exports
HHSimulationRK4 = root.HHSimulationRK4

class common.sim.LinearCompartmentModel

	constructor: (@nCompartments) ->

		@cIDs = [0..@nComparments-1]
		@compartments = (new HHSimulationRK4() for c in @cIDs)

		@R_a = 1.0

		@v = []
		@I = []

	# a hack to make bindings easier
	unpackArrays: ->
		for c in @cIDs
			this['v' + c] = @v[c]
			this['I' + c] = @I[c]

	reset:
		if @compartments?
			s.reset() for s in @compartments

	step: ->

		Iexts = []

		for c in @cIDs
			I = 0.0

			if c > 0
				I += @compartments[c - 1] / @R_a

			if c < @nCompartments
				I += @compartments[c + 1] / @R_a

			I -= 2 * @compartments[c] / @R_a

			@compartments.I_ext = I

		compartment.step() for compartment in @compartments

		@t = @compartments[0].t

		for c in @cIDs
			@v[c] = @compartments[c].v
			@I[c] = @compartments[c].I_ext