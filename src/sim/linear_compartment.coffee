#<< mcb80x/properties
#<< mcb80x/sim/hh_rk

class mcb80x.sim.LinearCompartmentModelSim extends mcb80x.PropsEnabled


	constructor: (@nCompartments) ->

		@cIDs = [0..@nCompartments-1]
		@compartments = (mcb80x.sim.HodgkinHuxleyNeuron() for c in @cIDs)

		# Tie all compartments to a global membrane capacitance property
		@C_m = @prop 1.1
		for c in @compartments
			c.C_m = @C_m

		@t = @compartments[0].t

		@R_a = @prop 2.0

		@v = @prop (0.0 for c in @cIDs)
		@I = @prop (0.0 for c in @cIDs)

		for c in @cIDs
			this['v' + c] = @prop 0.0
			this['I' + c] = @prop 0.0

		@unpackArrays()

	# a hack to make bindings easier
	unpackArrays: ->
		vs = @v()
		Is = @I()
		for c in @cIDs
			this['v' + c](vs[c])
			this['I' + c](Is[c])

	reset: ->
		if @compartments?
			s.reset() for s in @compartments

	step: ->

		Iexts = []

		v_rest = (@compartments[0].V_rest() +
				  @compartments[0].V_offset())

		for c in @cIDs
			I = 0.0

			if c > 0
				I += @compartments[c - 1].v() / @R_a()
			else
				I += v_rest / @R_a()

			if c < @nCompartments - 1
				I += @compartments[c + 1].v() / @R_a()
			else
				I += v_rest / @R_a()

			I -= 2 * @compartments[c].v() / @R_a()

			@compartments[c].I_a(I)

		compartment.step() for compartment in @compartments

		# @t = @compartments[0].t

		vs = @v()
		Is = @I()
		for c in @cIDs
			vs[c] = @compartments[c].v()
			Is[c] = @compartments[c].I_ext()

		@unpackArrays()

mcb80x.sim.LinearCompartmentModel = (c) -> new mcb80x.sim.LinearCompartmentModelSim(c)
