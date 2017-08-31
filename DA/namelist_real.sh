#!/bin/bash
#possible usages:
#use_for = "perturb"  Use WRF 3DVar randomcv mode to generate ensemble perturbations
#use_for = "ndown"    Running ndown.exe on nested domain $idom
#use_for = "wrfw"     Running wrf.exe for domain $RUN_DOMAIN across the cycle window, 
#                     wrfinput files will be generated for next cycle

. $CONFIG_FILE
end_date=`advance_time $start_date $run_minutes`
#end_date=$DATE_END

use_for=$1
idom=$2

if [ -f ij_parent_start ]; then
  i_parent_start=(`cat ij_parent_start |head -n1`)
  j_parent_start=(`cat ij_parent_start |tail -n1`)
else
  for n in `seq 1 $MAX_DOM`; do
    i_parent_start[$n-1]=${I_PARENT_START[$n-1]}
    j_parent_start[$n-1]=${J_PARENT_START[$n-1]}
  done
fi

domlist=`seq 1 $MAX_DOM`
LBINT=$LBC_INTERVAL
if [ $use_for == "perturb" ]; then
  MAX_DOM=1
  domlist=$idom
fi
if [ $use_for == "ndown" ]; then
  MAX_DOM=2
  domlist="${PARENT_ID[$idom-1]} $idom"
  LBINT=$((WRFOUT_INTERVAL[${PARENT_ID[$idom-1]}-1]))
fi

#=============TIME CONTROL PART=============
echo "&time_control"
cat << EOF
run_minutes        = $run_minutes,
start_year         = `for i in $domlist; do printf ${start_date:0:4}, ; done`
start_month        = `for i in $domlist; do printf ${start_date:4:2}, ; done`
start_day          = `for i in $domlist; do printf ${start_date:6:2}, ; done`
start_hour         = `for i in $domlist; do printf ${start_date:8:2}, ; done`
start_minute       = `for i in $domlist; do printf ${start_date:10:2}, ; done`
start_second       = `for i in $domlist; do printf 00, ; done`
end_year           = `for i in $domlist; do printf ${end_date:0:4}, ; done`
end_month          = `for i in $domlist; do printf ${end_date:4:2}, ; done`
end_day            = `for i in $domlist; do printf ${end_date:6:2}, ; done`
end_hour           = `for i in $domlist; do printf ${end_date:8:2}, ; done`
end_minute         = `for i in $domlist; do printf ${end_date:10:2}, ; done`
end_second         = `for i in $domlist; do printf 00, ; done`
EOF
if $RUN_VORTEX_NEST; then
  export MAX_DOM_WPS=`expr $MAX_DOM - 1`
  domlist_vor=`seq 1 $MAX_DOM_WPS`
  echo "input_from_file       = `for i in $domlist_vor; do printf .true., ; done`.false.,"
else
  echo "input_from_file       = `for i in $domlist; do printf .true., ; done`"
fi
cat << EOF
interval_seconds   = $((LBINT*60)),
history_interval   = `for i in $domlist; do printf ${WRFOUT_INTERVAL[$i-1]}, ; done`
frames_per_outfile = `for i in $domlist; do printf 1, ; done`
debug_level        = 0,
EOF


if [[ $use_for == "wrfw" ]]; then
cat << EOF
input_outname="wrfinput_d<domain>_<date>",
write_input=true,
inputout_interval=$inputout_interval,
inputout_begin_m=$inputout_begin,
inputout_end_m=$inputout_end,
EOF
fi

if [[ $use_for == "ndown" ]]; then
  echo io_form_auxinput2=2,
fi

if [[ $SST_UPDATE == 1 ]]; then
  dmin=`min ${CYCLE_PERIOD[@]}`
  echo auxinput4_inname="wrflowinp_d<domain>",
  echo auxinput4_interval=`for i in $domlist; do printf $dmin, ; done`
  echo io_form_auxinput4=2,
fi

echo "/"

#=============DOMAIN PART=============
echo "&domains"
cat << EOF
time_step=$DT,
max_dom=$MAX_DOM,
e_we       = `for i in $domlist; do printf ${E_WE[$i-1]}, ; done`
e_sn       = `for i in $domlist; do printf ${E_SN[$i-1]}, ; done`
e_vert     = `for i in $domlist; do printf ${E_VERT[$i-1]}, ; done`
dx         = `for i in $domlist; do printf ${DX[$i-1]}, ; done`
dy         = `for i in $domlist; do printf ${DY[$i-1]}, ; done`
EOF

