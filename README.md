# PSU WRF-EnKF with CRTM Data Assimilation system
This is the modified version of [PSU WRF-EnKF system](http://www.adapt.psu.edu/index.php?loc=outreach) that allows us to directly assimilate satellite radiances.
- Radiance part: Masashi Minamide ([mum373@psu.edu](mailto:mum373@psu.edu))
- Control Scripts: Michael Ying, Jonathan Poterjoy, Yonghui Weng, Masashi Minamide 
- EnKF component code: Fuqing Zhang, Yonghui Weng, Michael Ying, Jonathan Poterjoy, Masashi Minamide

### How to use ###
Following the user-guide of [PSU WRF-EnKF system](http://www.adapt.psu.edu/index.php?loc=outreach)

1. Unpackage, compile and place all necessary code packages in the proper directory
  - EnKF system code
  - The Advanced Weather Research and Forecasting model (WRF-ARW), compiled for normal(WRFV3) and preset moving nest(WRF_preset)
  - WRF Pre-Processing System (WPS)
  - WRF Data Assimilation System (WRFDA)
  - WRF Boundary Condition Update (WRF_BC_v2.1)
  - Community Radiative Transfer Model (CRTM)
    - Also, link coefficient files from $CRTM_DIR/fix/SpcCoeff/Big_Endian and $CRTM_DIR/fix/TauCoeff/Big_Endian to $CRTM_DIR/crtm_wrf/coefficients directory. 
    - if you do not have "crtm_wrf" directory, just make it. (You do not have to download below "crtm_wrf" package, but I am sure it will be useful for you!:) )
    - The "crtm_wrf" is the name of the directory that contains the code package to use CRTM for WRF outputs [https://github.com/MasashiMinamide/crtm_wrf](https://github.com/MasashiMinamide/crtm_wrf).
2. Prepare the data and place them in the proper directories
  - Geography data for WPS
  - Global analyses/forecasts to generate initial and boundary conditions
  - Observations
    - For satellite radiance assimilation, check "data_sample" directory.
3. Modify "config" file for your settings
4. run "run.sh"

