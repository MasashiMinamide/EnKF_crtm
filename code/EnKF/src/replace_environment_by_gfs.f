  Program replace_environment_by_gfs

!----------------------------------------------------------------
! This program is used to replace environment by GFS

! Input files:  atcf_file:  tcvitals.dat
! wrfinput (or output): wrfinput_gfs and wrfinput

!-----work flow 
! 1, readin observed center from TCVitials file
! 2, find the i,j by mapping the lat, lon of TCVitals
! 3, replace the environemt:
!    Xnew = a*wrfinput + (1-a)*wrfinput_gfs
!    while: r<=300, a=1.0, r is the distance from the grid to center
!           r> 600, a=0.0,
!           300<r<=600, a=(r-300)/(600-300) 

!----------------------------------------------------------------
  use netcdf
  implicit none

  integer              :: iost,ilat,ilon,cdfid,rcode,ix,jx,kx,i,j,k,tcind1_i,tcind1_j
  integer              :: varnum, ii,jj,kk, m, fid
  character(len= 1)    :: ilatc, ilonc
  real                 :: dx, tclat, tclon, dis0, dis1, r, a, Rmin, Rmax

  real, allocatable, dimension(:,:) :: xlat, xlong

  character (len=10), allocatable, dimension(:) :: varname
  character (len=10)                            :: var

  real, allocatable, dimension(:,:,:)   :: gfs     !!! initial field
  real, allocatable, dimension(:,:,:)   :: dat

  Rmin = 600
  Rmax = 800
!----------------------------------------------------------------
! Get storm center from "tcvitals.dat"
  open(10, file="tcvitals.dat", status='old', form = 'formatted', iostat = iost )
  if ( iost .ne. 0 ) then
     stop 'NO a-deck file found!'
  endif
  read(10,'(32x, i4, a1, i5, a1)')ilat,ilatc,ilon,ilonc
  tclat=ilat/10.
  if (ilatc.eq.'S')tclat=-ilat/10.
  tclon=ilon/10.
  if (ilonc.eq.'W')tclon=-ilon/10.
  write(*,*)'TC center:', tclat, tclon

!----------------------------------------------------------------
! Map the TC center to the WRF domain
  rcode = nf_open ('wrfinput', NF_NOWRITE, cdfid)
  rcode = nf_get_att_int (cdfid, nf_global, 'WEST-EAST_PATCH_END_UNSTAG', ix)
  rcode = nf_get_att_int (cdfid, nf_global, 'SOUTH-NORTH_PATCH_END_UNSTAG', jx)
  rcode = nf_get_att_int (cdfid, nf_global, 'BOTTOM-TOP_PATCH_END_UNSTAG', kx)
  rcode = nf_get_att_real(cdfid, nf_global, 'DX', dx)
  dx=dx/1000.
  rcode = nf_close(cdfid)
  write(*,*)'ix,jx,kx=',ix,jx,kx
  allocate( xlat (ix, jx) ) 
  allocate( xlong (ix, jx) ) 
  call get_variable2d( 'wrfinput   ', 'XLAT      ', ix, jx, 1, xlat )
  call get_variable2d( 'wrfinput   ', 'XLONG     ', ix, jx, 1, xlong )
  if ( tclat.gt.xlat(1,1) .and. tclat.lt.xlat(1,jx) .and.      &
       tclon.gt.xlong(1,1) .and. tclon.lt.xlong(ix,1) ) then
     dis0=999999. 
     do j = 1, jx 
     do i = 1, ix
        dis1 = (tclat-xlat(i,j))**2 + (tclon-xlong(i,j))**2
        if ( dis1 <= dis0 ) then
           dis0 = dis1
           tcind1_i = i
           tcind1_j = j
        end if
     end do
     end do
  else
     tcind1_i = -9999
     tcind1_j = -9999
  end if
  write(*,*)'TC center in WRFout:', tcind1_i, tcind1_j

!----------------------------------------------------------------
! variables will be replaced
  varnum = 26 
  allocate( varname (varnum) )
  varname = (/'U         ', 'V         ', 'W         ', 'PH        ', 'PHB       ', &
              'T         ', 'MU        ', 'MUB       ', 'P         ', &
              'Q2        ', 'T2        ', 'TH2       ', 'PSFC      ', 'PB        ', &
              'U10       ', 'V10       ', 'QVAPOR    ', 'QCLOUD    ', 'QRAIN     ', &
              'QICE      ', 'QSNOW     ', 'QGRAUP    ', 'TSK       ', 'HGT       ', &
              'TMN       ', 'SST       '/)

!----------------------------------------------------------------
  do_wrf_var  : do m = 1, varnum

