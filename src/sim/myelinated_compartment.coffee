#<< common/sim/linear_compartment
#<< common/sim/passive_membrane

class MyelinatedLinearCompartmentModel extends LinearCompartmentModel

	constructor: (@nCompartments, @nNodes) ->


		interNodeDistance = (@nCompartments - @nNodes) / (@nNodes - 1)

		@nodeIndices = []

		@compartments = []
		for n in @nodeIDs
			@compartments.push(new HHSimulationRK4())
			@nodeIndices.push(@compartments.length - 1)
			for c in [0..interNodeDistance]
				@compartments.push(new PassiveMembrane())

		@compartments.push(new HHSimulationRK4())
		@nodeIndices.push(@compartments.length - 1)

		@t = @compartments[0].t

		@R_a = @prop 10.0

		@v = (0.0 for c in @cIDs)
		@I = (0.0 for c in @cIDs)

		for c in @cIDs
			this['v' + c] = @prop 0.0
			this['I' + c] = @prop 0.0

		@unpackArrays()


root = window ? exports
root.LinearCompartmentModel = LinearCompartmentModel