#!/bin/bash
. $CONFIG_FILE

rundir=$WORK_DIR/run/$DATE/skipSpin
if [[ ! -d $rundir ]]; then mkdir -p $rundir; echo waiting > $rundir/stat; fi
cd $rundir

if [[ `cat stat` == "complete" ]]; then exit; fi

# This script skips the spinup period of a run if the data files already exist
# The directory to the previous ensemble run (e.g. noda) needs to be specified
echo running > stat

if $TWO_WAY_NESTING || [ $RUN_DOMAIN == 1 ]; then
  domlist=`seq 1 $MAX_DOM`
else
  MAX_DOM=1
  domlist=1
fi

#Copy IC
echo "  Copying IC files..."
tid=0
nt=$SLURM_NTASKS
for n in $domlist; do
  dm=d`expr $n + 100 |cut -c2-`
  for NE in `seq 1 $NUM_ENS`; do
    id=`expr $NE + 1000 |cut -c2-`
    ibrun -n 1 -o $tid cp -L $SPIN_DIR/fc/$DATE_START/wrfinput_${dm}_$id $WORK_DIR/fc/$DATE_START/wrfinput_${dm}_$id >> cpIC.log 2>&1 &
    tid=$((tid+1))
    if [[ $tid == $nt ]]; then
      tid=0
      wait
    fi
  done
  # Copy control IC
  ibrun -n 1 -o $tid cp -L $SPIN_DIR/fc/$DATE_START/wrfinput_${dm} $WORK_DIR/fc/$DATE_START/wrfinput_${dm} >> cpIC.log 2>&1 &
  tid=$((tid+1))
  if [[ $tid == $nt ]]; then
    tid=0
    wait
  fi
  ibrun -n 1 -o $tid cp -L $SPIN_DIR/rc/$DATE_START/wrfinput_${dm} $WORK_DIR/rc/$DATE_START/wrfinput_${dm} >> cpIC.log 2>&1 &
  tid=$((tid+1))
  if [[ $tid == $nt ]]; then
    tid=0
    wait
  fi
done
wait

#Copy BC
echo "  Copying BC files..."
tid=0
nt=$SLURM_NTASKS
for NE in `seq 1 $NUM_ENS`; do
  id=`expr $NE + 1000 |cut -c2-`
  ibrun -n 1 -o $tid cp -L $SPIN_DIR/fc/$DATE_START/wrfbdy_d01_$id $WORK_DIR/fc/$DATE_START/wrfbdy_d01_$id >> cpBC.log 2>&1 &
  tid=$((tid+1))
  if [[ $tid == $nt ]]; then
    tid=0
    wait
  fi
done
wait
#Copy control BC
ibrun -n 1 -o 0 cp -L $SPIN_DIR/fc/$DATE_START/wrfbdy_d01 $WORK_DIR/fc/$DATE_START/wrfbdy_d01 >> cpBC.log 2>&1 &
ibrun -n 1 -o 1 cp -L $SPIN_DIR/rc/$DATE_START/wrfbdy_d01 $WORK_DIR/rc/$DATE_START/wrfbdy_d01 >> cpBC.log 2>&1 &

#Copy spinup
echo "  Copying spinup files..."
tid=0
nt=$SLURM_NTASKS
for n in $domlist; do
  dm=d`expr $n + 100 |cut -c2-`
  for NE in `seq 1 $NUM_ENS`; do
    id=`expr $NE + 1000 |cut -c2-`
    ibrun -n 1 -o $tid cp -L $SPIN_DIR/fc/$DATE/wrfinput_${dm}_`wrf_time_string $NEXTDATE`_$id $WORK_DIR/fc/$DATE/wrfinput_${dm}_`wrf_time_string $NEXTDATE`_$id >> cpSPIN.log 2>&1 &
    tid=$((tid+1))
    if [[ $tid == $nt ]]; then
      tid=0
      wait
    fi
  done
done
wait

#Link random sample files
echo "  Linking random samples files for BC update..."
ln -s $SPIN_DIR/rc/random_samples $WORK_DIR/rc/random_samples

echo complete > stat
