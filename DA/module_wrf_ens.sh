#!/bin/bash
. $CONFIG_FILE
rundir=$WORK_DIR/run/$DATE/wrf_ens
if [[ ! -d $rundir ]]; then mkdir -p $rundir; echo waiting > $rundir/stat; fi

cd $rundir
if [[ `cat stat` == "complete" ]]; then exit; fi

#Check dependency
wait_for_module ../update_bc ../icbc 
if [[ $DATE -gt $DATE_START ]]; then
  wait_for_module ../enkf
fi

#Setup for wrf run
echo running > stat
echo "  Running WRF ensemble..."

tid=1  #does not start from 0, because the wrf forecast runs with ens at the same time.
#if [[ `cat ../wrf/stat` == "complete" ]]; then tid=0; fi
if [[ `tail -n2 ../wrf/rsl.error.0000 |grep SUCCESS` ]]; then tid=0; fi
nt=$((total_ntasks/$wrf_ntasks))
for re_run in `seq 1 3`; do
  tid=1
  if [[ `tail -n2 ../wrf/rsl.error.0000 |grep SUCCESS` ]]; then tid=0; fi
  for NE in `seq 1 $NUM_ENS`; do
    id=`expr $NE + 1000 |cut -c2-`
    if [[ ! -d $id ]]; then mkdir $id; fi
    touch $id/rsl.error.0000
    if [[ `tail -n2 $id/rsl.error.0000 |grep SUCCESS` ]]; then continue; fi

    cd $id
    lfs setstripe -c 1 $rundir/$id

    for n in `seq 1 $MAX_DOM`; do
      dm=d`expr $n + 100 |cut -c2-`
      ln -fs $WORK_DIR/fc/$DATE/wrfinput_${dm}_$id wrfinput_$dm
    done
    ln -fs $WORK_DIR/fc/$DATE/wrfbdy_d01_$id wrfbdy_d01

    if [[ $SST_UPDATE == 1 ]]; then
      ln -fs $WORK_DIR/rc/$LBDATE/wrflowinp_d?? .
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
    export run_minutes=$run_minutes_cycle 
    export inputout_interval=$run_minutes
    export inputout_begin=0
    export inputout_end=$run_minutes
    export GET_PHYS_FROM_FILE=false
    $SCRIPT_DIR/namelist_wrf.sh wrfw $RUN_DOMAIN > namelist.input

    $SCRIPT_DIR/job_submit.sh `expr $wrf_ntasks - $HOSTPPN` $((tid*$wrf_ntasks)) $HOSTPPN ./wrf.exe >& wrf.log &
    #$SCRIPT_DIR/job_submit.sh $wrf_ntasks $((tid*$wrf_ntasks)) $HOSTPPN ./wrf.exe >& wrf.log &
    tid=$((tid+1))
    if [[ $tid == $nt ]]; then
      tid=1
      if [[ `tail -n2 ../../wrf/rsl.error.0000 |grep SUCCESS` ]]; then tid=0; fi
      wait
    fi
    cd ..
  done
wait
done

for NE in `seq 1 $NUM_ENS`; do
  id=`expr $NE + 1000 |cut -c2-`
  watch_log $id/rsl.error.0000 SUCCESS 1 $rundir
  outfile=$id/wrfinput_d01_`wrf_time_string $NEXTDATE`
#  watch_file $outfile 1 $rundir
  mv $outfile $WORK_DIR/fc/$DATE/wrfinput_d01_`wrf_time_string $NEXTDATE`_$id
  if [ $MAX_DOM -gt 1 ]; then
    for n in `seq 2 $MAX_DOM`; do
      dm=d`expr $n + 100 |cut -c2-`
      outfile=$id/wrfout_${dm}_`wrf_time_string $NEXTDATE`
      watch_file $outfile 1 $rundir
###      mv $outfile $WORK_DIR/fc/$DATE/wrfinput_${dm}_`wrf_time_string $NEXTDATE`_$id
      ln -fs $rundir/$outfile $WORK_DIR/fc/$DATE/wrfinput_${dm}_`wrf_time_string $NEXTDATE`_$id
    done
  fi
done

if $CLEAN; then rm $rundir/$id/wrfout* ; fi
echo complete > stat
