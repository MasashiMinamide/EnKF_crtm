#!/bin/bash
. $CONFIG_FILE
rundir=$WORK_DIR/run/$DATE/real

if [[ ! -d $rundir ]]; then mkdir -p $rundir; echo waiting > $rundir/stat; fi

cd $rundir
if [[ `cat stat` == "complete" ]]; then exit; fi

#Check dependency
wait_for_module ../wps

#if CP < LBC_INTERVAL, cannot generate wrfinput and wrfbdy from LBC data
#instead, we will fetch wrfbdy from the previous cycle where LBC is available
#and wrfinput will be from the previous cycle wrf run.
if [ $LBDATE != $DATE ]; then echo complete > stat; exit; fi

#Run real
echo running > stat
echo "  Running real.exe..."

export start_date=$start_date_cycle
#export run_minutes=`max $run_minutes_cycle $run_minutes_forecast $((LBC_INTERVAL*2))`
#export run_minutes=`max $run_minutes_cycle $run_minutes_forecast $((LBC_INTERVAL*2))`
export run_minutes=`diff_time $DATE $DATE_END`
export GET_PHYS_FROM_FILE=false
$SCRIPT_DIR/namelist_real.sh real 1 > namelist.input

  ln -fs $WORK_DIR/rc/$DATE/met_em* .
  ln -fs $WRF_DIR/main/real.exe .
  $SCRIPT_DIR/job_submit.sh $wrf_ntasks 0 $HOSTPPN ./real.exe >& real.log
  watch_log rsl.error.0000 SUCCESS 1 $rundir

  #if sst_update=1, wrflowinp_d?? files will be created, but if CP < LBC_INTERVAL, we need to
  #interpolate these files in time so that the smaller-period cycles have valid time in these files
  # to work with too.
  if [ $SST_UPDATE == 1 ]; then
    for n in `seq 1 $MAX_DOM`; do
      dm=d`expr $n + 100 |cut -c2-`
      dmin=`min ${CYCLE_PERIOD[@]}`
      if [[ $dmin -lt $LBC_INTERVAL ]]; then
        ncl $SCRIPT_DIR/linint_time_ncfile.ncl dmin=$dmin 'infile="wrflowinp_'$dm'"' >> lowinp.log 2>&1
        mv tmp.nc $WORK_DIR/rc/$DATE/wrflowinp_$dm
      else
        cp wrflowinp_$dm $WORK_DIR/rc/$DATE/.
      fi
    done
  fi

cp wrfinput_d?? $WORK_DIR/rc/$DATE/.
cp wrfbdy_d01 $WORK_DIR/rc/$DATE/.
if [[ $DATE == $DATE_START ]]; then
  cp wrfinput_d?? $WORK_DIR/fc/$DATE/.
  cp wrfbdy_d01 $WORK_DIR/fc/$DATE/.
fi

echo complete > stat
