#<< properties


class sim.PassiveMembraneSim extends lessonplan.PropsEnabled

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
        @g_L = @prop 0.3                 # mS / cm^2


        # Resting Potential
        @V_rest = @prop 0.0                # mV

        # hack
        @V_offset = @prop -65.0

        # Reversal Potentials
        @E_L = @prop 10.6 + @V_rest()         # mV

        # Internal variables
        @defineProps ['I_L', 'g_L'], 0.0

        @v = @prop 0.0
        @t = @prop 0.0

        # External voltage clamp
        # this will force the voltage to some value
        @voltageClamped = @prop false

        @clampVoltage = @prop -65.0

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

        @state = @v()

        # Starting time for simulation
        @t(0.0)

    step: (stepCallback) ->

        # update the time
        @t(@t() + @dt())

        # Store these as locals for convenience (be careful!)
        t = @t()
        dt = @dt()


        # Euler term
        k1 = @ydot(t, @state)


        if @rk4

            k2 = @ydot(t + (dt / 2),
                       @state + (dt * k1 / 2))

            k3 = @ydot(t + dt / 2,
                       @state + (dt * k2 / 2))

            k4 = @ydot(t + dt,
                       @state + dt * k3)

            @state = @state + (dt / 6.0) * (k1 + 2*k2 + 2*k3 + k4)

        else
            # Euler's method (just use the first term, k1)
            @state = @state + dt * k1

        # unpack the state vector to make outputs accessible
        if @voltageClamped()
            # hold the voltage at the clamped level
            @v(@clampVoltage())
            console.log('clamped')
        else
            # update normally
            @v(@state + @V_offset())


        if isNaN(@v())
            @reset()
            console.log(@v())
            return

        if stepCallback?
            stepCallback()



    ydot: (t, s) ->
        # Compute the slope of the state vector
        # t: time, s: start state

        # Unpack the incoming state
        v = s

        # Currents
        @I_L (@g_L() * (v - @E_L()))

        dv = (@I_ext() + @I_a() - @I_L()) / @C_m()

        return dv

lessonplan.sim.PassiveMembrane = -> new lessonplan.sim.PassiveMembraneSim
