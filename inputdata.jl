function makeparameters(hh_profile, flags)
    (; Monthly_Power_Cost, Common_Power_Cost, Annual_Power_Cost) = flags

    println("Loading parameters...")
    
    # Scalars
    TimestepsPerHour = 4 # 15_min resolution
    NumberOfCars = 188
    DemandFactor = 1
    
    # Sets
    priceareas = ["SE1", "SE2", "SE3", "SE4"]
    month = ["m$i" for i in 1:12]
    hours = ["h$(lpad(i, 4, "0"))" for i in 1:8760]
    timestep_all = ["t$(lpad(i, 5, "0"))" for i in 1:35040]
    houses = [:BASE, :DV1, :DV2, :DV3, :EJ1, :EJ2, :EJ3, :VP1, :VP2, :VP3,
        :DVV1, :DVV2, :DVV3, :APTEL1, :APTEL2, :APTEL3, :APTEJ1, :APTEJ2, :APTEJ3]
    @assert hh_profile in houses
    
    # Constants
    Beff_EV = 0.95
    Batterysize = 70.0
    Price_fastcharge = 0.56
    kWhtokW = 4.0
    Charge_Power = 6.9 / kWhtokW
    Fuse_cost = 7.4
    ktoM = 1/1000

    # Cost coefficients (based on input flags)
    Monthly_P_cost_ind = Monthly_Power_Cost ? Fuse_cost : 0.0
    Monthly_P_cost_common = Common_Power_Cost ? Fuse_cost : 0.0
    Annual_P_cost = Annual_Power_Cost ? Fuse_cost * 12 : 0.0

    # Read trsp set
    trsp_all = read_gams_set("logged_names_2.INC")
    # Active subset in GAMS
    trsp = ["b100", "b102", "b103"]
    
    # Parameters
    battery_capacity_dict = read_gams_parameter("Battery_cap_15min_2.INC")
    
    # residential_demand
    println("Reading HH demand ($hh_profile)...")
    if hh_profile == :BASE
        residential_demand_dict = read_gams_parameter("HH_dem_91A2.inc")
        # Convert to Vector aligned with timestep_all
        residential_demand = [residential_demand_dict[t] for t in timestep_all]
    else
        HH_dem_df = read_gams_table("HH_dem_random_15min.inc")
        residential_demand = HH_dem_df[!, hh_profile]
    end
    # Unit conversion: kWh -> W
    residential_demand .= residential_demand .* TimestepsPerHour .* 1000
    
    # Tables
    println("Reading EV_home...")
    EV_home_df = read_gams_table("homeshare_2.INC")
    # Convert to Dict or Matrix? Matrix is faster for optimization.
    # We need to map (timestep, car) -> value.
    # Let's create a dictionary for sparse access or a matrix if dense.
    # Given the size (35040 x ~200), a matrix is ~7M entries. Float64 matrix is ~56MB. That's fine.
    # We need to ensure the order of columns matches trsp_all or trsp.
    
    # Helper to convert DataFrame to Matrix with row/col mapping
    function df_to_dict(df)
        d = Dict{Tuple{String, String}, Float64}()
        # Assuming first col is ID (timestep)
        row_ids = string.(df[!, 1])
        col_names = names(df)[2:end]
        for (i, r) in enumerate(eachrow(df))
            rid = row_ids[i]
            for c in col_names
                val = r[c]
                d[(rid, c)] = val
            end
        end
        return d
    end

    EV_home = df_to_dict(EV_home_df)
    
    println("Reading EV_demand...")
    EV_demand_df = read_gams_table("tripenergy_2.inc")
    EV_demand = df_to_dict(EV_demand_df)
    
    # Apply GAMS logic: EV_demand(timestep_all,trsp_all)$(EV_demand(timestep_all,trsp_all)>0)=0;
    for k in keys(EV_demand)
        if EV_demand[k] > 0
            EV_demand[k] = 0.0
        end
    end
    
    # eprice
    println("Reading eprice...")
    eprice_df = read_gams_table("eprice_priceareas_2023.INC")
    eprice_hourly = df_to_dict(eprice_df)
    
    eprice = Dict{Tuple{String, String}, Float64}()
    for (i, t) in enumerate(timestep_all)
        h_idx = ceil(Int, i / TimestepsPerHour)
        hour = hours[h_idx]
        for a in priceareas
            eprice[t, a] = eprice_hourly[hour, a]
        end
    end

    # maptimestep2month
    # dayspermonth
    dayspermonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    # Calculate first and last timestep for each month
    firsttimestepinmonth = Int[]
    lasttimestepinmonth = Int[]
    current_ts = 1
    for days in dayspermonth
        push!(firsttimestepinmonth, current_ts)
        end_ts = current_ts + days * 24 * TimestepsPerHour - 1
        push!(lasttimestepinmonth, end_ts)
        current_ts = end_ts + 1
    end
    
    t2m = Dict{String, String}()
    for (m_idx, m) in enumerate(month)
        start_ts = firsttimestepinmonth[m_idx]
        end_ts = lasttimestepinmonth[m_idx]
        for ts_idx in start_ts:end_ts
            if ts_idx <= length(timestep_all)
                t2m[timestep_all[ts_idx]] = m
            end
        end
    end
    
    # time_diff
    time_diff = Dict(t => 1.0 for t in timestep_all)
    
    # Return everything
    return (; priceareas, month, hours, timestep_all, trsp_all, trsp,
            TimestepsPerHour, NumberOfCars, DemandFactor, Beff_EV, Batterysize,
            Price_fastcharge, kWhtokW, Charge_Power, Fuse_cost, ktoM,
            battery_capacity_dict, residential_demand, eprice, EV_home, EV_demand,
            t2m, time_diff, Monthly_P_cost_ind, Monthly_P_cost_common, Annual_P_cost)
end
