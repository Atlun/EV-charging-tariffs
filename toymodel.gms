$offlisting
option limrow=0, limcol=0, solprint=off, profile=3;

$setglobal path "C:\Users\thelun\Documents\GAMS\EV charging"
$setglobal Output_path "C:\Users\thelun\Documents\GAMS\EV charging"

$setglobal Year "2023"
*Set temporal resolution to either "hours" or "10_min"
$setglobal RealBatteryCap "yes"
$setglobal Temporal_Resolution "15_min"
* Set to real for estimated battery caps

*Set the first two to yes to use tariffs
$setglobal Annual_Power_Cost "no"          
$setglobal Monthly_Power_Cost "no"         
$setglobal Common_Power_Cost "no"           
$setglobal Fixed_Common_Power "no"
$setGlobal Time_Differentiated "no"

$setglobal Casename "Test_Realcap_%RealBatteryCap%_%Temporal_Resolution%_%Year%"

$if %Annual_Power_Cost% == yes $setglobal Casename "%Casename%_annual"
$if %Monthly_Power_Cost% == yes $setglobal Casename "%Casename%_month"
$if %Common_Power_Cost% == yes $setglobal Casename "%Casename%_common"
$if %Fixed_Common_Power% == yes $setglobal Casename "%Casename%_fixedP"
$if %Time_Differentiated% == yes $setglobal Casename "%Casename%_timediff"

Sets
priceareas
/SE1, SE2, SE3, SE4/
;

Scalar
TimestepsPerHour
NumberOfCars
DemandFactor;
NumberOfCars = 188;

$ifThen %Temporal_Resolution% ==10_min
TimestepsPerHour=6;
DemandFactor=1;

$elseIf %Temporal_Resolution% ==15_min
TimestepsPerHour=4;
DemandFactor=1;

$elseIf %Temporal_Resolution% ==hours
TimestepsPerHour=1;
DemandFactor=-1;
*DemandFactor compensates for input data for demand being positive for the hourly resolution - update if changed input!
$endIf


Sets
month
/ m1*m12 /

$ifThen %Temporal_Resolution% ==hours
timestep
/h0001*h8784/

trsp /
$include ./trsp_426.inc 
/;

Table EV_home(timestep,trsp)  notes if car is home or not [1 if home and able to charge - otherwise 0]
$include "fleetava_home_YDP426.inc"
;
Table EV_demand(timestep,trsp)  electricity demand per car in each daily driving profile [kWh per hour]
$include "demand_bil_YDP426.inc"
;
Table eprice(timestep,priceareas) 
$include ./eprice_priceareas_%year%.inc
* €/MWh (unit conversion  for energy demand in in cost eq as energy in normally in kWh)
;
Parameter residential_demand(timestep) /
$include ./h_AVG_residential_demand.inc
/;
    
$else

Sets
hours
/ h0001*h8760 /

$ifThen %Temporal_Resolution% ==10_min
timestep_all
/t00001*t52560/

timestep(timestep_all)
/t00001*t52560/

trsp_all /
*$include ./logged_carnames.inc
$include ./names_logged.inc
/
    
;
Parameter battery_capacity(trsp_all)/
$include ./battery_capacity_real.inc
/;

Table EV_home(timestep_all,trsp_all)  notes if car is home or not [1 if home and able to charge - otherwise 0]
$include ./homeshare_10min.inc
;
Table EV_demand(timestep_all,trsp_all)  electricity demand per car in each daily driving profile [kWh per timestep]
$include ./tripenergy.inc
;
EV_demand(timestep_all,trsp_all)$(EV_demand(timestep_all,trsp_all)>0)=0;

Parameter residential_demand(timestep_all) /
$include ./HH_dem_10_min_all_houses.inc
/;
* Unit W
$elseIf %Temporal_Resolution% ==15_min
Sets
timestep_all
/t00001*t35040/

timestep(timestep_all)
/t00001*t35040/

trsp_all /
*$include ./logged_carnames.inc
$include ./logged_names_2.inc
/
;
Table EV_home(timestep_all,trsp_all)  notes if car is home or not [1 if home and able to charge - otherwise 0]
$include ./homeshare_2.inc
;
Table EV_demand(timestep_all,trsp_all)  electricity demand per car in each daily driving profile [kWh per timestep]
$include ./tripenergy_2.inc
;
EV_demand(timestep_all,trsp_all)$(EV_demand(timestep_all,trsp_all)>0)=0;

