# TODO

* cleanup vibe comments
* make into Julia package, install with dev
* add README
* add loop option (over houses) for runmodel: hh_profile==:ALL
    - read HH_dem and hh_profile processing outside loop and pass residential_demand into makeconstraints
    - accumulate costs
    - modify constraints for HH profiles with JuMP.set_rhs() or whatever its name is
* speed up generation: replace dictionaries with something faster
* rename results files depending on hh_profile and flags
* cleanup result writing, gams helpers
