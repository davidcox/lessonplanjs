#<< mcb80x/properties


class mcb80x.sim.GHKSim extends mcb80x.PropsEnabled

    constructor: ->

        # Concentrations (mM)
        @Na_extra = @prop 0.0
        @Na_intra = @prop 0.0
        @K_extra = @prop 0.0
        @K_intra = @prop 0.0

        @Cl_extra = @prop 0.0
        @Cl_intra = @prop 0.0
        @Ca_extra = @prop 0.0
        @Ca_intra = @prop 0.0

        # Permeability (m/s)
        @P_Na = @prop 1.0
        @P_K = @prop 1.0
        @P_Cl = @prop 1.0
        @P_Ca = @prop 1.0

        # Temperature
        @T = @prop 310.0

        # Membrane Potential
        @E_m = @prop 0.0

        # Constants

        # Faraday's Constant
        @F = 96485.3365  # C / mol

        # Ideal Gas Constant
        @R = 8.3144621 # J / K • mol

        p.subscribe(=> @update()) for p in [@Na_extra,
                                            @Na_intra,
                                            @K_extra,
                                            @K_intra,
                                            @Cl_extra,
                                            @Cl_intra,
                                            @Ca_extra,
                                            @Ca_intra,
                                            @P_Na,
                                            @P_K,
                                            @P_Cl,
                                            @P_Ca,
                                            @T]
    update: ->

        numerator = (@P_Na() * @Na_extra() + @P_K() * @K_extra() +
                    @P_Cl() * @Cl_intra() + @P_Ca() * @Ca_extra())

        denominator = (@P_Na() * @Na_intra() + @P_K() * @K_intra() +
                    @P_Cl() * @Cl_extra() + @P_Ca() * @Ca_intra())

        v = (@R / @F) * @T() * Math.log( numerator / denominator )

        @E_m(v)


mcb80x.sim.GHK = -> new mcb80x.sim.GHKSim()