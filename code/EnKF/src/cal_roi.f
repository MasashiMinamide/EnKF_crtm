!========================================================================================
   subroutine cal_hroi ( instrument, grid_id, iroi, ngxn ) 

   implicit none

   character (len=8), intent(in)          :: instrument
   integer, intent(in)                    :: grid_id, iroi
   integer, intent(inout)                 :: ngxn

!   if ( instrument == 'Radar   ' .or. instrument == 'aircft  ' .or.  &
!        instrument == 'metar   ' .or. instrument == 'satwnd  ' ) then
!!Successive covariance localization (SCL) technique:
!!http://hfip.psu.edu/fuz4/2011/WengZhang2011MWR.pdf
   if ( instrument == 'Radar   ' ) then
        if ( grid_id == 1 ) then
             ngxn = 1
        else if ( grid_id == 2 ) then
             ngxn = 1
             if( mod(iroi,3) == 1 ) ngxn = 3
        else if ( grid_id == 3 ) then
             ngxn = 1
             if( mod(iroi,3) == 1 ) ngxn = 3
             if( mod(iroi,9) == 1 ) ngxn = 9
        else if ( grid_id == 4 ) then
             ngxn = 1
             if( mod(iroi,3) == 1 ) ngxn = 3
             if( mod(iroi,9) == 1 ) ngxn = 9
             if( mod(iroi,27) == 1) ngxn = 27
        endif
   else
!        ngxn = 3**(grid_id-1)
! need to adjust HROI in namelist.enkf to match the (hroi_n_grid)*(grid spacing)=hroi_km
! namelist.enkf sets hroi_n_grid
       ngxn = 1
   endif

   end subroutine cal_hroi
!========================================================================================
   subroutine corr(dx,dy,dz,ngx,ngz,corr_coef)
! This is alternative routine to calculate corr_coef, if schur_matrix
! requires too much memory to be calculated before hand.

  implicit none

  real, intent(in)    :: dx,dy,dz        !dx: x distance(grids) from model grid to obs
  integer, intent(in) :: ngx, ngz        !ngx: horrizontal cutting off distances
  integer :: i,j,k
  real, intent(out)   :: corr_coef

  integer :: horradi
  real :: k1
  real :: comp_cov_factor
  real :: horrad, distance, distanceh

! calculate horizontal radius at height k
     horrad = (real(ngx)/real(ngz))*sqrt(real(ngz**2. - dz**2.))
     horradi = int(horrad)   ! grid points within the radius

! equivalence of k in terms of dx  ! added FZ 2004/09/09
     k1 = dz * real(ngx) / real(ngz)

        distanceh = sqrt(real(dx**2. + dy**2.))   ! hor. distance from z-axis

        if ((dx==0.) .and. (dy==0.) .and. (dz==0.)) then
           corr_coef = 1.

        else if (distanceh<=horrad) then

           distance  = sqrt( real(dx**2. + dy**2. + k1**2.))   ! 3-d distance from obs

           corr_coef  = comp_cov_factor(dble(distance),dble(ngx/2.))

        else
           corr_coef  = 0.

        end if

   end subroutine corr
!========================================================================================
   subroutine corr_matrix(nx,nz,cmatr)

! written by Altug Aksoy, 05/20/2003

! this subroutine computes the coefficient matrix to be used for
! compact correlation function calculations. the matrix is computed
! once and stored so that it can be refered to when calculating the gain.

  implicit none

  integer, intent(in) :: nx,nz
  integer :: i,j,k
  integer :: centerx, centerz, horradi, totradi

  real :: k1
  real , intent(out), dimension(2*nx+1,2*nx+1,2*nz+1) :: cmatr
  real :: comp_cov_factor
  real :: horrad, distance, distanceh, term1, term2, totrad, schur

  cmatr = 0.

  centerx = nx+1   ! location of origin (obs) within the matrix
  centerz = nz+1

  do k = -nz,nz