Parameter residential_demand(timestep_all) /
*$include ./HH_dem_15min.inc
$include ./HH_dem_91A2.inc
/;
* Unit kWh
residential_demand(timestep_all)=residential_demand(timestep_all)*TimestepsPerHour*1000;
* Unit W
Parameter battery_capacity(trsp_all)/
$include ./Battery_cap_15min_2.inc
/;
$endIf
Sets
*trsp(trsp_all) / b100, b102, b103 /
*trsp(trsp_all) / b100, b101, b102, b103, b105, b109, b10A, b10C, b10D, b10E, b10_1, b11, b110, b111, b113, b115, b11B, b12_1, b13, b14_2, b17_1, b18_1, b1B, b1C, b1D, b1F, b1_1, b20, b21, b22, b23, b24, b26, b27, b29, b2A_1, b2C, b2E, b2F, b2_1 / 
*trsp(trsp_all) / b100, b102, b103, b109, b10A, b10E, b10_1, b110, b113, b115, b117, b11B, b12_1, b13, b14_2, b15, b17_1, b18_1, b1B, b1C, b1D, b1F, b1_1, b20, b21, b22, b26, b29, b2B, b2E, b2F, b2_1, b30, b31, b32, b33, b35, b36, b37, b38, b3B, b3C, b3D, b3E, b3F, b3_1, b41, b43, b44, b47_2, b48, b4A, b4B_1, b4E, b4F, b4_1 /
*trsp(trsp_all) / b100, b102, b103, b109, b10A, b10E, b10_1, b110, b113, b115, b117, b11B, b12_1, b13, b14_2, b15, b17_1, b18_1, b1B, b1C, b1D, b1F, b1_1, b20, b21, b22, b26, b29, b2B, b2E, b2F, b2_1, b30, b31, b32, b33, b35, b36, b37, b38, b3B, b3C, b3D, b3E, b3F, b3_1, b41,  b43, b44, b47_2, b48, b4A, b4B_1, b4E, b4F, b4_1, b50, b52, b55, b58, b59, b5B, b5C, b5_1,b63, b64, b65, b66, b6A, b6B, b6C, b6E, b70, b74, b75, b77, b78, b79, b7B, b7C, b7D, b7E, b7_1  /
*trsp(trsp_all) / b100, b102, b103, b109, b10D, b10E, b10_1, b110, b113, b115, b117, b11B, b12_1, b13, b14_2, b15, b17_1, b18_1, b1B, b1C, b1D, b1F, b1_1, b20, b21, b22, b26, b29, b2B, b2E, b2F, b2_1, b30, b31, b32, b33, b35, b36, b37, b38, b3B, b3C, b3D, b3E, b3F, b3_1, b41, b43, b44, b47_2, b48, b4A, b4B_1, b4E, b4F, b4_1, b50, b52, b55, b58, b59, b5B, b5C, b5_1, b63, b64, b65, b66, b6A, b6B, b6C, b6E, b70, b74, b75, b77, b78, b79, b7B, b7C, b7D, b7E, b7_1, b80, b87, b88, b8A, b8C, b8D, b8E, b90, b92, b95, b96, b97, b98, b99_1, b9A, b9C, b9D_1, b9E, b9F, b9_1, bA0, bA2, bA3, bA7, bA8, bAC, bAD, bAE, bA_1, bB3, bB4, bB5, bB6, bB7, bB8, bB9, bBB, bBD, bBF, bC0, bC2, bC5, bC8, bC9, bCA_1, bCD, bCF, bC_1, bD1, bD2, bD5, bD6, bD7, bD8, bD9, bDE, bDF, bE5, bE7, bE9, bEB, bF0, bF1, bF4, bF5, bF6, bF7, bF8, bF9, bFA, bFC  /
trsp(trsp_all) / b100, b101, b102, b103, b105, b109, b10A, b10C, b10D, b10E, b10_1, b11, b110, b111, b113, b115, b11B, b12_1, b13, b14_2, b17_1, b18_1, b1B, b1C, b1D, b1F, b1_1, b20, b21, b22, b23, b24, b26, b27, b29, b2A_1, b2C, b2E, b2F, b2_1, b30, b31, b32, b33, b34, b35, b36, b37, b38, b3B, b3D, b3E, b3F, b3_1, b41, b42, b43, b44, b47_2, b48, b4A, b4B_1, b4C_2, b4E, b4F, b4_1, b50, b51, b52, b55, b56, b57, b58, b59, b5A, b5B, b5C, b5_1, b60, b61, b62, b63, b64, b65, b66, b69, b6B, b6C, b6D, b6E, b6F, b6_1, b70, b73, b74, b75, b76, b77, b78, b7B, b7C, b7D, b7E, b7_1, b80, b82, b84, b85, b87, b88, b89, b8A, b8B, b8C, b8D, b8E, b90, b92, b94, b95, b96, b97, b98, b99_1, b9A, b9D_1, b9E, b9F, b9_1, bA0, bA2, bA3, bA7, bA8, bAA, bAC, bAD, bAE, bAF, bB0, bB2, bB3, bB4, bB6, bB7, bB8, bB9, bBA, bBB, bBF, bB_1, bC2, bC3, bC8, bC9, bCD, bCF, bC_1, bD1, bD2, bD3, bD5, bD6, bD7, bD8, bD9, bDC, bDE, bDF, bE1, bE3, bE5, bE7, bE9, bEB, bEE, bF0, bF1, bF3, bF4, bF5, bF6, bF7, bF9, bFA, bFB, bFC, bFD  /

