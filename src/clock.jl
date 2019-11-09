#
# simulation routines for discrete event simulation
#


"""
    setUnit!(sim::Clock, new::FreeUnits)
set a clock to a new time unit in `Unitful`. If necessary convert
current clock times to the new unit.
# Arguments
- `sim::Clock`
- `new::FreeUnits`: new is one of `ms`, `s`, `minute` or `hr` or another Unitful
`Time` unit.
# Examples
```jldoctest
julia> using Simulate, Unitful

julia> import Unitful: Time, s, minute, hr

julia> c = Clock(t0=60) # setup a new clock with t0=60
Clock: state=Simulate.Undefined(), time=60.0, unit=, events: 0, processes: 0, sampling: 0, sample rate Δt=0.0
julia> τ(c) # current time is 60.0 NoUnits
60.0
julia> setUnit!(c, s)  # set clock unit to Unitful.s
60.0 s
julia> τ(c) # current time is now 60.0 s
60.0 s
julia> setUnit!(c, minute)  # set clock unit to Unitful.minute
1.0 minute
julia> τ(c) # current time is now 1.0 minute
1.0 minute
julia> typeof(τ(c))  # τ(c) now returns a time Quantity ...
Quantity{Float64,𝐓,Unitful.FreeUnits{(minute,),𝐓,nothing}}
julia> isa(τ(c), Time)
true
julia> uconvert(s, τ(c)) # ... which can be converted to other time units
60.0 s
julia> τ(c).val  # it has a value of 1.0
1.0
julia> c.time  # internal clock time is set to 1.0 (is a Float64)
1.0
julia> c.unit  # internal clock unit is set to Unitful.minute
minute
```
"""
function setUnit!(sim::Clock, new::FreeUnits)
    if isa(1new, Time)
        if sim.unit == new
            println("clock is already set to $new")
        elseif sim.unit == NoUnits
            sim.unit = new
        else
            old = sim.unit
            sim.unit = new
            fac = uconvert(new, 1*old).val
            sim.time *= fac
            sim.end_time *= fac
            sim.tev *= fac
            sim.Δt *= fac
            sim.tsa *= fac
        end
    else
        sim.unit = NoUnits
    end
    τ(sim)
end

"""
```
𝐶
Clk
```
italic 𝐶 (`\\itC`+Tab) or `Clk` is the central `Clock()`-variable, which
normally is sufficient for simulation purposes.
# Examples
```jldoctest
julia> using Simulate

julia> reset!(𝐶)
"clock reset to t₀=0.0, sampling rate Δt=0.0."
julia> 𝐶  # central clock
Clock: state=Simulate.Idle(), time=0.0, unit=, events: 0, processes: 0, sampling: 0, sample rate Δt=0.0
julia> Clk  # alias
Clock: state=Simulate.Idle(), time=0.0, unit=, events: 0, processes: 0, sampling: 0, sample rate Δt=0.0
julia> 𝐶.time
0.0
```
"""
𝐶 = Clk = Clock()

"""
```
τ(sim::Clock=𝐶)
tau(sim::Clock=Tau)
```
Return the current simulation time (τ=\tau+Tab).
# Examples
```jldoctest
julia> using Simulate

julia> reset!(𝐶)
"clock reset to t₀=0.0, sampling rate Δt=0.0."
julia> τ() # gives the central time
0.0
julia> tau() # alias, gives the central time
0.0
```
"""
τ(sim::Clock=𝐶) = sim.time*sim.unit
tau = τ

"""
```
sync!(sim::Clock, to::Clock=𝐶)
```
Force a synchronization of two clocks. Change all registered times of
`sim` accordingly. Convert or force sim.unit to to.unit.
"""
function sync!(sim::Clock, to::Clock=𝐶)
    if (sim.unit == NoUnits) | (sim.unit == to.unit)
        fac = 1
    elseif to.unit == NoUnits
        println(stderr, "Warning: deleted time unit without conversion")
        fac = 1
    else
        fac = uconvert(to.unit, 1sim.unit).val
    end
    Δt = to.time - sim.time*fac
    sim.time = sim.time*fac + Δt
    sim.unit = to.unit
    sim.tsa  = sim.tsa*fac + Δt
    sim.tev  = sim.tev*fac + Δt
    sim.end_time = sim.end_time*fac + Δt
    sim.Δt = to.Δt
    evq = PriorityQueue{SimEvent,Float64}()
    for (ev, t) ∈ pairs(sim.events)
        evq[ev] = t*fac + Δt
    end
    sim.events = evq
    sim
