
class HHSimulationRK4

    constructor: ->

        # Stimulus
        @I_ext = 0.0               # uA / cm^2

        # Time Step
        @dt = 0.05                         # ms

        # Capacitance
        @C_m = 1.0                          # uF / cm^2

        # Peak Channel conductances
        @g_Na_max = 120                     # mS / cm^2
        @g_K_max = 36                       # mS / cm^2
        @g_L_max = 0.3                      # mS / cm^2

        # Reversal Potentials
        @E_Na = 115                         # mV
        @E_K = -12                          # mV
        @E_L = 10.6                         # mV

        # Resting Potential (a la H&H 1952)
        @V_rest = 0.0                       # mV


        # Internal variables (exposed in case we'd like to plot them)
        @I_Na = @I_K = @I_L = @g_Na = @g_K = @g_L = 0.0

        @reset()

        # Use Runga-Kutta
        @rk4 = true

    reset: ->
        # Starting (steady) sate
        # v: membrane potential
        # m: Na-channel activation gating variable
        # n: K-channel activation gating variable
        # h: Na-channel inactivation gating variable
        @v = @V_rest
        @m = @alphaM(@v) / (@alphaM(@v) + @betaM(@v))
        @n = @alphaN(@v) / (@alphaN(@v) + @betaN(@v))
        @h = @alphaH(@v) / (@alphaH(@v) + @betaH(@v))

        # Package into a vector for convenience
        @state = [@v, @m, @n, @h]

        # Starting time for simulation
        @t = 0.0

    unpackState: ->
        [@v, @m, @n, @h] = @state

        # hack:
        # shift the membrane V down to a physiologically realistic value
        # H & H fit everything assuming Em = 0.0
        @v -= 65.0


    step: (stepCallback) ->

        # update the time
        @t += @dt

        # Vector math in JS/CS is tedious; I've done it below as list comprehensions for
        # compactness's sake
        svars = [0..3] # indices over state variables, a shorthand/cut

        # Euler term
        k1 = @ydot(@t, @state)


        if @rk4

            k2 = @ydot(@t + (@dt / 2),
                       (@state[i] + (@dt * k1[i] / 2) for i in svars))

            k3 = @ydot(@t + @dt / 2,
                       (@state[i] + (@dt * k2[i] / 2) for i in svars))

            k4 = @ydot(@t + @timeStep,
                       (@state[i] + @dt * k3[i] for i in svars))

            @state = (@state[i] + (@dt / 6.0) * (k1[i] + 2*k2[i] + 2*k3[i] + k4[i]) for i in svars)

        else
            # Euler's method (just use the first term, k1)
            @state = (@state[i] + @dt * k1[i] for i in svars)

        @unpackState()

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
        @g_Na = @g_Na_max * Math.pow(m, 3) * h
        @g_K = @g_K_max * Math.pow(n, 4)
        @g_L = @g_L_max

        # Currents
        @I_Na = @g_Na * (v - @E_Na)
        @I_K = @g_K * (v - @E_K)
        @I_L = @g_L * (v - @E_L)

        dv = (@I_ext - @I_Na - @I_K - @I_L) / @C_m

        # Gating Variables
        dm = @alphaM(v) * (1.0 - m) - @betaM(v) * m
        dn = @alphaN(v) * (1.0 - n) - @betaN(v) * n
        dh = @alphaH(v) * (1.0 - h) - @betaH(v) * h

        dy = [dv, dm, dn, dh]
        return dy

# export this class
root = window ? exports
root.HHSimulationRK4 = HHSimulationRK4