*alias(trsp_all, trsp);
;

Table epriceh(hours,priceareas) 
$include ./eprice_priceareas_%year%.inc
* €/MWh (unit conversion  for energy demand in in cost eq as energy in normally in kWh)
;

*map timesteps to hours if not hourly resolution
parameter lasttimestepinhour(hours);
parameter firsttimestepinhour(hours);
lasttimestepinhour(hours) = ord(hours) * TimestepsPerHour;
*sum(hours2 $ (ord(hours) <= ord(hours)), 24*TimestepsPerHour*dayspermonth(hours2));
firsttimestepinhour(hours) = lasttimestepinhour(hours-1) + 1;
firsttimestepinhour('h0001') = 1;

parameter t2h(timestep);
t2h(timestep) = ceil(ord(timestep)/TimestepsPerHour);

set maptimestep2hour(timestep, hours);
maptimestep2hour(timestep, hours) = yes$(t2h(timestep) = ord(hours));

$endIf

*map timesteps to months
alias(month, month2);

parameter dayspermonth(month) / m1 31, m2 28, m3 31, m4 30, m5 31, m6 30, m7 31, m8 31, m9 30, m10 31, m11 30, m12 31 /;
parameter lasttimestepinmonth(month);
parameter firsttimestepinmonth(month);
lasttimestepinmonth(month) = sum(month2 $ (ord(month2) <= ord(month)), 24*TimestepsPerHour*dayspermonth(month2));
firsttimestepinmonth(month) = lasttimestepinmonth(month-1) + 1;
firsttimestepinmonth('m1') = 1;

set maptimestep2month(timestep, month);
maptimestep2month(timestep, month) = yes $ (ord(timestep) >= firsttimestepinmonth(month) and ord(timestep) <= lasttimestepinmonth(month));





$ifThen %Time_Differentiated% == yes
$ifThen %Temporal_Resolution% ==10_min
Parameter time_diff(timestep)/
$include ./timestepsWPTariff.inc
/;
$elseIf %Temporal_Resolution% ==15_min
Parameter time_diff(timestep)/
$include ./timediff_15min.inc
*$include ./timediff_15min_6_22.inc
/;

$endIf

$else
Parameter time_diff(timestep);
time_diff(timestep) = 1;

$endIf
Scalar
El_cost
Beff_EV
Batterysize
Price_fastcharge
Charge_Power
Fuse_cost
kWhtokW
ktoM
Monthly_P_cost_ind
Monthly_P_cost_common
Annual_P_cost
Annual_P_cost_common
;