if [[ $use_for == "ndown" ]]; then
cat << EOF
grid_id    = 1,2,
parent_id  = 0,1,
parent_grid_ratio = 1,${GRID_RATIO[$idom-1]},
i_parent_start = 1,${i_parent_start[$idom-1]},
j_parent_start = 1,${j_parent_start[$idom-1]},
EOF
else
cat << EOF
grid_id    = `for i in $domlist; do printf $i, ; done`
parent_id  = 0,`for i in $(seq 2 $MAX_DOM); do printf ${PARENT_ID[$i-1]}, ; done`
parent_grid_ratio = 1,`for i in $(seq 2 $MAX_DOM); do printf ${GRID_RATIO[$i-1]}, ; done`
parent_time_step_ratio = 1,`for i in $(seq 2 $MAX_DOM); do printf ${TIME_STEP_RATIO[$i-1]}, ; done`
i_parent_start = 1,`for i in $(seq 2 $MAX_DOM); do printf ${i_parent_start[$i-1]}, ; done`
j_parent_start = 1,`for i in $(seq 2 $MAX_DOM); do printf ${j_parent_start[$i-1]}, ; done`
EOF
fi

if $TWO_WAY_NESTING; then
  echo "feedback=1,"
else
  echo "feedback=0,"
fi

cat << EOF
smooth_option=0,
num_metgrid_levels=$NUM_METGRID_LEVELS,
num_metgrid_soil_levels=$NUM_METGRID_SOIL_LEVELS,
eta_levels   = 1.00, 0.9900, 0.980, 0.9700, 0.960, 0.9500,
               0.940, 0.9300, 0.9200, 0.9099, 0.8997, 0.8892,
               0.8780, 0.8658, 0.8520, 0.8363, 0.8187, 0.7991,
               0.7780, 0.7559, 0.7331, 0.7099, 0.6866, 0.6633,
               0.6400, 0.6167, 0.5933, 0.5700, 0.5467, 0.5233,
               0.5000, 0.4767, 0.4533, 0.4300, 0.4067, 0.3833,
               0.3600, 0.3367, 0.3134, 0.2901, 0.2669, 0.2441,
               0.220, 0.2009, 0.1813, 0.1637, 0.1480, 0.1342,
               0.1220, 0.1108, 0.1003, 0.0901, 0.0800, 0.0700,
               0.0600, 0.0500, 0.0400, 0.0300, 0.0200, 0.0100,
               0.0,
p_top_requested=$P_TOP,
EOF
#eta_levels   = 1.00, 0.9900, 0.980, 0.9700, 0.960, 0.9500,
#               0.940, 0.9300, 0.9200, 0.9099, 0.8997, 0.8892,
#               0.8780, 0.8658, 0.8520, 0.8363, 0.8187, 0.7991,
#               0.7780, 0.7559, 0.7331, 0.7099, 0.6866, 0.6633,
#               0.6400, 0.6167, 0.5933, 0.5700, 0.5467, 0.5233,
#               0.5000, 0.4767, 0.4533, 0.4300, 0.4067, 0.3833,
#               0.3600, 0.3367, 0.3134, 0.2901, 0.2669, 0.2441,
#               0.220, 0.2009, 0.1813, 0.1637, 0.1480, 0.1342,
#               0.1220, 0.1108, 0.1003, 0.0901, 0.0800, 0.0700,
#               0.0600, 0.0500, 0.0400, 0.0300, 0.0200, 0.0100,
#               0.0,

if $RUN_VORTEX_NEST; then
  echo "time_to_move    = `for i in $domlist; do printf ${TIME_TO_MOVE[$i-1]}, ; done`"
  echo "vortex_interval = `for i in $domlist; do printf ${VORTEX_INTERVAL[$i-1]}, ; done`"
#else
#  echo "time_to_move    = `for i in $domlist; do printf 9999999, ; done`"
#  echo "vortex_interval = `for i in $domlist; do printf 9999999, ; done`"
fi

echo "/"

#=============PHYSICS PART=============
echo "&physics"
if $GET_PHYS_FROM_FILE; then
cat << EOF
mp_physics         = `for i in $domlist; do printf $(ncdump -h wrfinput_d$(expr $i + 100 |cut -c2-) |grep :MP_PHYSICS |awk '{print $3}'), ; done`
ra_lw_physics      = `for i in $domlist; do printf $(ncdump -h wrfinput_d$(expr $i + 100 |cut -c2-) |grep :RA_LW_PHYSICS |awk '{print $3}'), ; done`
ra_sw_physics      = `for i in $domlist; do printf $(ncdump -h wrfinput_d$(expr $i + 100 |cut -c2-) |grep :RA_SW_PHYSICS |awk '{print $3}'), ; done`
radt               = `for i in $domlist; do printf ${RADT[$i-1]}, ; done`
sf_sfclay_physics  = `for i in $domlist; do printf $(ncdump -h wrfinput_d$(expr $i + 100 |cut -c2-) |grep :SF_SFCLAY_PHYSICS |awk '{print $3}'), ; done`
sf_surface_physics = `for i in $domlist; do printf $(ncdump -h wrfinput_d$(expr $i + 100 |cut -c2-) |grep :SF_SURFACE_PHYSICS |awk '{print $3}'), ; done`
bl_pbl_physics     = `for i in $domlist; do printf $(ncdump -h wrfinput_d$(expr $i + 100 |cut -c2-) |grep :BL_PBL_PHYSICS |awk '{print $3}'), ; done`
bldt               = `for i in $domlist; do printf ${BLDT[$i-1]}, ; done`
cu_physics         = `for i in $domlist; do printf $(ncdump -h wrfinput_d$(expr $i + 100 |cut -c2-) |grep :CU_PHYSICS |awk '{print $3}'), ; done`
cudt               = `for i in $domlist; do printf ${CUDT[$i-1]}, ; done`
EOF
else
cat << EOF
mp_physics         = `for i in $domlist; do printf ${MP_PHYSICS[$i-1]}, ; done`
ra_lw_physics      = `for i in $domlist; do printf ${RA_LW_PHYSICS[$i-1]}, ; done`
ra_sw_physics      = `for i in $domlist; do printf ${RA_SW_PHYSICS[$i-1]}, ; done`
radt               = `for i in $domlist; do printf ${RADT[$i-1]}, ; done`
sf_sfclay_physics  = `for i in $domlist; do printf ${SF_SFCLAY_PHYSICS[$i-1]}, ; done`
sf_surface_physics = `for i in $domlist; do printf ${SF_SURFACE_PHYSICS[$i-1]}, ; done`
bl_pbl_physics     = `for i in $domlist; do printf ${BL_PBL_PHYSICS[$i-1]}, ; done`
bldt               = `for i in $domlist; do printf ${BLDT[$i-1]}, ; done`
cu_physics         = `for i in $domlist; do printf ${CU_PHYSICS[$i-1]}, ; done`
cudt               = `for i in $domlist; do printf ${CUDT[$i-1]}, ; done`
EOF
fi

cat << EOF
isfflx             = 1,
ifsnow             = 1,
icloud             = 1,
surface_input_source=1,
num_soil_layers    = 0,
sst_update         = $SST_UPDATE,
sst_skin           = 1,
EOF

#extra physics options
cat << EOF
levsiz = 59,
paerlev = 29,
cam_abs_dim1 = 4,
cam_abs_dim2 = 45,
EOF

echo "/"


#=============DYNAMICS PART=============
echo "&dynamics"
cat << EOF
w_damping           = 0,
use_input_w         = .true.,
diff_opt            = 2,
km_opt              = 4,
diff_6th_opt        = `for i in $domlist; do printf 0, ; done`
diff_6th_factor     = `for i in $domlist; do printf 0.12, ; done`
base_temp           = 290.,
damp_opt            = 3,
zdamp               = `for i in $domlist; do printf 7000., ; done`
dampcoef            = `for i in $domlist; do printf 0.1, ; done`
khdif               = `for i in $domlist; do printf 0, ; done`
kvdif               = `for i in $domlist; do printf 0, ; done`
non_hydrostatic     = `for i in $domlist; do printf .true., ; done`
moist_adv_opt       = `for i in $domlist; do printf 1, ; done`
scalar_adv_opt      = `for i in $domlist; do printf 1, ; done`
EOF
#iso_temp            = 0.,
echo "/"

#=============BODY CONTROL PART=============
echo "&bdy_control"
cat << EOF
spec_bdy_width     = 5,
spec_zone          = 1,
relax_zone         = 4,
specified          = `for i in $domlist; do printf .true., ; done`
EOF
echo "/"

#=============OTHERS=============
cat << EOF
&noah_mp
/
&fdda
/
&scm
/
&grib2
/
&fire
/
&diags
/
&namelist_quilt
/
&tc
/
&logging
/
&dfi_control
/
EOF

