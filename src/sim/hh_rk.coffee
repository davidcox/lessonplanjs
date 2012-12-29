#<< common/properties


class common.sim.HHSimulationRK4 extends common.PropsEnabled

    constructor: ->

        # Stimulus
        @I_ext = @prop 0.0                   # uA / cm^2

        # Axial currents (if any)
        @I_a = @prop 0.0

        # Time step
        @dt = @prop 0.05                     # ms

        # Capacitance
        @C_m = @prop 1.0                     # uF / cm^2

        # Channel conductances
        @gbar_Na = @prop 120                # mS / cm^2
        @gbar_K = @prop 36                  # mS / cm^2
        @gbar_L = @prop 0.3                 # mS / cm^2


        # Resting Potential
        @V_rest = @prop 0.0                # mV

        # hack
        @V_offset = @prop -65.0

        # Reversal Potentials
        @E_Na = @prop 115 + @V_rest()         # mV
        @E_K = @prop -12 + @V_rest()          # mV
        @E_L = @prop 10.6 + @V_rest()         # mV


        # Internal variables
        @defineProps ['I_Na', 'I_K', 'I_L', 'g_Na', 'g_K', 'g_L'], 0.0

        @defineProps ['v', 'm', 'n', 'h', 't'], 0.0

        @reset()

        # Use Runga-Kutta
        @rk4 = true

    reset: ->
        # Starting (steady) sate
        # v: membrane potential
        # m: Na-channel activation gating variable
        # n: K-channel activation gating variable
        # h: Na-channel inactivation gating variable
        @v(@V_rest())

        v_ = @v()
        @m(@alphaM(v_) / (@alphaM(v_) + @betaM(v_)))
        @n(@alphaN(v_) / (@alphaN(v_) + @betaN(v_)))
        @h(@alphaH(v_) / (@alphaH(v_) + @betaH(v_)))

        @state = [@v(), @m(), @n(), @h()]

        # Starting time for simulation
        @t(0.0)

    step: (stepCallback) ->

        # update the time
        @t(@t() + @dt())

        # Store these as locals for convenience (be careful!)
        t = @t()
        dt = @dt()

        # Vector math in JS/CS is tedious; I've done it below as list comprehensions for
        # compactness's sake
        svars = [0..3] # indices over state variables, a shorthand/cut


        # Euler term
        k1 = @ydot(t, @state)


        if @rk4

            k2 = @ydot(t + (dt / 2),
                       (@state[i] + (dt * k1[i] / 2) for i in svars))

            k3 = @ydot(t + dt / 2,
                       (@state[i] + (dt * k2[i] / 2) for i in svars))

            k4 = @ydot(t + dt,
                       (@state[i] + dt * k3[i] for i in svars))

            @state = (@state[i] + (dt / 6.0) * (k1[i] + 2*k2[i] + 2*k3[i] + k4[i]) for i in svars)

        else
            # Euler's method (just use the first term, k1)
            @state = (state[i] + dt * k1[i] for i in svars)

        # unpack the state vector to make outputs accessible
        @v(@state[0] + @V_offset())
        @m(@state[1])
        @n(@state[2])
        @h(@state[3])

        if stepCallback?
            stepCallback()


    # Na channel activation
    alphaM: (v) ->
        0.1 * (25.0 - v) / (Math.exp(2.5 - 0.1 * v) - 1.0)

    betaM: (v) ->
        4 * Math.exp(-1 * v / 18.0)


    # K channel
    alphaN: (v) ->
        0.01 * (10 - v) / (Math.exp(1.0 - 0.1 * v) - 1.0)

    betaN: (v) ->
        0.125 * Math.exp(-v / 80.0)

    # Na channel inactivation
    alphaH: (v) ->
        0.07 * Math.exp(-v / 20.0)

    betaH: (v) ->
        1.0 / (Math.exp(3.0 - 0.1 * v) + 1.0)


    ydot: (t, s) ->
        # Compute the slope of the state vector
        # t: time, s: start state

        # Unpack the incoming state
        [v, m, n, h] = s

        # Conductances
        @g_Na (@gbar_Na() * Math.pow(m, 3) * h)
        @g_K  (@gbar_K() * Math.pow(n, 4))
        @g_L  (@gbar_L())

        # Currents
        @I_Na (@g_Na() * (v - @E_Na()))
        @I_K (@g_K() * (v - @E_K()))
        @I_L (@g_L() * (v - @E_L()))

        dv = (@I_ext() + @I_a() - @I_Na() - @I_K() - @I_L()) / @C_m()

        # Gating Variables
        dm = @alphaM(v) * (1.0 - m) - @betaM(v) * m
        dn = @alphaN(v) * (1.0 - n) - @betaN(v) * n
        dh = @alphaH(v) * (1.0 - h) - @betaH(v) * h

        dy = [dv, dm, dn, dh]
        return dy

common.sim.HodgkinHuxleyNeuron = -> new common.sim.HHSimulationRK4()
