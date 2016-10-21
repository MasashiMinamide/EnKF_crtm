#!/bin/bash
. $CONFIG_FILE

rundir=$WORK_DIR/run/$DATE/perturb_ic
if [[ ! -d $rundir ]]; then mkdir -p $rundir; echo waiting > $rundir/stat; fi

cd $rundir
if [[ `cat stat` == "complete" ]]; then exit; fi

#Check dependency
wait_for_module ../icbc

echo running > stat
echo "  Running PerturbIC..."

#Run randomcv wrfvar to perturb ICs
  tid=0
  nt=$((total_ntasks/$var3d_ntasks))
  echo "    Generating perturbations using WRF 3DVar"
  for NE in `seq 1 $NUM_ENS`; do 
    id=`expr $NE + 1000 |cut -c2-`
    if [[ ! -d $id ]]; then mkdir $id; fi
    touch $id/rsl.error.0000
    if [[ `tail -n2 $id/rsl.error.0000 |grep successful` ]]; then continue; fi

    cd $id

    ln -fs $WRFDA_DIR/run/LANDUSE.TBL .
    ln -fs $WRFDA_DIR/var/build/da_wrfvar.exe .
    ln -fs $WRFDA_DIR/var/run/obs_gts.3dvar_blank ob.ascii

    cp $WORK_DIR/rc/$DATE/wrfinput_d0? .
    ln -fs wrfinput_d01 fg

    if [[ $CV_OPTIONS == 3 ]]; then
      ln -fs $WRFDA_DIR/var/run/be.dat.cv3 be.dat
    else
      ln -fs $BE_DIR/be.dat .
    fi
    export start_date=$DATE
    export run_minutes=0
    export time_window_min=$DATE
    export time_window_max=$DATE
    $SCRIPT_DIR/namelist_wrfvar.sh perturb > namelist.input
    if $RUN_MULTI_PHYS_ENS; then
      . $SCRIPT_DIR/multi_physics
      n=$((RANDOM%${#BIN_MP_PHYSICS[@]}))
      export M_MP_PHYSICS=${BIN_MP_PHYSICS[$n]}
      n=$((RANDOM%${#BIN_CU_PHYSICS[@]}))
      export M_CU_PHYSICS=${BIN_CU_PHYSICS[$n]}
      n=$((RANDOM%${#BIN_RA_SW_PHYSICS[@]}))
      export M_RA_SW_PHYSICS=${BIN_RA_SW_PHYSICS[$n]}
      export M_RA_LW_PHYSICS=${BIN_RA_LW_PHYSICS[$n]}
      n=$((RANDOM%${#BIN_BL_PBL_PHYSICS[@]}))
      export M_BL_PBL_PHYSICS=${BIN_BL_PBL_PHYSICS[$n]}
      export M_SF_SFCLAY_PHYSICS=${BIN_SF_SFCLAY_PHYSICS[$n]}
      n=$((RANDOM%${#BIN_SF_SURFACE_PHYSICS[@]}))
      export M_SF_SURFACE_PHYSICS=${BIN_SF_SURFACE_PHYSICS[$n]}
      for i in `seq 1 $MAX_DOM`; do
        dm=d`expr $i + 100 |cut -c2-`
        ncatted -a MP_PHYSICS,global,m,i,$M_MP_PHYSICS wrfinput_d01
        ncatted -a CU_PHYSICS,global,m,i,$M_CU_PHYSICS wrfinput_d01
        ncatted -a RA_SW_PHYSICS,global,m,i,$M_RA_SW_PHYSICS wrfinput_d01
        ncatted -a RA_LW_PHYSICS,global,m,i,$M_RA_LW_PHYSICS wrfinput_d01
        ncatted -a BL_PBL_PHYSICS,global,m,i,$M_BL_PBL_PHYSICS wrfinput_d01
        ncatted -a SF_SFCLAY_PHYSICS,global,m,i,$M_SF_SFCLAY_PHYSICS wrfinput_d01
        ncatted -a SF_SURFACE_PHYSICS,global,m,i,$M_SF_SURFACE_PHYSICS wrfinput_d01
      done
      export GET_PHYS_FROM_FILE=true
    else
      export GET_PHYS_FROM_FILE=false
    fi
    #$SCRIPT_DIR/namelist_wrf.sh perturb 1 >> namelist.input
    $SCRIPT_DIR/job_submit.sh $var3d_ntasks $((tid*$var3d_ntasks)) $HOSTPPN ./da_wrfvar.exe >& perturb_ic.log &
    tid=$((tid+1))
    if [[ $tid == $nt ]]; then
      tid=0
      wait
    fi
    cd ..
  done
  
  for NE in `seq 1 $NUM_ENS`; do
    id=`expr $NE + 1000 |cut -c2-`
    watch_log $id/rsl.error.0000 successful 1 $rundir
    mv $id/wrfvar_output $WORK_DIR/rc/$DATE/wrfinput_d01_$id
    if [[ $DATE == $DATE_START ]]; then
      cp $WORK_DIR/rc/$DATE/wrfinput_d01_$id $WORK_DIR/fc/$DATE/wrfinput_d01_$id
    fi
  done

#nest down perturbations for inner domains
export p_ntasks=$var3d_ntasks
if [ $MAX_DOM -gt 1 ]; then
  tid=0
  nt=$((total_ntasks/$p_ntasks))
  echo "    Nestdown perturbation for inner domains..."
  for n in `seq 2 $MAX_DOM`; do
    dm=d`expr $n + 100 |cut -c2-`
    parent_dm=d`expr ${PARENT_ID[$n-1]} + 100 |cut -c2-`
    for NE in `seq 1 $NUM_ENS`; do
      id=`expr $NE + 1000 |cut -c2-`
      cd $id
      if [[ ! -d $dm ]]; then mkdir -p $dm; fi
      cd $dm
      ln -fs ../wrfinput_d0? .
      export run_minutes=0
      export start_date=$DATE
      if $FOLLOW_STORM; then
        cp $WORK_DIR/rc/$DATE/ij_parent_start .
      fi
      if $RUN_MULTI_PHYS_ENS; then
        export GET_PHYS_FROM_FILE=true
      else
        export GET_PHYS_FROM_FILE=false
      fi
      $SCRIPT_DIR/namelist_wrf.sh ndown $n > namelist.input
      rm -f wrfinput_d0?
      ln -fs $WRF_DIR/run/ndown.exe .
      ln -fs $WORK_DIR/rc/$DATE/wrfinput_${parent_dm}_$id wrfout_d01_`wrf_time_string $DATE`
      ln -fs ../wrfinput_$dm wrfndi_d02
      $SCRIPT_DIR/job_submit.sh $p_ntasks $((tid*$p_ntasks)) $HOSTPPN ./ndown.exe >& ndown.log &
      tid=$((tid+1))
      if [[ $tid == $nt ]]; then
        tid=0
        wait
      fi
      cd ../..
    done
    wait
    for NE in `seq 1 $NUM_ENS`; do
      id=`expr $NE + 1000 |cut -c2-`
      watch_log $id/$dm/rsl.error.0000 SUCCESS 1 $rundir
      mv $id/$dm/wrfinput_d02 $WORK_DIR/rc/$DATE/wrfinput_${dm}_$id
      if [[ $DATE == $DATE_START ]]; then
        cp $WORK_DIR/rc/$DATE/wrfinput_${dm}_$id $WORK_DIR/fc/$DATE/wrfinput_${dm}_$id
      fi
    done
  done
fi

#ln -fs $WORK_DIR/rc/$DATE/wrfinput_d?? $WORK_DIR/fc/$DATE/.

echo complete > stat
