#!/bin/bash
#HOSTTYPE, HOSTPPN are defined in config file
#total_ntasks is defined in run.sh
. $CONFIG_FILE
n=$1  # num of tasks job uses
o=$2  # offset location in total_ntasks, useful for several jobs to run together
ppn=$3  # proc per node for the job
exe=$4  # executable

###stampede
if [[ $HOSTTYPE == "stampede" ]]; then
  export SLURM_TASKS_PER_NODE="$ppn(x$SLURM_NNODES)"
  ibrun -n $n -o $o $exe
  export SLURM_TASKS_PER_NODE="$((SLURM_NTASKS/$SLURM_NNODES))(x$SLURM_NNODES)"
fi

###jet
if [[ $HOSTTYPE == "jet" ]]; then
  nn=$((($n+$n%$ppn)/$ppn))   #number of nodes used for job = ceiling(n/ppn)
  rm -f nodefile
  for i in `seq 1 $nn`; do 
    cat $PBS_NODEFILE |head -n$((HOSTPPN*($nn*$o/$n+$i))) |tail -n$ppn >> nodefile
  done
  mpiexec.mpirun_rsh -np $n -machinefile nodefile OMP_NUM_THREADS=1 $exe
fi

###define your own mpiexec here:
