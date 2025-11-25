module EVModel

using JuMP, Gurobi, CSV, DataFrames, DelimitedFiles

export makeparameters, makevariables, makeconstraints, makemodel, runmodel

include("$(@__DIR__)/gamshelpers.jl")
include("$(@__DIR__)/inputdata.jl")

function makevariables(model, params)
    (; timestep_all, trsp, priceareas, month) = params
       
    # Scalars needed for bounds (some are passed in params or defined here)
    # We need to pass Charge_Power and Batterysize from makeparameters or define them here.
    # I'll add them to makeparameters return values first.
    
    @variables model begin
        V_PEVcharging_slow[timestep_all, trsp, priceareas] >= 0
        V_PEV_storage[timestep_all, trsp, priceareas] >= 0
        V_PEV_need[timestep_all, trsp, priceareas] >= 0
        V_fuse[trsp, priceareas] >= 0
        V_power_monthly[month, trsp, priceareas] >= 0
        V_common_power[month, priceareas] >= 0
        V_maxF_all[month, priceareas] >= 0
        vtotcost
    end
    
    return (; V_PEVcharging_slow, V_PEV_storage, V_PEV_need, V_fuse, 
              V_power_monthly, V_common_power, V_maxF_all, vtotcost)
end

function makeconstraints(model, vars, params)
    (; timestep_all, trsp, priceareas, month, hours,
       battery_capacity_dict, residential_demand, eprice,
       EV_home, EV_demand, t2m, time_diff,
       TimestepsPerHour, NumberOfCars, DemandFactor) = params
       
    (; V_PEVcharging_slow, V_PEV_storage, V_PEV_need, V_fuse, 
       V_power_monthly, V_common_power, V_maxF_all, vtotcost) = vars
       
    # Constants
    Beff_EV = 0.95
    Batterysize = 70.0
    Price_fastcharge = 0.56
    kWhtokW = 4.0
    Charge_Power = 6.9 / kWhtokW
    Fuse_cost = 7.4
    ktoM = 1/1000
    
    # Cost flags (hardcoded based on GAMS defaults)
    Monthly_P_cost_ind = 0.0
    Monthly_P_cost_common = 0.0
    Annual_P_cost = 0.0
    
    # Bounds and Fixed values
    for t in timestep_all, car in trsp, area in priceareas
        # V_PEVcharging_slow.up = Charge_Power
        set_upper_bound(V_PEVcharging_slow[t, car, area], Charge_Power)
        
        # V_PEVcharging_slow.fx $ (not EV_home) = 0
        is_home = EV_home[t, car]
        if is_home == 0
            fix(V_PEVcharging_slow[t, car, area], 0.0; force=true)
        end
        
        # V_PEV_need.fx $ EV_home = 0
        if is_home == 1
            fix(V_PEV_need[t, car, area], 0.0; force=true)
        end
        
        # V_PEV_storage.up
        # RealBatteryCap = yes
        # GAMS default for parameter is 0. If car is not in file, capacity is 0.
        cap = battery_capacity_dict[car]
        set_upper_bound(V_PEV_storage[t, car, area], cap)
    end
    
    # EQU_totcost
    @constraint(model, EQU_totcost,
        vtotcost == 
        sum(V_PEV_need[t, c, a] * Price_fastcharge for t in timestep_all, c in trsp, a in priceareas) +
        sum(V_PEVcharging_slow[t, c, a] * ktoM * eprice[t, a] for t in timestep_all, c in trsp, a in priceareas) +
        sum(V_fuse[c, a] * Annual_P_cost for c in trsp, a in priceareas) +
        sum(V_power_monthly[m, c, a] * Monthly_P_cost_ind for m in month, c in trsp, a in priceareas) +
        sum(V_common_power[m, a] * Monthly_P_cost_common for m in month, a in priceareas)
    )
    
    # EQU_EVstoragelevel
    # V_PEV_storage(timestep++1, ...) = ...
    # We need to handle the circularity or end condition. GAMS "++1" usually wraps around or goes to next.
    # If it's a dynamic set, it might drop the last one.
    # Usually in GAMS t++1 for the last element is empty or wraps if circular.
    # "timestep(timestep_all) /t00001*t35040/"
    # It's a linear set. t++1 for t35040 is likely nothing.
    # But the equation is defined for `timestep`.
    # If I write `V_PEV_storage[t+1] == ...`, I need to handle t=end.
    # Let's assume t=1 is initial state, and we define balance for t=1 to T-1?
    # Or t=1 is result of previous?
    # GAMS: V_PEV_storage(t+1) = V_PEV_storage(t) + ...
    # This defines storage at t+1 based on t.
    # So for t=Last, it defines storage at Last+1 (which doesn't exist in variable).
    # Unless V_PEV_storage is defined over timestep_all and the equation is over timestep (same set).
    # If GAMS ignores the equation for the last timestep, I should too.
    # Or maybe it wraps to t1?
    # "timestep++1" is the next element.
    # I will iterate t from 1 to T-1.
    
    # Also need to handle indices for vectors.    
    @constraint(model, EQU_EVstoragelevel[(i,t) in enumerate(timestep_all), c in trsp, a in priceareas],
        V_PEV_storage[t == timestep_all[end] ? timestep_all[1] : timestep_all[i+1], c, a] ==
        V_PEV_storage[t, c, a] + 
        V_PEVcharging_slow[t, c, a] * Beff_EV * EV_home[t, c] + EV_demand[t, c] * DemandFactor +
        V_PEV_need[t, c, a] * Beff_EV * (1 - EV_home[t, c])
    )
    
    # Initial storage condition? GAMS doesn't specify. Usually free or fixed to something.
    # Or maybe cyclic?
    # If not specified, JuMP variables start at 0 (if lower bound 0).
    # I'll leave it as is.
    
    # EQU_fuse_need
    # Optimize by iterating indices
    @constraint(model, EQU_fuse_need[i in 1:length(timestep_all), c in trsp, a in priceareas],
        (V_PEVcharging_slow[timestep_all[i], c, a] * kWhtokW + residential_demand[i]/1000) * time_diff[timestep_all[i]] <= V_fuse[c, a]
    )
    
    # EQU_month_p_need
    @constraint(model, EQU_month_p_need[i in 1:length(timestep_all), c in trsp, a in priceareas],
        (V_PEVcharging_slow[timestep_all[i], c, a] * kWhtokW + residential_demand[i]/1000) * time_diff[timestep_all[i]] <= 
        V_power_monthly[t2m[timestep_all[i]], c, a]
    )
    
    # EQU_common_power
    @constraint(model, EQU_common_power[i in 1:length(timestep_all), a in priceareas],
        (sum(V_PEVcharging_slow[timestep_all[i], c, a] for c in trsp) * kWhtokW + residential_demand[i]/1000 * NumberOfCars) * time_diff[timestep_all[i]] <=
        V_common_power[t2m[timestep_all[i]], a]
    )
    
    return (; EQU_totcost, EQU_EVstoragelevel, EQU_fuse_need, EQU_month_p_need, EQU_common_power)
end

function makemodel()
    # Use Gurobi to match GAMS. Switch to HiGHS.Optimizer if Gurobi is not available.
    model = Model(Gurobi.Optimizer)
    # set_optimizer_attribute(model, "OutputFlag", 0)
    
    params = makeparameters()
    vars = makevariables(model, params)
    constraints = makeconstraints(model, vars, params)
    
    @objective(model, Min, vars.vtotcost)
    
    return model, params, vars, constraints
end

function runmodel()
    model, params, vars, constraints = makemodel()
    optimize!(model)
    println("Objective value: ", objective_value(model))
    
    write_results(params, vars)
    
    println("Done.")
    return nothing
end

function write_results(params, vars)
    (; timestep_all, trsp, priceareas, month, t2m, residential_demand, NumberOfCars) = params
    (; V_PEVcharging_slow) = vars
    
    kWhtokW = 4.0 # Hardcoded as in makeconstraints
    
    # Calculate Monthly_fuse_common
    # smax(timestep$(maptimestep2month(timestep, month)), sum(trsp, V_PEVcharging_slow...))
    Monthly_fuse_common = Dict{Tuple{String, String}, Float64}()
    
    # Pre-compute timesteps per month for efficiency
    ts_in_month = Dict(m => Int[] for m in month)
    for (i, t) in enumerate(timestep_all)
        m = t2m[t]
        push!(ts_in_month[m], i)
    end
    
    for m in month, a in priceareas
        max_val = 0.0
        for i in ts_in_month[m]
            t = timestep_all[i]
            val = sum(value(V_PEVcharging_slow[t, c, a]) for c in trsp) * kWhtokW + residential_demand[i]/1000 * NumberOfCars
            if val > max_val
                max_val = val
            end
        end
        Monthly_fuse_common[(m, a)] = max_val
    end
    
    # Calculate Monthly_fuse_ind
    Monthly_fuse_ind = Dict{Tuple{String, String, String}, Float64}()
    for m in month, a in priceareas, c in trsp
        max_val = 0.0
        for i in ts_in_month[m]
            t = timestep_all[i]
            val = value(V_PEVcharging_slow[t, c, a]) * kWhtokW + residential_demand[i]/1000
            if val > max_val
                max_val = val
            end
        end
        Monthly_fuse_ind[(m, a, c)] = max_val
    end
    
    # Export to CSV
    println("Exporting results...")
    
    # Helper to write Dict to CSV
    function write_dict_csv(filename, d, headers)
        open(filename, "w") do io
            println(io, join(headers, ","))
            for (k, v) in d
                # k is a tuple, flatten it
                println(io, join([k..., v], ","))
            end
        end
    end
    
    write_dict_csv("Monthly_fuse_common.csv", Monthly_fuse_common, ["Month", "PriceArea", "Value"])
    write_dict_csv("Monthly_fuse_ind.csv", Monthly_fuse_ind, ["Month", "PriceArea", "Car", "Value"])
    
    # Export V_PEVcharging_slow
    # This is large, maybe use DataFrame
    # Format: Timestep, Car, PriceArea, Value
    open("V_PEVcharging_slow.csv", "w") do io
        println(io, "Timestep,Car,PriceArea,Value")
        for t in timestep_all, c in trsp, a in priceareas
            v = value(V_PEVcharging_slow[t, c, a])
            if v > 1e-6 # Sparse export
                println(io, "$t,$c,$a,$v")
            end
        end
    end
end

end # module
