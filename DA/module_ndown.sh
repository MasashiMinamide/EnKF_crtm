#!/bin/bash
. $CONFIG_FILE

rundir=$WORK_DIR/run/$DATE/ndown
if [[ ! -d $rundir ]]; then mkdir -p $rundir; echo waiting > $rundir/stat; fi

cd $rundir
if [[ `cat stat` == "complete" ]]; then exit; fi

#Check dependency
wait_for_module ../real

echo running > stat
echo "  Running NDOWN..."

#nest down perturbations for inner domains
if $TWO_WAY_NESTING && [ $MAX_DOM -gt 1 ]; then
  echo "    Nestdown outer domain for inner domains..."
  for n in `seq 2 $MAX_DOM`; do
    dm=d`expr $n + 100 |cut -c2-`
    parent_dm=d`expr ${PARENT_ID[$n-1]} + 100 |cut -c2-`
    tid=0
    nt=$((SLURM_NTASKS/$wrf_ntasks))
    for NE in `seq 1 $NUM_ENS`; do
      id=`expr $NE + 1000 |cut -c2-`
      if [[ ! -d $id ]]; then mkdir -p $id; fi
      cd $id
      if [[ ! -d $dm ]]; then mkdir -p $dm; fi
      cd $dm
      export run_minutes=0
      export start_date=$DATE
      if $RUN_MULTI_PHYS_ENS; then
        export GET_PHYS_FROM_FILE=true
      else
        export GET_PHYS_FROM_FILE=false
      fi
      $SCRIPT_DIR/namelist_wrf.sh ndown $n > namelist.input
      rm -f wrfinput_d0?
      ln -fs $WRF_DIR/run/ndown.exe .
      ln -fs $WORK_DIR/fc/$DATE/wrfinput_${parent_dm}_$id wrfout_d01_`wrf_time_string $DATE`
      ln -fs $WORK_DIR/rc/$DATE/wrfinput_${dm} wrfndi_d02
      ibrun -n $wrf_ntasks -o $((tid*$wrf_ntasks)) ./ndown.exe >& ndown.log &
      tid=$((tid+1))
      if [ $tid -eq $nt ]; then
        tid=0
        wait
      fi
      cd ../..
    done
    wait
    for NE in `seq 1 $NUM_ENS`; do
      id=`expr $NE + 1000 |cut -c2-`
      watch_log $id/$dm/rsl.error.0000 SUCCESS 1 $rundir
      mv $id/$dm/wrfinput_d02 $WORK_DIR/fc/$DATE/wrfinput_${dm}_$id
    done
  done
fi

echo complete > stat