Beff_EV=0.95;
El_cost=1;
Batterysize=70; 
Price_fastcharge=0.56;
*€/kWh
Charge_Power=6.9;
Fuse_cost=7.4;
Monthly_P_cost_ind=Fuse_cost;
Monthly_P_cost_common=Fuse_cost;
Annual_P_cost=Fuse_cost*12;
Annual_P_cost_common=Fuse_cost*12;
*€/kW monthly
ktoM=1/1000;

$if %Monthly_Power_Cost%==no Monthly_P_cost_ind=0;
$if %Annual_Power_Cost%==no Annual_P_cost=0;
$if %Common_Power_Cost%==no Monthly_P_cost_common=0;

$ifThen %Temporal_Resolution% ==10_min
    kWhtokW=6;
    
$elseIf %Temporal_Resolution% ==15_min
    kWhtokW=4;
$elseIf %Temporal_Resolution% ==hours
    kWhtokW=1;
    
$endIf

Charge_Power=6.9/kWhtokW;


Variable
   vtotcost
   ;
   

Positive variables
V_PEVcharging_slow (timestep,trsp,priceareas) charging of the vehicle battery [kWh per timestep]
V_PEV_storage (timestep,trsp,priceareas) Storage level of the vehicle battery [kWh per timestep]
V_PEV_need (timestep,trsp,priceareas) vehicle kilometers not met by charging [kWh per timestep]
V_fuse(trsp,priceareas) fuse size [kW per pricearea]
V_power_monthly(month,trsp,priceareas) monthly peak power consumption [kW per month]
V_common_power(month, priceareas) common power consumption [kW per pricearea]
V_maxF_all(month, priceareas) common power consumption [kW per pricearea]
;


Equations
EQU_totcost
EQU_EVstoragelevel(timestep,trsp,priceareas)
EQU_fuse_need(timestep,trsp,priceareas)
EQU_month_p_need(timestep,trsp,priceareas)
EQU_common_power(timestep,priceareas)
EQU_maxfuse(timestep,priceareas)

;

V_PEVcharging_slow.up(timestep,trsp,priceareas)=Charge_Power;
V_PEVcharging_slow.fx(timestep,trsp,priceareas) $ (not(EV_home(timestep,trsp)))=0;
V_PEV_need.fx(timestep,trsp,priceareas) $ EV_home(timestep,trsp)=0;

$if %RealBatteryCap%==yes V_PEV_storage.up(timestep,trsp,priceareas)=battery_capacity(trsp);
$if %RealBatteryCap%==no V_PEV_storage.up(timestep,trsp,priceareas)=Batterysize;
$if %Time_Differentiated%==no V_maxF_all.fx(month, priceareas)=0;



EQU_totcost..
vtotcost =E= 
    sum(priceareas, sum(trsp, 
        sum(timestep, V_PEV_need(timestep,trsp,priceareas)*Price_fastcharge)  
$if %Temporal_Resolution% == 10_min        + sum(hours, sum(timestep $ maptimestep2hour(timestep, hours), V_PEVcharging_slow(timestep,trsp,priceareas)) * ktoM  * epriceh(hours,priceareas))
$if %Temporal_Resolution% == 15_min        + sum(hours, sum(timestep $ maptimestep2hour(timestep, hours), V_PEVcharging_slow(timestep,trsp,priceareas)) * ktoM  * epriceh(hours,priceareas))
$if %Temporal_Resolution% == hours        + sum(timestep, V_PEVcharging_slow(timestep,trsp,priceareas) * ktoM * eprice(timestep,priceareas))
        + V_fuse(trsp,priceareas) *Annual_P_cost  + sum(month, (V_power_monthly(month, trsp,priceareas))*Monthly_P_cost_ind+V_common_power(month, priceareas)*Monthly_P_cost_common )));
        
EQU_EVstoragelevel(timestep,trsp,priceareas)..
V_PEV_storage(timestep++1,trsp,priceareas) =E= V_PEV_storage(timestep,trsp,priceareas) + V_PEVcharging_slow(timestep,trsp,priceareas)*Beff_EV*EV_home(timestep,trsp) + EV_demand(timestep,trsp) * DemandFactor + V_PEV_need (timestep,trsp,priceareas)*Beff_EV*(1-EV_home(timestep,trsp));

