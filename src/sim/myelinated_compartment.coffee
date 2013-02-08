#<< mcb80x/sim/linear_compartment
#<< mcb80x/sim/passive_membrane

class mcb80x.sim.MyelinatedLinearCompartmentModelSim extends mcb80x.PropsEnabled

    constructor: (@nCompartments, @nNodes) ->

        interNodeDistance = (@nCompartments - @nNodes) / (@nNodes - 1)
        @nodes = []
        @internodes = []

        # A global capacitance for the passive nodes
        @C_internode = @prop 1.1
        @C_node = @prop 2.0
        @passiveNodes = @prop false
        @passiveInternodes = @prop true

        @compartments = []
        for n in [1..@nNodes]
            # add a "node"
            node = new mcb80x.sim.HHSimulationRK4()
                .C_m(@C_node)
                .passiveMembrane(@passiveNodes)

            @nodes.push(node)
            @compartments.push(node)

            # add a span of "internodes"
            if n < @nNodes
                for c in [1..interNodeDistance]
                    internode = new mcb80x.sim.HHSimulationRK4()
                        .C_m(@C_internode)
                        .passiveMembrane(@passiveInternodes)

                    @internodes.push(internode)
                    @compartments.push(internode)


        @t = @compartments[0].t

        @R_a = @prop 1.0

        @nCompartments = @compartments.length
        console.log('nCompartments: ' + @nCompartments)

        @cIDs = [0..@nCompartments-1]

        @v = @prop (0.0 for c in @cIDs)
        @I = @prop (0.0 for c in @cIDs)

        for c in @cIDs
            this['v' + c] = @prop 0.0
            this['I' + c] = @prop 0.0

        @unpackArrays()

    # a hack to make bindings easier
    unpackArrays: ->
        for c in @cIDs
            this['v' + c](@v()[c])
            this['I' + c](@I()[c])

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

mcb80x.sim.MyelinatedLinearCompartmentModel = (c, n) -> new mcb80x.sim.MyelinatedLinearCompartmentModelSim(c,n)