! calculate horizontal radius at height k
     horrad = (real(nx)/real(nz))*sqrt(real(nz**2. - k**2.))
     horradi = int(horrad)   ! grid points within the radius

! equivalence of k in terms of dx  ! added FZ 2004/09/09
     k1 = real(k) * real(nx) / real(nz)

     do j = -horradi,horradi
     do i = -horradi,horradi

        distanceh = sqrt(real(i**2. + j**2.))   ! hor. distance from z-axis

        if ((i==0) .and. (j==0) .and. (k==0)) then
           cmatr(centerx,centerx,centerz) = 1.

        else if (distanceh<=horrad) then

           distance  = sqrt( real(i**2. + j**2. + k1**2.))   ! 3-d distance from obs
!           distance  = sqrt( real(i**2. + j**2. ))   ! 2-d distance from obs

           schur  = comp_cov_factor(dble(distance),dble(nx/2.))
           cmatr(centerx+i, centerx+j,centerz+k) = schur

        end if

      enddo
      enddo

   enddo

   end subroutine corr_matrix
!========================================================================================
   subroutine corr_matrix_h(nx,cmatr)
! this subroutine computes the coefficient matrix to be used for
! compact correlation function calculations. the matrix is computed
! once and stored so that it can be refered to when calculating the gain.

  implicit none

  integer, intent(in) :: nx
  integer :: i,j,k
  integer :: centerx, horradi, totradi

  real , intent(out), dimension(2*nx+1,2*nx+1) :: cmatr
  real :: comp_cov_factor
  real :: horrad, distance, distanceh, term1, term2, totrad, schur

  cmatr = 0.

  centerx = nx+1   ! location of origin (obs) within the matrix
     do j = -nx, nx
     do i = -nx, nx
       distanceh = sqrt(real(i**2. + j**2.))   ! hor. distance from z-axis

        if ((i==0) .and. (j==0)) then
           cmatr(centerx,centerx) = 1.

        else if (distanceh<=real(nx)) then
           distance  = sqrt( real(i**2. + j**2. ))   ! 2-d distance from obs

           schur  = comp_cov_factor(dble(distance),dble(nx/2.))
           cmatr(centerx+i, centerx+j) = schur

        end if

     enddo
     enddo

  end subroutine corr_matrix_h
!==============================================================================
   function comp_cov_factor(z_in, c)

   implicit none

   real comp_cov_factor
   double precision z_in, c
   double precision z, r

!  Computes a covariance cutoff function from Gaspari and Cohn
!  (their eqn. 4.10) QJRMS, 125, 723-757.

!  z_in is the distance while c is the cutoff distance.
!  For distances greater than 2c, the cov_factor returned goes to 0.

   z = dabs(z_in)
   r = z / c

   if(z >= 2*c) then
      comp_cov_factor = 0.0
   else if(z >= c .and. z < 2*c) then
      comp_cov_factor =                                               &
          ( ( ( ( r/12.  -0.5 )*r  +0.625 )*r +5./3. )*r  -5. )*r     &
                                                 + 4. - 2./(3.*r)
   else
      comp_cov_factor =                                               &
          ( ( ( -0.25*r +0.5 )*r +0.625 )*r  -5./3. )*r**2 + 1.
   endif

   end function comp_cov_factor
!==============================================================================
   subroutine corr_elf(varname, satid, ch, ca, ngx, ngz, kk)