end

"""
```
reset!(sim::Clock, Δt::Number=0; t0::Number=0, hard::Bool=true, unit=NoUnits)
```
reset a clock
# Arguments
- `sim::Clock`
- `Δt::Number=0`: time increment
- `t0::Float64=0` or `t0::Time`: start time
- `hard::Bool=true`: time is reset, all scheduled events and sampling are
deleted. If hard=false, then only time is reset, event and
sampling times are adjusted accordingly.
- `unit=NoUnits`: the Time unit for the clock after reset. If a `Δt::Time` is
given, its Time unit goes into the clock Time unit. If only t0::Time is given,
its Time unit goes into the clock time unit.
# Examples
```jldoctest
julia> using Simulate, Unitful

julia> import Unitful: s

julia> c = Clock(1s, t0=60s)
Clock: state=Simulate.Undefined(), time=60.0, unit=s, events: 0, processes: 0, sampling: 0, sample rate Δt=1.0
julia> reset!(c)
"clock reset to t₀=0.0, sampling rate Δt=0.0."
julia> c
Clock: state=Simulate.Idle(), time=0.0, unit=, events: 0, processes: 0, sampling: 0, sample rate Δt=0.0
```
"""
function reset!(sim::Clock, Δt::Number=0;
                t0::Number=0, hard::Bool=true, unit=NoUnits)
    if  isa(1unit, Time)
        Δt = isa(Δt, Time) ? uconvert(unit, Δt).val : Δt
        t0 = isa(t0, Time) ? uconvert(unit, t0).val : t0
    elseif isa(Δt, Time)
        unit = Unitful.unit(1Δt)
        Δt = Δt.val
        t0 = isa(t0, Time) ? uconvert(unit, t0).val : t0
    elseif isa(t0, Time)
        unit = Unitful.unit(t0)
        t0 = t0.val
    else
        nothing
    end
    if hard
        sim.state = Idle()
        sim.time = t0
        sim.unit = unit
        sim.tsa = t0
        sim.tev = t0
        sim.end_time = t0
        sim.evcount = 0
        sim.Δt = Δt
        sim.events = PriorityQueue{SimEvent,Float64}()
        sim.processes = Dict{Any, SimProcess}()
    else
        sync!(sim, Clock(Δt, t0=t0, unit=unit))
    end
    "clock reset to t₀=$(float(t0*unit)), sampling rate Δt=$(float(Δt*unit))."
end

"""
    nextevent(sim::Clock)
Return the next scheduled event.
"""
nextevent(sim::Clock) = peek(sim.events)[1]

"""
    nextevtime(sim::Clock)
Return the internal time (unitless) of next scheduled event.
"""
nextevtime(sim::Clock) = peek(sim.events)[2]

"""
    simExec(ex::Union{Expr,SimFunction}, m::Module=Main)
evaluate an expression or execute a SimFunction.
"""
function simExec(ex::Union{Expr,SimFunction}, m::Module=Main)
    if isa(ex, SimFunction)
        ex.func(ex.arg...; ex.kw...)
        yield()  # to an eventually triggered process
    else
        Core.eval(m,ex)
    end
end

"""
    checktime(sim::Clock, t::Number)::Float64
check `t` given according to clock settings and return value
"""
function checktime(sim::Clock, t::Number)::Float64
    if isa(t, Real)
        return t
    else
        if sim.unit == NoUnits
            println(stderr, "Warning: clock has no time unit, ignoring units")
            return t.val
        else
            return uconvert(sim.unit, t).val
        end
    end
end

