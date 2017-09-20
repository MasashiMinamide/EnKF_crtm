#!/bin/bash
. $CONFIG_FILE
rundir=$WORK_DIR/run/$DATE/wrf
if [[ ! -d $rundir ]]; then mkdir -p $rundir; echo waiting > $rundir/stat; fi

cd $rundir
if [[ `cat stat` == "complete" ]]; then exit; fi

#Check dependency
if $RUN_ENKF || $RUN_4DVAR; then
  wait_for_module ../update_bc ../icbc
  if [[ $DATE -gt $DATE_START ]]; then
    wait_for_module ../enkf
  fi
else
  wait_for_module ../icbc
fi

#Setup for wrf run
echo running > stat
echo "  Running WRF forecast..."
lfs setstripe -c 1 $rundir

#for i in 1; do
for re_run in `seq 1 3`; do
  touch rsl.error.0000
  if [[ `tail -n2 rsl.error.0000 |grep SUCCESS` ]]; then continue; fi

  if [[ $SST_UPDATE == 1 ]]; then
    ln -fs $WORK_DIR/rc/$LBDATE/wrflowinp_d?? .
  fi

  if $RUN_ENKF || $RUN_4DVAR ; then
    ln -fs $WORK_DIR/fc/$DATE/wrfinput_d?? .
    ln -fs $WORK_DIR/fc/$DATE/wrfbdy_d01 . 
  else
    if [[ $LBDATE == $DATE ]]; then
      ln -fs $WORK_DIR/rc/$DATE/wrfinput_d?? .
    else
      for n in `seq 1 $MAX_DOM`; do
        dm=d`expr $n + 100 |cut -c2-`
        ln -fs $WORK_DIR/fc/$PREVDATE/wrfinput_${dm}_`wrf_time_string $DATE` wrfinput_${dm}
      done
    fi
    ln -fs $WORK_DIR/rc/$LBDATE/wrfbdy_d01 .
  fi

  if $FOLLOW_STORM; then
    cp $WORK_DIR/rc/$DATE/ij_parent_start .
    cp $WORK_DIR/rc/$DATE/domain_moves .
    ln -fs $WRF_PRESET_DIR/run/* .
  else
    ln -fs $WRF_DIR/run/* .
  fi
  rm -f namelist.*


  export start_date=$start_date_cycle
  export run_minutes=`max $run_minutes_cycle $run_minutes_forecast`
  export inputout_interval=$run_minutes_cycle
  export inputout_begin=0
  export inputout_end=$run_minutes_cycle
  export GET_PHYS_FROM_FILE=false
  $SCRIPT_DIR/namelist_wrf.sh wrfw > namelist.input
  if [[ $wrf_ntasks -gt $HOSTPPN ]]; then
     $SCRIPT_DIR/job_submit.sh `expr $wrf_ntasks - $HOSTPPN` 0 $HOSTPPN ./wrf.exe >& wrf.log &
  else
     $SCRIPT_DIR/job_submit.sh $wrf_ntasks 0 $HOSTPPN ./wrf.exe >& wrf.log
  fi
wait
done

#Check output
watch_log rsl.error.0000 SUCCESS 1 $rundir

#wrfout files save to output dir
  for n in `seq 1 $MAX_DOM`; do
    dm=d`expr $n + 100 |cut -c2-`
    outdate=$DATE
    while [[ $outdate -le `advance_time $DATE $run_minutes` ]]; do
      watch_file wrfout_${dm}_`wrf_time_string $outdate` 1 $rundir
      cp wrfout_${dm}_`wrf_time_string $outdate` $WORK_DIR/output/$DATE/.
      outdate=`advance_time $outdate ${WRFOUT_INTERVAL[$n-1]}`
    done
  done

#wrfinput for next cycle
outfile=wrfinput_d01_`wrf_time_string $NEXTDATE`
#watch_file $outfile 1 $rundir
mv $outfile $WORK_DIR/fc/$DATE/.
if [ $MAX_DOM -gt 1 ]; then
  for n in `seq 2 $MAX_DOM`; do
    dm=d`expr $n + 100 |cut -c2-`
    outfile=wrfout_${dm}_`wrf_time_string $NEXTDATE`
    watch_file $outfile 1 $rundir
    cp $outfile $WORK_DIR/fc/$DATE/wrfinput_${dm}_`wrf_time_string $NEXTDATE`
  done
fi

echo complete > stat