! This is routine to give correlation coefficient from ELF

   implicit none

   character (len=10), intent(in)  :: varname
   character (len=12), intent(in)  :: satid
   integer, intent(in)    :: ch
   real, intent(in)       :: ca
   integer, intent(inout) :: ngx, ngz
   real, intent(inout)    :: kk
   ! input for ELFs computed offline
   integer, parameter     :: n_ca = 19
   real, parameter        :: clevs = 2.0
   integer, dimension(n_ca) :: ngx_list, ngz_list, kk_list
 
   ngx_list = ngx
   ngz_list = ngz
   kk_list  = int(kk)
 
   if (trim(adjustl(satid)) == 'abi_gr' .or. trim(adjustl(satid)) == 'ahi_h8') then
    if (ch == 8) then
      select case (trim(adjustl(varname)))
        case('T')
          ngx_list = (/52, 28, 34, 30, 32, 28, 22, 20, 22, 24, 22, 22, 22, 24, 26, 28, 22, 20, 18 /)
          ngz_list = (/15, 15, 15, 12, 14, 14, 15, 17, 21, 22, 21, 22, 26, 29, 41, 55, 57, 59, 73 /)
          kk_list = (/42, 44, 47, 48, 49, 49, 49, 49, 48, 48, 49, 49, 49, 51, 49, 49, 47, 46, 39 /)
        case('QVAPOR')
          ngx_list = (/50, 42, 34, 26, 24, 22, 20, 20, 18, 16, 14, 16, 16, 16, 18, 18, 20, 16, 28 /)
          ngz_list = (/21, 21, 22, 23, 24, 26, 28, 28, 31, 33, 32, 33, 33, 37, 43, 49, 52, 55, 64 /)
          kk_list = (/44, 43, 43, 43, 43, 43, 43, 43, 43, 43, 43, 42, 42, 42, 40, 41, 41, 41, 37 /)
        case('QCLOUD')
          ngx_list = (/8, 8, 6, 6, 6, 6, 6, 6, 6, 6, 6, 82, 10, 8, 10, 10, 8, 8, 8 /)
          ngz_list = (/2, 2, 6, 10, 11, 15, 14, 15, 16, 16, 15, 14, 13, 14, 16, 21, 21, 29, 27 /)
          kk_list = (/41, 39, 41, 43, 42, 42, 42, 42, 43, 43, 43, 45, 44, 44, 41, 39, 39, 39, 35 /)
        case('QRAIN')
          ngx_list = (/4, 2, 4, 4, 10, 10, 10, 10, 12, 12, 10, 10, 12, 18, 12, 12, 10, 14, 10 /)
          ngz_list = (/3, 2, 3, 11, 31, 44, 48, 57, 83, 55, 47, 12, 15, 4, 52, 68, 72, 66, 76 /)
          kk_list = (/41, 44, 44, 41, 19, 23, 21, 20, 6, 21, 26, 42, 42, 43, 26, 18, 18, 22, 17 /)
        case('QICE')
          ngx_list = (/36, 34, 30, 24, 22, 20, 18, 18, 16, 16, 16, 16, 20, 20, 20, 20, 12, 10, 10 /)
          ngz_list = (/12, 20, 19, 20, 20, 20, 21, 23, 26, 78, 22, 19, 23, 19, 57, 44, 46, 48, 45 /)
          kk_list = (/40, 43, 43, 44, 45, 45, 46, 47, 48, 55, 49, 50, 52, 52, 55, 55, 50, 49, 48 /)
        case('QSNOW')
          ngx_list = (/20, 20, 18, 18, 20, 22, 20, 22, 20, 22, 20, 18, 18, 20, 18, 18, 16, 12, 12 /)
          ngz_list = (/16, 32, 40, 47, 48, 43, 58, 55, 73, 56, 60, 50, 54, 54, 53, 52, 49, 45, 44 /)
          kk_list = (/28, 28, 29, 28, 32, 36, 32, 36, 33, 39, 38, 45, 43, 45, 45, 44, 42, 45, 45 /)
        case('QGRAUP')
          ngx_list = (/20, 12, 14, 14, 14, 14, 16, 18, 18, 18, 16, 16, 18, 16, 16, 14, 16, 16, 102 /)
          ngz_list = (/5, 20, 34, 46, 34, 47, 57, 57, 57, 58, 61, 67, 62, 60, 66, 63, 62, 61, 60 /)
          kk_list = (/14, 18, 23, 28, 37, 36, 34, 37, 38, 39, 38, 40, 43, 45, 43, 42, 41, 43, 44 /)
        case('PH')
          ngx_list = (/88, 52, 32, 28, 26, 20, 20, 18, 16, 14, 10, 10, 14, 28, 12, 18, 16, 18, 12 /)
          ngz_list = (/21, 16, 22, 20, 20, 25, 36, 78, 59, 55, 43, 40, 7, 3, 22, 48, 100, 120, 120 /)
          kk_list = (/49, 51, 10, 10, 10, 12, 14, 6, 20, 20, 22, 19, 28, 52, 12, 6, 6, 6, 13 /)
        case('MU')
          ngx_list = (/0, 0, 4, 4, 10, 16, 20, 24, 30, 52, 54, 52, 32, 26, 36, 32, 18, 14, 18 /)
          ngz_list = (/999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999 /)
          kk_list = (/1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 /)
        case('P')
          ngx_list = (/0, 4, 26, 22, 10, 16, 20, 24, 30, 52, 52, 50, 24, 26, 24, 16, 14, 16, 18 /)
          ngz_list = (/1, 1, 2, 2, 2, 92, 21, 75, 118, 49, 3, 3, 4, 3, 11, 11, 16, 20, 27 /)
          kk_list = (/6, 18, 14, 14, 51, 55, 50, 55, 55, 35, 55, 55, 55, 55, 55, 55, 55, 55, 55 /)
        case('U')
          ngx_list = (/50, 44, 42, 36, 34, 36, 34, 32, 32, 30, 28, 28, 32, 32, 34, 42, 52, 28, 50 /)
          ngz_list = (/4, 5, 13, 13, 14, 15, 17, 19, 20, 19, 16, 15, 17, 22, 32, 41, 39, 35, 40 /)
          kk_list = (/52, 43, 45, 45, 45, 46, 46, 46, 46, 48, 49, 50, 50, 50, 48, 47, 46, 48, 45 /)
        case('V')
          ngx_list = (/42, 48, 38, 36, 34, 32, 32, 30, 28, 26, 22, 24, 42, 46, 52, 28, 24, 24, 12 /)
          ngz_list = (/9, 17, 18, 17, 18, 20, 22, 23, 22, 20, 18, 17, 11, 10, 10, 24, 28, 23, 14 /)
          kk_list = (/42, 45, 46, 45, 46, 45, 45, 45, 46, 47, 49, 50, 52, 53, 53, 50, 47, 48, 52 /)
        case('PSFC')
          ngx_list = (/0, 0, 26, 20, 22, 24, 46, 52, 50, 102, 102, 52, 44, 2, 38, 36, 94, 50, 34 /)
          ngz_list = (/999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999 /)
          kk_list = (/1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 /)
        case('U10')
          ngx_list = (/18, 8, 0, 0, 0, 20, 18, 46, 50, 2, 2, 4, 4, 0, 2, 40, 44, 2, 2 /)
          ngz_list = (/999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999 /)
          kk_list = (/1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 /)
        case('V10')
          ngx_list = (/6, 0, 2, 0, 28, 32, 34, 32, 38, 44, 22, 2, 2, 2, 2, 2, 2, 2, 8 /)
          ngz_list = (/999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999 /)
          kk_list = (/1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 /)
        case('TSK')
          ngx_list = (/26, 38, 30, 10, 12, 14, 14, 10, 16, 20, 6, 18, 16, 26, 20, 18, 26, 52, 84 /)
          ngz_list = (/999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999 /)
          kk_list = (/1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 /)
      end select
    else
       write(*,*) 'ELFs ERROR!!! Please prepare ELFs for channel ',ch
    endif
   else
      write(*,*) 'ELFs ERROR!!! Please prepare ELFs for ',trim(adjustl(satid))
   endif
   ngx = ngx_list(min(int(ca/clevs)+1,n_ca))
   ngz = ngz_list(min(int(ca/clevs)+1,n_ca))
   kk = real(kk_list(min(int(ca/clevs)+1,n_ca)))
   end subroutine corr_elf
!========================================================================================