"""
```
event!(sim::Clock, ex::Union{Expr, SimFunction}, t::Number; scope::Module=Main, cycle::Number=0.0)::Float64
event!(sim::Clock, ex::Union{Expr, SimFunction}, T::Timing, t::Number; scope::Module=Main)::Float64
```
Schedule a function or expression for a given simulation time.
# Arguments
- `sim::Clock`: simulation clock
- `ex::{Expr, SimFunction}`: an expression or SimFunction
- `t::Float64` or `t::Time`: simulation time
- `T::Timing`: a timing, `at`, `after` or `every` (`before` behaves like `at`)
- `scope::Module=Main`: scope for the expression to be evaluated
- `cycle::Float64=0.0`: repeat cycle time for the event
# returns
Scheduled internal simulation time (unitless) for that event.
May return a time `> t` from repeated applications of `nextfloat(t)`
if there are events scheduled for `t`.
# Examples
```jldoctest
julia> using Simulate, Unitful

julia> import Unitful: s, minute, hr

julia> myfunc(a, b) = a+b
myfunc (generic function with 1 method)
julia> event!(𝐶, SimFunction(myfunc, 1, 2), 1) # a 1st event
1.0
julia> event!(𝐶, SimFunction(myfunc, 2, 3), 1) #  a 2nd event to the same time
1.0000000000000002
julia> event!(𝐶, SimFunction(myfunc, 3, 4), 1s)
Warning: clock has no time unit, ignoring units
1.0000000000000004
julia> setUnit!(𝐶, s)
0.0 s
julia> event!(𝐶, SimFunction(myfunc, 4, 5), 1minute)
60.0
julia> event!(𝐶, SimFunction(myfunc, 5, 6), after, 1hr)
3600.0
julia> 𝐶
Clock: state=Simulate.Idle(), time=0.0, unit=s, events: 5, processes: 0, sampling: 0, sample rate Δt=0.0
julia> run!(𝐶, 1hr)
"run! finished with 5 events, simulation time: 3600.0"
```
"""
function event!(sim::Clock, ex::Union{Expr, SimFunction}, t::Number;
                scope::Module=Main, cycle::Number=0.0)::Float64
    t = checktime(sim, t)
    cycle = checktime(sim, cycle)
    while any(i->i==t, values(sim.events)) # in case an event at that time exists
        t = nextfloat(float(t))                  # increment scheduled time
    end
    ev = SimEvent(ex, scope, t, cycle)
    sim.events[ev] = t
    return t
end
function event!(sim::Clock, ex::Union{Expr, SimFunction}, T::Timing,
                t::Number; scope::Module=Main)
    t = checktime(sim, t)
    if T == after
        event!(sim, ex, t + sim.time, scope=scope)
    elseif T == every
        event!(sim, ex, sim.time, scope=scope, cycle=t)
    else
        event!(sim, ex, t, scope=scope)
    end
end

"""
    sample_time!(sim::Clock, Δt::Number)
set the clock's sampling time starting from now (`τ(sim)`).
# Arguments
- `sim::Clock`
- `Δt::Number`: sample rate, time interval for sampling
"""
function sample_time!(sim::Clock, Δt::Number)
    sim.Δt = checktime(sim, Δt)
    sim.tsa = sim.time + sim.Δt
end

"""
    sample!(sim::Clock, ex::Union{Expr, SimFunction}; scope::Module=Main)
enqueue an expression for sampling.
# Arguments
- `sim::Clock`
- `ex::Union{Expr, SimFunction}`: an expression or function
- `scope::Module=Main`: optional, a scope for the expression to be evaluated in
"""
sample!(sim::Clock, ex::Union{Expr, SimFunction}; scope::Module=Main) =
                            push!(sim.sexpr, Sample(ex, scope))

"""
    step!(sim::Clock, ::Undefined, ::Init)
initialize a clock.
"""
function step!(sim::Clock, ::Undefined, ::Init)
    sim.state = Idle()
end

"""
    step!(sim::Clock, ::Undefined, σ::Union{Step,Run})
if uninitialized, initialize and then Step or Run.
"""
function step!(sim::Clock, ::Undefined, σ::Union{Step,Run})
    step!(sim, sim.state, Init(0))
    step!(sim, sim.state, σ)
end

"""
    setTimes(sim::Clock)

set clock times for next event or sampling action. The internal clock times
`sim.tev` and `sim.tsa` must always be set to be at least `sim.time`.
"""
function setTimes(sim::Clock)
    if length(sim.events) ≥ 1
        sim.tev = nextevtime(sim)
        sim.tsa = sim.Δt > 0 ? sim.time + sim.Δt : sim.time
    else
        sim.tsa = sim.Δt > 0 ? sim.time + sim.Δt : sim.time
        sim.tev = sim.tsa
    end
end