!.... get dimensions
      var = varname(m)
      call wrf_var_dimension ( var, ix, jx, kx, ii, jj, kk )
      allocate( gfs   ( ii, jj, kk ) )
      allocate( dat   ( ii, jj, kk ) )
      write(*,*)var, ii, jj, kk

!....... get data
      if ( kk > 1 ) then
         call get_variable3d('wrfinput_gfs', var, ii, jj, kk, 1, gfs)
         call get_variable3d('wrfinput',     var, ii, jj, kk, 1, dat)
      else if ( kk == 1 ) then
         call get_variable2d('wrfinput_gfs', var, ii, jj, 1, gfs)
         call get_variable2d('wrfinput',     var, ii, jj, 1, dat)
      endif

!....... combine gfs and work to dat
      do j = 1, jj
      do i = 1, ii
         !r = sqrt((i-tcind1_i)**2+(j-tcind1_j)**2)*dx
         r = (((i-tcind1_i)**2+(j-tcind1_j)**2)**0.5)*dx
         if ( r > Rmax ) then
            a = 0.0
         else if ( r < Rmin ) then
            a = 1.0
         else if ( r <= Rmax .and. r >= Rmin )then
            a = (Rmax-r)/(Rmax-Rmin)
         endif
         do k = 1, kk
            dat(i,j,k)=dat(i,j,k)*a+gfs(i,j,k)*(1.-a)
         end do
      end do
      end do

!....... put back to wrfinput
      call open_file('wrfinput   ', nf_write, fid)
      if ( kk > 1 ) then
         call write_variable3d(fid, var, ii, jj, kk, 1, dat)
      else if ( kk == 1 ) then
         call write_variable2d(fid, var, ii, jj, 1, dat)
      endif 
      call close_file( fid )

      deallocate( gfs  )
      deallocate( dat  )
  end do do_wrf_var

  write(*,*)'!!! Successful completion of replace_environment.exe!!!'


end Program replace_environment_by_gfs

!==============================================================================
subroutine wrf_var_dimension ( var, ix, jx, kx, ii, jj, kk )

   character(len=10), intent(in)   :: var
   integer, intent(in)             :: ix, jx, kx
   integer, intent(out)            :: ii, jj, kk

   ii = ix
   jj = jx
   kk = kx
   if      ( var == 'U         ' ) then
      ii = ix + 1
   else if ( var == 'V         ' ) then
      jj = jx + 1
   else if ( var == 'W         ' .or. var == 'PH        ' .or. var == 'PHB       ' ) then
      kk = kx + 1
   else if ( var == 'MU        ' .or. var == 'MUB       ' .or. var == 'Q2        '  &
        .or. var == 'T2        ' .or. var == 'TH2       ' .or. var == 'PSFC      '  &
        .or. var == 'SST       ' .or. var == 'TSK       ' .or. var == 'XICE      '  &
        .or. var == 'SFROFF    ' .or. var == 'UDROFF    ' .or. var == 'IVGTYP    '  &
        .or. var == 'ISLTYP    ' .or. var == 'VEGFRA    ' .or. var == 'GRDFLX    '  &
        .or. var == 'SNOW      ' .or. var == 'SNOWH     ' .or. var == 'CANWAT    '  &
        .or. var == 'MAPFAC_M  ' .or. var == 'F         '  &
        .or. var == 'E         ' .or. var == 'SINALPHA  ' .or. var == 'COSALPHA  '  &
        .or. var == 'HGT       ' .or. var == 'TSK       ' .or. var == 'RAINC     '  &
        .or. var == 'RAINNC    ' .or. var == 'SWDOWN    ' .or. var == 'GLW       '  &
        .or. var == 'XLAT      ' .or. var == 'XLONG     ' .or. var == 'TMN       '  &
        .or. var == 'XLAND     ' .or. var == 'PBLH      ' .or. var == 'HFX       '  &
        .or. var == 'QFX       ' .or. var == 'LH        ' .or. var == 'SNOWC     '  &
        .or. var == 'SR        ' .or. var == 'POTEVP    ' .or. var == 'U10       '  &
        .or. var == 'V10       '  ) then
      kk = 1
   else if ( var == 'MAPFAC_U  ' ) then
      kk = 1
      ii = ix + 1
   else if ( var == 'MAPFAC_V  ' ) then
      kk = 1
      jj = jx + 1
   else if ( var == 'FNM       ' .or. var == 'FNP       '  &
        .or. var == 'RDNW      ' .or. var == 'RDN       '  &
        .or. var == 'DNW       ' .or. var == 'DN        '  &
        .or. var == 'ZNU       '                          ) then
      ii = 1
      jj = 1
   else if ( var == 'ZNW       '                          ) then
      ii = 1
      jj = 1
      kk = kx + 1
   endif

end subroutine wrf_var_dimension

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