EQU_fuse_need(timestep,trsp,priceareas)..
(V_PEVcharging_slow(timestep,trsp,priceareas)*kWhtokW + residential_demand(timestep)/1000)*time_diff(timestep) =L= V_fuse(trsp,priceareas);

EQU_month_p_need(timestep, trsp,priceareas)..
(V_PEVcharging_slow(timestep, trsp,priceareas)*kWhtokW + residential_demand(timestep)/1000)*time_diff(timestep) =L= sum(month $ maptimestep2month(timestep, month), V_power_monthly(month, trsp,priceareas));

EQU_common_power(timestep,priceareas)..
(sum(trsp, V_PEVcharging_slow(timestep, trsp,priceareas)*kWhtokW)+ residential_demand(timestep)/1000*NumberOfCars)*time_diff(timestep) =L=sum(month $ maptimestep2month(timestep, month), V_common_power(month, priceareas));

EQU_maxfuse(timestep,priceareas)..
(sum(trsp, V_PEVcharging_slow(timestep, trsp,priceareas)*kWhtokW)+ residential_demand(timestep)/1000*NumberOfCars) =L=sum(month $ maptimestep2month(timestep, month), V_maxF_all(month, priceareas));


Model EV_charge /
*Add missing equation names here to be part of model
EQU_totcost
EQU_EVstoragelevel
EQU_fuse_need
EQU_month_p_need
EQU_common_power

             /;

EV_charge.iterlim=400000;
EV_charge.optfile = 1;
Option Reslim=1000000;
EV_charge.holdfixed=1;

option solver=gurobi
*option solver=osigurobi;

Solve EV_charge using lp minimizing vtotcost;

* First, declare the parameters (add this before the solve statement)
Parameter Monthly_fuse_common(month, priceareas);
Parameter Monthly_fuse_ind(month, priceareas, trsp);

* Then after the solve, calculate the peak values correctly
* For common peak (one value per month and pricearea)
loop(month,
    loop(priceareas,
        Monthly_fuse_common(month, priceareas) = smax(timestep$(maptimestep2month(timestep, month)),
            sum(trsp, V_PEVcharging_slow.l(timestep, trsp, priceareas)*kWhtokW) 
            + residential_demand(timestep)/1000*NumberOfCars
        );
    );
);

* For individual peak (one value per month, pricearea, and trsp)
loop(month,
    loop(priceareas,
        loop(trsp,
            Monthly_fuse_ind(month, priceareas, trsp) = smax(timestep$(maptimestep2month(timestep, month)),
                V_PEVcharging_slow.l(timestep, trsp, priceareas)*kWhtokW 
                + residential_demand(timestep)/1000
            );
        );
    );
);

* Display and export the results
display Monthly_fuse_common, Monthly_fuse_ind;
Execute_unload '%Casename%_M.gdx', Monthly_fuse_common, Monthly_fuse_ind;
executeTool 'csvwrite id=Monthly_fuse_common file=%Casename%_common_peaks.csv';
executeTool 'csvwrite id=Monthly_fuse_ind file=%Casename%_individual_peaks.csv';

Execute_unload '%Casename%.gdx';
*execute "gdxxrw %Casename%.gdx o=%Casename%.xlsx squeeze=0 var=V_PEV_need rng=Fast_charging!a1";
executeTool 'csvwrite id=V_PEVcharging_slow file=%Casename%.csv';
executeTool 'csvwrite id=V_PEV_need file=%Casename%_fast_charging.csv';
executeTool 'csvwrite id=EV_demand file=%Casename%_demand.csv';

*execute "gdxxrw %Casename%.gdx o=%Casename%.csv symb=V_PEVcharging_slow format=csv";

* Display total charging (slow + fast) over all vehicles and time periods
Scalar total_slow_charging, total_fast_charging, total_charging;

total_slow_charging = sum((timestep,trsp,priceareas), V_PEVcharging_slow.l(timestep,trsp,priceareas));
total_fast_charging = sum((timestep,trsp,priceareas), V_PEV_need.l(timestep,trsp,priceareas));
total_charging = total_slow_charging + total_fast_charging;

display total_slow_charging, total_fast_charging, total_charging;