"""
    step!(sim::Clock, ::Union{Idle,Busy,Halted}, ::Step)
step forward to next tick or scheduled event.
At a tick evaluate all sampling expressions, or, if an event is encountered
evaluate the event expression.

The internal clock times `sim.tev` and `sim.tsa` must always be set to be
at least `sim.time`.
"""
function step!(sim::Clock, ::Union{Idle,Busy,Halted}, ::Step)

    function exec_next_event()
        sim.time = sim.tev
        ev = dequeue!(sim.events)
        simExec(ev.ex, ev.scope)
        sim.evcount += 1
        if ev.Δt > 0.0  # schedule repeat event
            event!(sim, ev.ex, sim.time + ev.Δt, scope=ev.scope, cycle=ev.Δt)
        end
        sim.tev = length(sim.events) ≥ 1 ? nextevtime(sim) : sim.time
    end

    function exec_next_tick()
        sim.time = sim.tsa
        for s ∈ sim.sexpr
            simExec(s.ex, s.scope)
        end
    end

    if (sim.tev ≤ sim.time) && (length(sim.events) ≥ 1)
        sim.tev = nextevtime(sim)
    end

    if (length(sim.events) ≥ 1) | (sim.Δt > 0)
        if length(sim.events) ≥ 1
            if (sim.Δt > 0)
                if sim.tsa <= sim.tev
                    exec_next_tick()
                    if sim.tsa == sim.tev
                        exec_next_event()
                    end
                    sim.tsa += sim.Δt
                else
                    exec_next_event()
                end
            else
                exec_next_event()
                sim.tsa = sim.time
            end
        else
            exec_next_tick()
            sim.tsa += sim.Δt
            sim.tev = sim.time
        end
    else
        println(stderr, "step!: nothing to evaluate")
    end
    length(sim.processes) == 0 || sleep(0.01) # let processes run
end

"""
    step!(sim::Clock, ::Idle, σ::Run)
Run a simulation for a given duration.
The duration is given with `Run(duration)`. Call scheduled events and evaluate
sampling expressions at each tick in that timeframe.
"""
function step!(sim::Clock, ::Idle, σ::Run)
    sim.end_time = sim.time + σ.duration
    sim.evcount = 0
    sim.state = Busy()
    setTimes(sim)
    while any(i->(sim.time < i ≤ sim.end_time), (sim.tsa, sim.tev))
        step!(sim, sim.state, Step())
        if sim.state == Halted()
            return
        end
    end
    tend = sim.end_time

    # catch remaining events
    while (length(sim.events) ≥ 1) && (sim.tev ≤ tend + Base.eps(tend)*10)
        step!(sim, sim.state, Step())
        tend = nextfloat(tend)
    end

    sim.time = sim.end_time
    sim.state = Idle()
    sleep(0.1)
    "run! finished with $(sim.evcount) events, simulation time: $(sim.time)"
end

"""
    step!(sim::Clock, ::Busy, ::Stop)
Stop the clock.
"""
function step!(sim::Clock, ::Busy, ::Stop)
    sim.state = Halted()
    "Halted after $(sim.evcount) events, simulation time: $(sim.time)"
end

"""
    step!(sim::Clock, ::Halted, ::Resume)
Resume a halted clock.
"""
function step!(sim::Clock, ::Halted, ::Resume)
    sim.state = Idle()
    step!(sim, sim.state, Run(sim.end_time - sim.time))
end

"""
    step!(sim::Clock, q::SState, σ::SEvent)
catch all step!-function.
"""
function step!(sim::Clock, q::SState, σ::SEvent)
    println(stderr, "Warning: undefined transition ",
            "$(typeof(sim)), ::$(typeof(q)), ::$(typeof(σ)))\n",
            "maybe, you should reset! the clock!")
end

"""
    run!(sim::Clock, duration::Number)
Run a simulation for a given duration.
Call scheduled events and evaluate sampling expressions at each tick
in that timeframe.
"""
run!(sim::Clock, duration::Number) =
                        step!(sim, sim.state, Run(checktime(sim, duration)))


"""
    incr!(sim::Clock)
Take one simulation step, execute the next tick or event.
"""
incr!(sim::Clock) = step!(sim, sim.state, Step())

"""
    stop!(sim::Clock)
Stop a running simulation.
"""
stop!(sim::Clock) = step!(sim, sim.state, Stop())

"""
    resume!(sim::Clock)
Resume a halted simulation.
"""
resume!(sim::Clock) = step!(sim, sim.state, Resume())

"""
    init!(sim::Clock)
initialize a clock.
"""
init!(sim::Clock) = step!(sim, sim.state, Init(""))