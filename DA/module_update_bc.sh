#!/bin/bash
. $CONFIG_FILE

rundir=$WORK_DIR/run/$DATE/update_bc
if [[ ! -d $rundir ]]; then mkdir -p $rundir; echo waiting > $rundir/stat; fi
cd $rundir
if [[ `cat stat` == "complete" ]]; then exit; fi

#Check dependency
#----------------
if $RUN_ENKF; then
  if [[ $DATE == $DATE_START ]]; then
    wait_for_module ../perturb_ic ../icbc
  else
    wait_for_module ../enkf
  fi
fi

echo running > stat
echo "  Running UpdateBC..."

cat > parame.in << EOF
&control_param
 da_file               = 'wrfinput_d01_update'
 da_file_02            = 'ana02'
 wrf_bdy_file          = 'wrfbdy_d01_update'
 wrf_input             = 'wrfinput_d01'
 domain_id             = 1
 debug                 = .false. 
 update_lateral_bdy    = .true. 
 update_low_bdy        = .true.
 update_lsm            = .false.
 var4d_lbc             = .false.
/
EOF

#members
#tid=0
#nt=$total_ntasks
for NE in `seq 1 $NUM_ENS`; do
  id=`expr $NE + 1000 |cut -c2-`
  if [[ ! -d $id ]]; then mkdir $id; fi
  touch $id/update_bc.log
  if [[ `tail -n1 $id/update_bc.log |grep successfully` ]]; then continue; fi

  cd $id
  ln -fs ../parame.in .
  ln -fs $WRFDA_DIR/var/da/da_update_bc.exe .
##for when $LBDATE>$PREVDATE by Minamide 2014.11.23
#  if [ $LBDATE -ge $PREVDATE ] && [ $LBDATE != $DATE ]; then  
#    ln -fs $WORK_DIR/rc/$PREVDATE/wrfbdy_d01 .
#    ln -fs $WORK_DIR/rc/$PREVDATE/wrfinput_d01 .
#  else
#  if [[ $DATE == $DATE_START ]]; then
  if [[ $DATE == $LBDATE ]]; then
    ln -fs $WORK_DIR/rc/$LBDATE/wrfbdy_d01 wrfbdy_d01
  else
    ln -fs $WORK_DIR/rc/$LBDATE/wrfbdy_d01_$id wrfbdy_d01
  fi
  ln -fs $WORK_DIR/rc/$LBDATE/wrfinput_d01_$id wrfinput_d01
#  fi
  cp -L wrfbdy_d01 wrfbdy_d01_update
  rm -f wrfinput_d01_update
  ln -fs $WORK_DIR/fc/$DATE/wrfinput_d01_$id wrfinput_d01_update

  for re_run in `seq 1 3`; do
    if [[ `tail -n1 update_bc.log |grep successfully` ]]; then continue; fi
    ./da_update_bc.exe >& update_bc.log &
  done

#  tid=$((tid+1))
#  if [[ $tid == $nt ]]; then
#    tid=0
#    wait
#  fi
  cd ..
done
wait

for NE in `seq 1 $NUM_ENS`; do
  id=`expr $NE + 1000 |cut -c2-`
  watch_log $id/update_bc.log successfully 1 $rundir
#  if [[ $DATE == $DATE_START ]]; then
  if [[ $DATE == $LBDATE ]]; then
    cp $id/wrfbdy_d01_update $WORK_DIR/rc/$DATE/wrfbdy_d01_$id 
  fi
  mv $id/wrfbdy_d01_update $WORK_DIR/fc/$DATE/wrfbdy_d01_$id
done

#ensemble mean (analysis for deterministic run)
if [[ ! -d mean ]]; then mkdir mean; fi
cd mean
ln -fs ../parame.in .
ln -fs $WRFDA_DIR/var/da/da_update_bc.exe .
##for when $LBDATE>$PREVDATE by Minamide 2014.11.23
#if [ $LBDATE -ge $PREVDATE ] && [ $LBDATE != $DATE ]; then
#  ln -fs $WORK_DIR/rc/$PREVDATE/wrfbdy_d01 .
#  ln -fs $WORK_DIR/rc/$PREVDATE/wrfinput_d01 .
#else
ln -fs $WORK_DIR/rc/$LBDATE/wrfbdy_d01 .
ln -fs $WORK_DIR/rc/$LBDATE/wrfinput_d01 .
#fi
#ln -fs $WORK_DIR/rc/$LBDATE/wrfbdy_d01 .
#ln -fs $WORK_DIR/rc/$LBDATE/wrfinput_d01 .
cp -L wrfbdy_d01 wrfbdy_d01_update
rm -f wrfinput_d01_update
ln -fs $WORK_DIR/fc/$DATE/wrfinput_d01 wrfinput_d01_update
./da_update_bc.exe >& update_bc.log
cd ..
watch_log mean/update_bc.log successfully 1 $rundir
mv mean/wrfbdy_d01_update $WORK_DIR/fc/$DATE/wrfbdy_d01

echo complete > stat

