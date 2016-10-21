#!/bin/bash
. $CONFIG_FILE

if [[ $MAP_PROJ == "lambert" ]];  then IPROJ=1; fi
if [[ $MAP_PROJ == "polar" ]];    then IPROJ=2; fi
if [[ $MAP_PROJ == "mercator" ]]; then IPROJ=3; fi

window_min=`advance_time $DATE $OWMIN`
window_max=`advance_time $DATE $OWMAX`

cat << EOF
&record1
 obs_gts_filename = 'obs.raw',
 obs_err_filename = 'obserr.txt',
/

&record2
 time_window_min  = '`wrf_time_string $window_min`',
 time_analysis    = '`wrf_time_string $DATE`',
 time_window_max  = '`wrf_time_string $window_max`',
/

&record3
 max_number_of_obs        = 400000,
 fatal_if_exceed_max_obs  = .FALSE.,
/

&record4
 qc_test_vert_consistency = .true.,
 qc_test_convective_adj   = .true.,
 qc_test_above_lid        = .true.,
 remove_above_lid         = .true.,
 domain_check_h           = .true.,
 Thining_SATOB            = .false.,
 Thining_SSMI             = .false.,
 Thining_QSCAT            = .false.,
/

&record5
 print_gts_read           = .true.,
 print_gpspw_read         = .true.,
 print_recoverp           = .true.,
 print_duplicate_loc      = .true.,
 print_duplicate_time     = .true.,
 print_recoverh           = .true.,
 print_qc_vert            = .true.,
 print_qc_conv            = .true.,
 print_qc_lid             = .true.,
 print_uncomplete         = .true.,
/

&record6
 ptop =  $P_TOP,
 base_pres       = 100000.0,
 base_temp       = 290.0,
 base_lapse      = 50.0,
 base_strat_temp = 215.0,
 base_tropo_pres = 20000.0
/

&record7
 IPROJ = $IPROJ,
 PHIC  = ${REF_LAT[0]},
 XLONC = ${REF_LON[0]},
 TRUELAT1= $TRUELAT1,
 TRUELAT2= $TRUELAT2,
 MOAD_CEN_LAT = $REF_LAT,
 STANDARD_LON = $STAND_LON,
/

&record8
 IDD    =   1,
 MAXNES =   1,
 NESTIX =  ${E_SN[0]},
 NESTJX =  ${E_WE[0]},
 DIS    =  $((DX[0]/1000)),
 NUMC   =    1,
 NESTI  =    1,
 NESTJ  =    1,
 / 

&record9
 OUTPUT_OB_FORMAT = 2
 use_for          = '$use_for',
 num_slots_past   = $((OWMAX/$MPS)),
 num_slots_ahead  = $((-OWMIN/$MPS)),
 write_synop = .true., 
 write_ship  = .true.,
 write_metar = .true.,
 write_buoy  = .true., 
 write_pilot = .true.,
 write_sound = .true.,
 write_amdar = .true.,
 write_satem = .true.,
 write_satob = .true.,
 write_airep = .true.,
 write_gpspw = .true.,
 write_gpsztd= .true.,
 write_gpsref= .true.,
 write_gpseph= .true.,
 write_ssmt1 = .true.,
 write_ssmt2 = .true.,
 write_ssmi  = .true.,
 write_tovs  = .true.,
 write_qscat = .true.,
 write_profl = .true.,
 write_bogus = .true.,
 write_airs  = .true.,
 /

EOF
