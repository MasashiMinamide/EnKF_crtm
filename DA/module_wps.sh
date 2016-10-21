#!/bin/bash
. $CONFIG_FILE

rundir=$WORK_DIR/run/$DATE/wps
if [[ ! -d $rundir ]]; then mkdir -p $rundir; echo waiting > $rundir/stat; fi

cd $rundir
if [[ `cat stat` == "complete" ]]; then exit; fi

#Check dependency

#if CP < LBC_INTERVAL, cannot generate wrfinput and wrfbdy from LBC data
#instead, we will fetch wrfbdy from the previous cycle where LBC is available
#and wrfinput will be from the previous cycle wrf run.
if [[ $LBDATE != $DATE ]]; then echo complete > stat; exit; fi

#Setup for wps
echo running > stat
touch geogrid.log
touch ungrib.log
touch metgrid.log

export start_date=$start_date_cycle
#export run_minutes=`max $run_minutes_cycle $run_minutes_forecast $((LBC_INTERVAL*2))`
export run_minutes=`diff_time $DATE $DATE_END`


#####Link first guess files (FNL, GFS or ECWMF-interim)
  ln -sf $WPS_DIR/ungrib/Variable_Tables/Vtable.GFS Vtable
  fnldate=$start_date
  gribfile=""
  while [[ $fnldate -le `advance_time $start_date $run_minutes` ]]; do
    ccyymm=`echo $fnldate |cut -c1-6`
    dd=`echo $fnldate |cut -c7-8`
    hh=`echo $fnldate |cut -c9-10`
    file="$FNL_DIR/fnl_${ccyymm}${dd}_${hh}_00.grib2"
    if [ -e $file ]; then 
      gribfile="$gribfile $file"
    fi
    fnldate=`advance_time $fnldate $LBC_INTERVAL`
  done
  $WPS_DIR/link_grib.csh $gribfile

  $SCRIPT_DIR/namelist_wps.sh > namelist.wps

  if [[ $DATE == $DATE_START ]]; then
    echo "  Running geogrid.exe..."
    ln -sf $WPS_DIR/geogrid/src/geogrid.exe .
    ./geogrid.exe >& geogrid.log 
    watch_log geogrid.log Successful 1 $rundir
    mv geo_em.d0?.nc $WORK_DIR/rc/$DATE_START/.
  fi

  ln -fs $WORK_DIR/rc/$DATE_START/geo_em.d0?.nc .
  ln -fs $WPS_DIR/ungrib/src/ungrib.exe .
  ln -fs $WPS_DIR/metgrid/METGRID.TBL.ARW METGRID.TBL
  ln -fs $WPS_DIR/metgrid/src/metgrid.exe .

  echo "  Running ungrib.exe..."
  ./ungrib.exe >& ungrib.log
  echo "  Running metgrid.exe..."
  ./metgrid.exe >& metgrid.log

  watch_log metgrid.log Successful 1 $rundir
  mv met_em* $WORK_DIR/rc/$DATE/.
echo complete > stat
