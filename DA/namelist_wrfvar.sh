#!/bin/bash
. $CONFIG_FILE
use_for=$1
end_date=`advance_time $start_date $run_minutes`
domlist=`seq 1 $MAX_DOM`

if [[ $use_for == "4dvar" ]]; then 
  var4d=true
  analysis_type=3D-VAR
fi
if [[ $use_for == "perturb" ]]; then 
  MAX_DOM=1
  var4d=false
  analysis_type=RANDOMCV
  domlist=1
fi


cat << EOF
&wrfvar1
/
&wrfvar2
/
&wrfvar3
ob_format=2,
/
&wrfvar4
use_synopobs=$USE_SYNOPOBS,
use_shipsobs=$USE_SHIPSOBS,
use_metarobs=$USE_METAROBS,
use_soundobs=$USE_SOUNDOBS,
use_pilotobs=$USE_PILOTOBS,
use_airepobs=$USE_AIREPOBS,
use_geoamvobs=$USE_GEOAMVOBS,
use_polaramvobs=$USE_POLARAMVOBS,
use_bogusobs=$USE_BOGUSOBS,
use_buoyobs=$USE_BUOYOBS,
use_profilerobs=$USE_PROFILEROBS,
use_satemobs=$USE_SATEMOBS,
use_gpspwobs=$USE_GPSPWOBS,
use_gpsrefobs=$USE_GPSREFOBS,
use_qscatobs=$USE_QSCATOBS,
use_radarobs=$USE_RADAROBS,
/
&wrfvar5
PUT_RAND_SEED = .FALSE.,
OMB_SET_RAND = .FALSE., 
OMB_ADD_NOISE = .FALSE.,
/
&wrfvar6
/
&wrfvar7
cv_options=$CV_OPTIONS,
/
&wrfvar8
/
&wrfvar9
trace_use=false
/
&wrfvar10
/
&wrfvar11
seed_array1=2007081506,
seed_array2=10000,
/
&wrfvar12
/
&wrfvar13
/
&wrfvar14
/
&wrfvar15
/
&wrfvar16
alphacv_method          = 2 
ensdim_alpha            = 0
alpha_corr_type         = 3
alpha_corr_scale        = 1500.0
/
&wrfvar17
analysis_type="$analysis_type",
/
&wrfvar18
analysis_date="`wrf_time_string $time_window_min`.0000"
/
&wrfvar19
/
&wrfvar20
/
&wrfvar21
time_window_min="`wrf_time_string $time_window_min`.0000",
/
&wrfvar22
time_window_max="`wrf_time_string $time_window_max`.0000",
/
&wrfvar23
/
&perturbation
jcdfi_use               = .true.
jcdfi_diag              = 1
jcdfi_penalty           = 10
enable_identity         = .false.
trajectory_io           = .true.
var4d_detail_out        = .false.
/
&time_control
start_year         = `for i in $domlist; do printf ${start_date:0:4}, ; done`
start_month        = `for i in $domlist; do printf ${start_date:4:2}, ; done`
start_day          = `for i in $domlist; do printf ${start_date:6:2}, ; done`
start_hour         = `for i in $domlist; do printf ${start_date:8:2}, ; done`
end_year           = `for i in $domlist; do printf ${end_date:0:4}, ; done`
end_month          = `for i in $domlist; do printf ${end_date:4:2}, ; done`
end_day            = `for i in $domlist; do printf ${end_date:6:2}, ; done`
end_hour           = `for i in $domlist; do printf ${end_date:8:2}, ; done`
/
&dfi_control
/
&domains
e_we       = `for i in $domlist; do printf ${E_WE[$i-1]}, ; done`
e_sn       = `for i in $domlist; do printf ${E_SN[$i-1]}, ; done`
e_vert     = `for i in $domlist; do printf ${E_VERT[$i-1]}, ; done`
dx         = `for i in $domlist; do printf ${DX[$i-1]}, ; done`
dy         = `for i in $domlist; do printf ${DY[$i-1]}, ; done`
/
&physics
mp_physics         = `for i in $domlist; do printf ${MP_PHYSICS[$i-1]}, ; done`
sf_sfclay_physics  = `for i in $domlist; do printf ${SF_SFCLAY_PHYSICS[$i-1]}, ; done`
sf_surface_physics = `for i in $domlist; do printf ${SF_SURFACE_PHYSICS[$i-1]}, ; done`
num_soil_layers    = 4,
num_land_cat       = 21,
/
&fdda
/
&dynamics
/
&bdy_control
/
&logging
/
&tc
/
&noah_mp
/
&grib2
/
&namelist_quilt
/
&diags
/
EOF

