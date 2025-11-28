# TODO

* cleanup vibe comments
* make into Julia package, install with dev
* add README
* add loop option (over houses) for runmodel: hh_profile==:ALL
    - accumulate costs
    - modify constraints for HH profiles with JuMP.set_rhs() or whatever its name is
* speed up generation: replace dictionaries with something faster
* rename results files depending on hh_profile and flags
