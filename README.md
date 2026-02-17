# EV Charging model (previously internally known as the toymodel)

A model for cost-minmizing optimization of EV charging with different network tariffs based on the household peak power. The model was dveloped to compare 
cost-optimal EV charging, assuming different network tariff designs in combination with electricity prices that vary according to the spot price. The purpose 
of the model is to study both the temporal distribution of charging and the peak power that an electrified vehicle fleet may introduce to the local grid. The 
EV charging model minimizes the cost of EV charging, while ensuring that the energy demand for driving is met in all timesteps for each vehicle. It includes 
an energy balance, constraints related to the different network tariff designs, and a cost calculation (which is the objective function of the model). In 
particular, the model considers network tariffs based on peak power, also known as ‘power tariffs’. The components included in the cost calculation and the 
constraints vary between the modeled cases.                                                                                            
                                                                                                        
## NOTE: data not uploaded yet!

This repository contains all the code needed to run the model, but we have not yet uploaded the actual input data.The reason is that parts of the data were 
provided to us under confidentiality terms. Hopefully, more data will be available at a later point in time. 
                                                                                                      
## Running: arguments and defaults
Settings to be used in the model run are determined in the beginning of the code.                       
Annual_Power_Cost introduces a cost for the annual peak power per household
Monthly_Power_Cost introduces a cost for the monthly peak power per household
Common_Power_Cost introduces a cost for the combined monthly peak power of all households together
Time_Differentiated changes so that the activated criteria above only take the daytime peak. It must therefore be combined with at least one of the criteria above. 
