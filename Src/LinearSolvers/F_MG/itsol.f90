module itsol_module

  use bl_types
  use multifab_module
  use cc_stencil_module
  use cc_stencil_apply_module

  implicit none

  integer, private, parameter :: def_bicg_max_iter = 1000
  integer, private, parameter :: def_cg_max_iter   = 1000

  private :: dgemv
  private :: itsol_defect, itsol_precon
  private :: jacobi_precon_1d, jacobi_precon_2d, jacobi_precon_3d
  private :: nodal_precon_1d, nodal_precon_2d, nodal_precon_3d

contains

    subroutine jacobi_precon_1d(a, u, r, ng)
      integer, intent(in) :: ng
      real(kind=dp_t), intent(in)    :: a(0:,:)
      real(kind=dp_t), intent(inout) :: u(1-ng:)
      real(kind=dp_t), intent(in)    :: r(:)
      integer :: i, nx
      nx = size(a,dim=2)
      do i = 1, nx
         u(i) = r(i)/a(0,i)
      end do
    end subroutine jacobi_precon_1d

    subroutine jacobi_precon_2d(a, u, r, ng)
      integer, intent(in) :: ng
      real(kind=dp_t), intent(in)    :: a(0:,:,:)
      real(kind=dp_t), intent(inout) :: u(1-ng:,1-ng:)
      real(kind=dp_t), intent(in)    :: r(:,:)
      integer :: i, j, nx, ny
      ny = size(a,dim=3)
      nx = size(a,dim=2)
      do j = 1, ny
         do i = 1, nx
            u(i,j) = r(i,j)/a(0,i,j)
         end do
      end do
    end subroutine jacobi_precon_2d

    subroutine jacobi_precon_3d(a, u, r, ng)
      integer, intent(in) :: ng
      real(kind=dp_t), intent(in)    :: a(0:,:,:,:)
      real(kind=dp_t), intent(inout) :: u(1-ng:,1-ng:,1-ng:)
      real(kind=dp_t), intent(in)    :: r(:,:,:)
      integer i, j, k, nx, ny, nz
      nz = size(a,dim=4)
      ny = size(a,dim=3)
      nx = size(a,dim=2)
      !$OMP PARALLEL DO PRIVATE(j,i,k) IF(nz.ge.7)
      do k = 1, nz
         do j = 1, ny
            do i = 1, nx
               u(i,j,k) = r(i,j,k)/a(0,i,j,k)
            end do
         end do
      end do
      !$OMP END PARALLEL DO
    end subroutine jacobi_precon_3d

    subroutine nodal_precon_1d(a, u, r, mm, ng)
      integer, intent(in) :: ng
      real(kind=dp_t), intent(in)  :: a(0:,:)
      real(kind=dp_t), intent(inout) :: u(1-ng:)
      real(kind=dp_t), intent(in)  :: r(0:)
      integer, intent(in)  :: mm(:)
      integer :: i, nx
      nx = size(a,dim=2)
      do i = 1, nx
         if (.not. bc_dirichlet(mm(i),1,0)) &
            u(i) = r(i)/a(0,i)
      end do
    end subroutine nodal_precon_1d

    subroutine nodal_precon_2d(a, u, r, mm, ng)
      integer, intent(in) :: ng
      real(kind=dp_t), intent(in)    :: a(0:,:,:)
      real(kind=dp_t), intent(inout) :: u(1-ng:,1-ng:)
      real(kind=dp_t), intent(in)    :: r(0:,0:)
      integer, intent(in)            :: mm(:,:)
      integer :: i, j, nx, ny
      ny = size(a,dim=3)
      nx = size(a,dim=2)
      do j = 1, ny
         do i = 1, nx
            if (.not. bc_dirichlet(mm(i,j),1,0)) then
               u(i,j) = r(i,j)/a(0,i,j)
            end if
         end do
      end do
    end subroutine nodal_precon_2d

    subroutine nodal_precon_3d(a, u, r, mm, ng)
      integer, intent(in) :: ng
      real(kind=dp_t), intent(in)    :: a(0:,:,:,:)
      real(kind=dp_t), intent(inout) :: u(1-ng:,1-ng:,1-ng:)
      real(kind=dp_t), intent(in)    :: r(0:,0:,0:)
      integer, intent(in)            :: mm(:,:,:)
      integer :: i, j, k, nx, ny, nz
      nz = size(a,dim=4)
      ny = size(a,dim=3)
      nx = size(a,dim=2)
      !$OMP PARALLEL DO PRIVATE(j,i,k) IF(nz.ge.7)
      do k = 1, nz
         do j = 1, ny
            do i = 1, nx
               if (.not. bc_dirichlet(mm(i,j,k),1,0)) then
                  u(i,j,k) = r(i,j,k)/a(0,i,j,k)
               end if
            end do
         end do
      end do
      !$OMP END PARALLEL DO
    end subroutine nodal_precon_3d

    subroutine diag_init_cc_1d(a, ng_a, r, ng_r, lo, hi)
      integer        , intent(in   )  :: ng_a, ng_r
      integer        , intent(in   )  :: lo(:),hi(:)
      real(kind=dp_t), intent(inout)  ::  a(0:,lo(1)-ng_a:)
      real(kind=dp_t), intent(inout)  ::  r(lo(1)-ng_r:   )

      integer         :: i, nc
      real(kind=dp_t) :: denom

      nc = size(a,dim=1)-1
      !
      ! Protect against divide by zero -- necessary for embedded boundary problems.
      !
      do i = lo(1),hi(1)
         if (abs(a(0,i)) .gt. zero) then
            denom = one / a(0,i)
            r(i     ) = r(i     ) * denom
            a(1:nc,i) = a(1:nc,i) * denom
            a(0,i   ) = one
         end if
      end do

    end subroutine diag_init_cc_1d

    subroutine diag_init_cc_2d(a, ng_a, r, ng_r, lo, hi)
      integer        , intent(in   )  :: ng_a, ng_r
      integer        , intent(in   )  :: lo(:),hi(:)
      real(kind=dp_t), intent(inout)  ::  a(0:,lo(1)-ng_a:,lo(2)-ng_a:)
      real(kind=dp_t), intent(inout)  ::  r(lo(1)-ng_r:,lo(2)-ng_r:   )

      integer         :: i, j, nc
      real(kind=dp_t) :: denom

      nc = size(a,dim=1)-1
      !
      ! Protect against divide by zero -- necessary for embedded boundary problems.
      !
      do j = lo(2),hi(2)
         do i = lo(1),hi(1)
            if (abs(a(0,i,j)) .gt. zero) then
               denom = one / a(0,i,j)
               r(i,j     ) = r(i,j     ) * denom
               a(1:nc,i,j) = a(1:nc,i,j) * denom
               a(0,i,j   ) = one
            end if
         end do
      end do

    end subroutine diag_init_cc_2d

    subroutine diag_init_cc_3d(a, ng_a, r, ng_r, lo, hi)
      integer        , intent(in   )  :: ng_a, ng_r
      integer        , intent(in   )  :: lo(:),hi(:)
      real(kind=dp_t), intent(inout)  ::  a(0:,lo(1)-ng_a:,lo(2)-ng_a:,lo(3)-ng_a:)
      real(kind=dp_t), intent(inout)  ::  r(lo(1)-ng_r:,lo(2)-ng_r:,lo(3)-ng_r:   )

      integer         :: i, j, k, nc
      real(kind=dp_t) :: denom

      nc = size(a,dim=1)-1
      !
      ! Protect against divide by zero -- necessary for embedded boundary problems.
      !
      !$OMP PARALLEL DO PRIVATE(j,i,k,denom) IF((hi(3)-lo(3)).ge.7)
      do k = lo(3),hi(3)
         do j = lo(2),hi(2)
            do i = lo(1),hi(1)
               if (abs(a(0,i,j,k)) .gt. zero) then
                  denom = one / a(0,i,j,k)
                  r(i,j,k     ) = r(i,j,k     ) * denom
                  a(1:nc,i,j,k) = a(1:nc,i,j,k) * denom
                  a(0,i,j,k   ) = one
               end if
            end do
         end do
      end do
      !$OMP END PARALLEL DO

    end subroutine diag_init_cc_3d

    subroutine diag_init_nd_1d(a, ng_a, r, ng_r, mm, ng_m, lo, hi)
      integer        , intent(in   )  :: ng_a, ng_r, ng_m
      integer        , intent(in   )  :: lo(:),hi(:)
      real(kind=dp_t), intent(inout)  ::  a(0:,lo(1)-ng_a:)
      real(kind=dp_t), intent(inout)  ::  r(lo(1)-ng_r:   )
      integer        , intent(inout)  :: mm(lo(1)-ng_m:   )

      integer         :: i, nc
      real(kind=dp_t) :: denom

      nc = size(a,dim=1)-1

      do i = lo(1),hi(1)+1
         if (.not. bc_dirichlet(mm(i),1,0)) then
            denom = one / a(0,i)
            r(i     ) = r(i     ) * denom
            a(1:nc,i) = a(1:nc,i) * denom
            a(0,i   ) = one
         end if
      end do

    end subroutine diag_init_nd_1d

    subroutine diag_init_nd_2d(a, ng_a, r, ng_r, mm, ng_m, lo, hi)
      integer        , intent(in   )  :: ng_a, ng_r, ng_m
      integer        , intent(in   )  :: lo(:),hi(:)
      real(kind=dp_t), intent(inout)  ::  a(0:,lo(1)-ng_a:,lo(2)-ng_a:)
      real(kind=dp_t), intent(inout)  ::  r(lo(1)-ng_r:,lo(2)-ng_r:   )
      integer        , intent(inout)  :: mm(lo(1)-ng_m:,lo(2)-ng_m:   )

      integer         :: i, j, nc
      real(kind=dp_t) :: denom

      nc = size(a,dim=1)-1

      do j = lo(2),hi(2)+1
         do i = lo(1),hi(1)+1
            if (.not. bc_dirichlet(mm(i,j),1,0)) then
               denom = one / a(0,i,j)
               r(i,j     ) = r(i,j     ) * denom
               a(1:nc,i,j) = a(1:nc,i,j) * denom
               a(0,i,j   ) = one
            end if
         end do
      end do

    end subroutine diag_init_nd_2d

    subroutine diag_init_nd_3d(a, ng_a, r, ng_r, mm, ng_m, lo, hi)
      integer        , intent(in   )  :: ng_a, ng_r, ng_m
      integer        , intent(in   )  :: lo(:),hi(:)
      real(kind=dp_t), intent(inout)  ::  a(0:,lo(1)-ng_a:,lo(2)-ng_a:,lo(3)-ng_a:)
      real(kind=dp_t), intent(inout)  ::  r(lo(1)-ng_r:,lo(2)-ng_r:,lo(3)-ng_r:   )
      integer        , intent(inout)  :: mm(lo(1)-ng_m:,lo(2)-ng_m:,lo(3)-ng_m:   )

      integer         :: i, j, k, nc
      real(kind=dp_t) :: denom

      nc = size(a,dim=1)-1

      !$OMP PARALLEL DO PRIVATE(j,i,k,denom) IF((hi(3)-lo(3)).ge.6)
      do k = lo(3),hi(3)+1
         do j = lo(2),hi(2)+1
            do i = lo(1),hi(1)+1
               if (.not. bc_dirichlet(mm(i,j,k),1,0)) then
                  denom = one / a(0,i,j,k)
                  r(i,j,k     ) = r(i,j,k     ) * denom
                  a(1:nc,i,j,k) = a(1:nc,i,j,k) * denom
                  a(0,i,j,k   ) = one
               end if
            end do
         end do
      end do
      !$OMP END PARALLEL DO

    end subroutine diag_init_nd_3d

  function itsol_converged(rr, bnorm, eps, abs_eps, rrnorm) result(r)
    use bl_prof_module

    type(multifab), intent(in )           :: rr
    real(dp_t),     intent(in )           :: bnorm, eps
    real(dp_t),     intent(in ), optional :: abs_eps
    real(dp_t),     intent(out), optional :: rrnorm

    real(dp_t) :: norm_rr
    logical    :: r

    type(bl_prof_timer), save :: bpt

    call build(bpt, "its_converged")

    norm_rr = norm_inf(rr)

    if ( present(rrnorm) ) rrnorm = norm_rr

    if ( present(abs_eps) ) then
      r = (norm_rr <= eps*bnorm) .or. (norm_rr <= abs_eps)
    else
      r = (norm_rr <= eps*bnorm) 
    endif

    call destroy(bpt)
  end function itsol_converged
  !
  ! Computes rr = aa * uu
  !
  subroutine itsol_stencil_apply(aa, rr, uu, mm, stencil_type, lcross, uniform_dh)

    use bl_prof_module

    use nodal_stencil_module, only: stencil_apply_1d_nodal, &
                                    stencil_apply_2d_nodal, &
                                    stencil_apply_3d_nodal

    type(multifab), intent(in)    :: aa
    type(multifab), intent(inout) :: rr
    type(multifab), intent(inout) :: uu
    type(imultifab), intent(in)   :: mm
    integer, intent(in)           :: stencil_type
    logical, intent(in)           :: lcross
    logical, intent(in),optional  :: uniform_dh

    logical                       :: luniform_dh

    real(kind=dp_t), pointer :: rp(:,:,:,:), up(:,:,:,:), ap(:,:,:,:)
    integer        , pointer :: mp(:,:,:,:)

    integer :: i, n, lo(get_dim(rr)), hi(get_dim(rr)), dm
    logical :: nodal_flag
    type(bl_prof_timer), save :: bpt

    call build(bpt, "its_stencil_apply")

    luniform_dh = .false. ; if ( present(uniform_dh) ) luniform_dh = uniform_dh

    call multifab_fill_boundary(uu, cross = lcross)

    dm = get_dim(rr)

    nodal_flag = nodal_q(uu)

    do i = 1, nfabs(rr)
       rp => dataptr(rr, i)
       up => dataptr(uu, i)
       ap => dataptr(aa, i)
       mp => dataptr(mm, i)
       lo = lwb(get_box(uu,i))
       hi = upb(get_box(uu,i))
       do n = 1, ncomp(rr)
          select case(dm)
          case (1)
             if ( .not. nodal_flag) then
                call stencil_apply_1d(ap(:,:,1,1), rp(:,1,1,n), nghost(rr), up(:,1,1,n), nghost(uu),  &
                                      mp(:,1,1,1), lo, hi, stencil_type)
             else
                call stencil_apply_1d_nodal(ap(:,:,1,1), rp(:,1,1,n), up(:,1,1,n),  &
                     mp(:,1,1,1), nghost(uu), stencil_type)
             end if
          case (2)
             if ( .not. nodal_flag) then
                call stencil_apply_2d(ap(:,:,:,1), rp(:,:,1,n), nghost(rr), up(:,:,1,n), nghost(uu),  &
                     mp(:,:,1,1), lo, hi, stencil_type)
             else
                call stencil_apply_2d_nodal(ap(:,:,:,1), rp(:,:,1,n), up(:,:,1,n),  &
                     mp(:,:,1,1), nghost(uu), stencil_type)
             end if
          case (3)
             if ( .not. nodal_flag) then
                call stencil_apply_3d(ap(:,:,:,:), rp(:,:,:,n), nghost(rr), up(:,:,:,n), nghost(uu),  &
                                      mp(:,:,:,1), stencil_type)
             else
                call stencil_apply_3d_nodal(ap(:,:,:,:), rp(:,:,:,n), up(:,:,:,n),  &
                     mp(:,:,:,1), nghost(uu), stencil_type, luniform_dh)
             end if
          end select
       end do
    end do

    call destroy(bpt)

  end subroutine itsol_stencil_apply
  !
  ! computes rr = aa * uu - rh
  !
  subroutine itsol_defect(ss, rr, rh, uu, mm, stencil_type, lcross, uniform_dh)
    use bl_prof_module
    type(multifab), intent(inout) :: uu, rr
    type(multifab), intent(in)    :: rh, ss
    type(imultifab), intent(in)   :: mm
    integer, intent(in)           :: stencil_type
    logical, intent(in)           :: lcross
    logical, intent(in), optional :: uniform_dh
    type(bl_prof_timer), save     :: bpt
    call build(bpt, "its_defect")
    call itsol_stencil_apply(ss, rr, uu, mm, stencil_type, lcross, uniform_dh)
    call saxpy(rr, rh, -1.0_dp_t, rr)
    call destroy(bpt)
  end subroutine itsol_defect

  subroutine itsol_BiCGStab_solve(aa, uu, rh, mm, eps, max_iter, verbose, stencil_type, lcross, &
       stat, singular_in, uniform_dh, nodal_mask)

    use bl_prof_module

    integer,         intent(in   ) :: max_iter
    type(imultifab), intent(in   ) :: mm
    type(multifab),  intent(inout) :: uu
    type(multifab),  intent(in   ) :: rh
    type(multifab),  intent(in   ) :: aa
    integer,         intent(in   ) :: stencil_type, verbose
    logical,         intent(in   ) :: lcross
    real(kind=dp_t), intent(in   ) :: eps

    integer,         intent(out), optional :: stat
    logical,         intent(in ), optional :: singular_in
    logical,         intent(in ), optional :: uniform_dh
    type(multifab),  intent(in ), optional :: nodal_mask

    type(layout)    :: la
    type(multifab)  :: rr, rt, pp, ph, vv, tt, ss, rh_local, aa_local
    real(kind=dp_t) :: rho_1, alpha, beta, omega, rho, bnorm, rnorm, den
    real(dp_t)      :: tres0, tnorms(2),rtnorms(2)
    integer         :: i, cnt, ng_for_res
    logical         :: nodal_solve, singular, nodal(get_dim(rh))

    real(dp_t), pointer :: pdst(:,:,:,:), psrc(:,:,:,:)

    type(bl_prof_timer), save :: bpt

    call build(bpt, "its_BiCGStab_solve")

    if ( present(stat) ) stat = 0

    singular    = .false.; if ( present(singular_in) ) singular    = singular_in
    ng_for_res  = 0;       if ( nodal_q(rh)          ) ng_for_res  = 1
    nodal_solve = .false.; if ( ng_for_res /= 0      ) nodal_solve = .true.

    nodal = nodal_flags(rh)

    la = get_layout(aa)

    call multifab_build(rr, la, 1, ng_for_res, nodal)
    call multifab_build(rt, la, 1, ng_for_res, nodal)
    call multifab_build(pp, la, 1, ng_for_res, nodal)
    call multifab_build(ph, la, 1, nghost(uu), nodal)
    call multifab_build(vv, la, 1, ng_for_res, nodal)
    call multifab_build(tt, la, 1, ng_for_res, nodal)
    call multifab_build(ss, la, 1, ng_for_res, nodal)
    !
    ! Use these for local preconditioning.
    !
    call multifab_build(rh_local, la, ncomp(rh), nghost(rh), nodal)
    call multifab_build(aa_local, la, ncomp(aa), nghost(aa), nodal_flags(aa), stencil = .true.)

    if ( nodal_solve ) then
       call setval(rr, ZERO, all=.true.)
       call setval(rt, ZERO, all=.true.)
       call setval(pp, ZERO, all=.true.)
       call setval(vv, ZERO, all=.true.)
       call setval(tt, ZERO, all=.true.)
       call setval(ss, ZERO, all=.true.)
    end if

    call copy(rh_local, 1, rh, 1, nc = ncomp(rh), ng = nghost(rh))
    !
    ! Copy aa -> aa_local; gotta do it by hand since it's a stencil multifab.
    !
    do i = 1, nfabs(aa)
       pdst => dataptr(aa_local, i)
       psrc => dataptr(aa      , i)
       call cpy_d(pdst, psrc)
    end do
    !
    ! Make sure to do singular adjustment *before* diagonalization.
    !
    if ( singular ) then
      call setval(ss,ONE)
      tnorms(1) = dot(rh_local, ss, nodal_mask, local = .true.)
      tnorms(2) = dot(      ss, ss, nodal_mask, local = .true.)
      call parallel_reduce(rtnorms, tnorms, MPI_SUM)
      rho = rtnorms(1) / rtnorms(2)
      if ( parallel_IOProcessor() .and. verbose > 0 ) then
         print *,'...singular adjustment to rhs: ', rho
      endif
      call saxpy(rh_local,-rho,ss)
      call setval(ss,ZERO,all=.true.)
    end if

    call diag_initialize(aa_local,rh_local,mm)

    call copy(ph, uu, ng = nghost(ph))

    cnt = 0
    !
    ! Compute rr = aa * uu - rh.
    !
    call itsol_defect(aa_local, rr, rh_local, uu, mm, stencil_type, lcross, uniform_dh); cnt = cnt + 1

    call copy(rt, rr)

    rho = dot(rt, rr, nodal_mask)
    !
    ! Elide some reductions by calculating local norms & then reducing all together.
    !
    tnorms(1) = norm_inf(rr,       local = .true.)
    tnorms(2) = norm_inf(rh_local, local = .true.)

    call parallel_reduce(rtnorms, tnorms, MPI_MAX)

    tres0 = rtnorms(1)
    bnorm = rtnorms(2)

    if ( parallel_IOProcessor() .and. verbose > 0 ) then
       write(*,*) "   BiCGStab: A and rhs have been rescaled. So has the error."
       write(unit=*, fmt='("    BiCGStab: Initial error (error0) =        ",g15.8)') tres0
    end if 

    if ( itsol_converged(rr, bnorm, eps) ) then
       if ( parallel_IOProcessor() .and. verbose > 0 ) then
          if ( tres0 < eps*bnorm ) then
             write(unit=*, fmt='("    BiCGStab: Zero iterations: rnorm ",g15.8," < eps*bnorm ",g15.8)') tres0,eps*bnorm
          end if
       end if
       go to 100
    end if

    rho_1 = ZERO

    do i = 1, max_iter
       rho = dot(rt, rr, nodal_mask)
       if ( i == 1 ) then
          call copy(pp, rr)
       else
          if ( rho_1 == ZERO ) then
             if ( present(stat) ) then
                call bl_warn("BiCGStab_SOLVE: failure 1"); stat = 2; goto 100
             end if
             call bl_error("BiCGStab: failure 1")
          end if
          if ( omega == ZERO ) then
             if ( present(stat) ) then
                call bl_warn("BiCGStab_SOLVE: failure 2"); stat = 3; goto 100
             end if
             call bl_error("BiCGStab: failure 2")
          end if
          beta = (rho/rho_1)*(alpha/omega)
          call saxpy(pp, -omega, vv)
          call saxpy(pp, rr, beta, pp)
       end if
       call copy(ph,pp)
       call itsol_stencil_apply(aa_local, vv, ph, mm, stencil_type, lcross, uniform_dh)
       cnt = cnt + 1
       den = dot(rt, vv, nodal_mask)
       if ( den == ZERO ) then
          if ( present(stat) ) then
             call bl_warn("BICGSTAB_solve: breakdown in bicg, going with what I have"); stat = 30; goto 100
          endif
          call bl_error("BiCGStab: failure 3")
       end if
       alpha = rho/den
       call saxpy(uu, alpha, ph)
       call saxpy(ss, rr, -alpha, vv)
       if ( verbose > 1 ) then
          rnorm = norm_inf(ss)
          if ( parallel_IOProcessor() ) then
             write(unit=*, fmt='("    BiCGStab: Half Iter        ",i4," rel. err. ",g15.8)') cnt/2, rnorm/bnorm
          end if
       end if
       if ( itsol_converged(ss, bnorm, eps, rrnorm = rnorm) ) exit
       call copy(ph,ss)
       call itsol_stencil_apply(aa_local, tt, ph, mm, stencil_type, lcross, uniform_dh) 
       cnt = cnt + 1
       !
       ! Elide a reduction here by calculating the two dot-products
       ! locally and then reducing them both in a single call.
       !
       tnorms(1) = dot(tt, tt, nodal_mask, local = .true.)
       tnorms(2) = dot(tt, ss, nodal_mask, local = .true.)

       call parallel_reduce(rtnorms, tnorms, MPI_SUM)

       den   = rtnorms(1)
       omega = rtnorms(2)

       if ( den == ZERO ) then
          if ( present(stat) ) then
             call bl_warn("BICGSTAB_solve: breakdown in bicg, going with what I have"); stat = 31; goto 100
          endif
          call bl_error("BiCGStab: failure 3")
       end if
       omega = omega/den
       call saxpy(uu, omega, ph)
       call saxpy(rr, ss, -omega, tt)
       if ( verbose > 1 ) then
          rnorm = norm_inf(rr)
          if ( parallel_IOProcessor() ) then
             write(unit=*, fmt='("    BiCGStab: Iteration        ",i4," rel. err. ",g15.8)') cnt/2, rnorm/bnorm
          end if
       end if
       if ( itsol_converged(rr, bnorm, eps, rrnorm = rnorm) ) exit
       rho_1 = rho
    end do

    if ( parallel_IOProcessor() .and. verbose > 0 ) then
       write(unit=*, fmt='("    BiCGStab: Final: Iteration  ", i3, " rel. err. ",g15.8)') cnt/2, rnorm/bnorm
       if ( rnorm < eps*bnorm ) then
          write(unit=*, fmt='("    BiCGStab: Converged: rnorm ",g15.8," < eps*bnorm ",g15.8)') rnorm,eps*bnorm
       end if
    end if

    if ( rnorm > bnorm ) then
       call setval(uu,ZERO,all=.true.)
       if ( present(stat) ) stat = 1
       if ( verbose > 0 .and.  parallel_IOProcessor() ) print *,'   BiCGStab: solution reset to zero'
    end if

    if ( i > max_iter ) then
       if ( present(stat) ) then
          stat = 1
       else
          call bl_error("BiCGSolve: failed to converge");
       end if
    end if

100 continue

    call destroy(rh_local)
    call destroy(aa_local)
    call destroy(rr)
    call destroy(rt)
    call destroy(pp)
    call destroy(ph)
    call destroy(vv)
    call destroy(tt)
    call destroy(ss)

    call destroy(bpt)

  end subroutine itsol_BiCGStab_solve

  subroutine dgemv(alpha,a,x,beta,y,m,n)

    integer,    intent(in   ) :: m,n
    real(dp_t), intent(in   ) :: a(m,n),x(n),alpha,beta
    real(dp_t), intent(inout) :: y(m)
    !
    !  dgemv  performs 
    !
    !     y := alpha*A*x + beta*y
    !
    !  where alpha and beta are scalars, x and y are vectors and A is an
    !  m by n matrix.
    !
    !  Further Details
    !  ===============
    !
    !  Level 2 Blas routine.
    !  The vector and matrix arguments are not referenced when N = 0, or M = 0
    !
    !  -- Written on 22-October-1986.
    !     Jack Dongarra, Argonne National Lab.
    !     Jeremy Du Croz, Nag Central Office.
    !     Sven Hammarling, Nag Central Office.
    !     Richard Hanson, Sandia National Labs.
    !
    !  =====================================================================
    !
    integer    :: i,j,jx
    real(dp_t) :: temp
    !
    ! Quick return if possible.
    !
    if ((m.eq.0) .or. (n.eq.0) .or. ((alpha.eq.zero).and.(beta.eq.one))) return
    !
    ! Start the operations. In this version the elements of A are
    ! accessed sequentially with one pass through A.
    !
    ! First form  y := beta*y.
    !
    if (beta.ne.one) then
       if (beta.eq.zero) then
          do i = 1,m
             y(i) = zero
          end do
       else
          do i = 1,m
             y(i) = beta*y(i)
          end do
       end if
    end if
    if (alpha.eq.zero) return
    !
    ! Now form  y := alpha*a*x + y.
    !
    jx = 1
    do j = 1,n
       if (x(jx).ne.zero) then
          temp = alpha*x(jx)
          do i = 1,m
             y(i) = y(i) + temp*a(i,j)
          end do
       end if
       jx = jx + 1
    end do

  end subroutine dgemv

  subroutine itsol_CABiCGStab_solve(aa, uu, rh, mm, eps, max_iter, verbose, stencil_type, lcross, &
       stat, singular_in, uniform_dh, nodal_mask)
    use bl_prof_module
    integer,         intent(in   ) :: max_iter
    type(imultifab), intent(in   ) :: mm
    type(multifab),  intent(inout) :: uu
    type(multifab),  intent(in   ) :: rh
    type(multifab),  intent(in   ) :: aa
    integer        , intent(in   ) :: stencil_type, verbose
    logical        , intent(in   ) :: lcross
    real(kind=dp_t), intent(in   ) :: eps

    integer,        intent(out), optional :: stat
    logical,        intent(in ), optional :: singular_in
    logical,        intent(in ), optional :: uniform_dh
    type(multifab), intent(in ), optional :: nodal_mask

    type(layout)    :: la
    type(multifab)  :: rr, rt, pp, pr, ss, rh_local, aa_local, ph, tt
    real(kind=dp_t) :: alpha, beta, omega, rho, bnorm
    real(dp_t)      :: rnorm0, delta, delta_next, L2_norm_of_rt
    real(dp_t)      :: tnorms(2),rtnorms(2), L2_norm_of_resid, L2_norm_of_r
    integer         :: i, m, niters, ng_for_res, nit, ret
    logical         :: nodal_solve, singular, nodal(get_dim(rh))
    logical         :: BiCGStabFailed, BiCGStabConverged
    real(dp_t)      :: g_dot_Tpaj, omega_numerator, omega_denominator, L2_norm_of_s

    real(dp_t), pointer :: pdst(:,:,:,:), psrc(:,:,:,:)

    type(bl_prof_timer), save :: bpt

    integer, parameter :: SSS = 4

    real(dp_t)  temp1(4*SSS+1)
    real(dp_t)  temp2(4*SSS+1)
    real(dp_t)  temp3(4*SSS+1)
    real(dp_t)     Tp(4*SSS+1, 4*SSS+1)
    real(dp_t)    Tpp(4*SSS+1, 4*SSS+1)
    real(dp_t)     aj(4*SSS+1)
    real(dp_t)     cj(4*SSS+1)
    real(dp_t)     ej(4*SSS+1)
    real(dp_t)   Tpaj(4*SSS+1)
    real(dp_t)   Tpcj(4*SSS+1)
    real(dp_t)  Tppaj(4*SSS+1)
    real(dp_t)      G(4*SSS+1, 4*SSS+1)
    real(dp_t)     gg(4*SSS+1)

    call build(bpt, "its_CABiCGStab_solve")

    if ( present(stat) ) stat = 0

    singular    = .false.; if ( present(singular_in) ) singular    = singular_in
    ng_for_res  = 0;       if ( nodal_q(rh)          ) ng_for_res  = 1
    nodal_solve = .false.; if ( ng_for_res /= 0      ) nodal_solve = .true.

    la    = get_layout(aa)
    nodal = nodal_flags(rh)

    aj    = zero
    cj    = zero
    ej    = zero
    Tpaj  = zero
    Tpcj  = zero
    Tppaj = zero
    temp1 = zero
    temp2 = zero
    temp3 = zero

    call SetMonomialBasis()

    call multifab_build(rr, la, 1, ng_for_res, nodal)
    call multifab_build(rt, la, 1, ng_for_res, nodal)
    call multifab_build(pp, la, 1, ng_for_res, nodal)
    call multifab_build(tt, la, 1, ng_for_res, nodal)
    call multifab_build(ph, la, 1, nghost(uu), nodal)
    !
    ! Contains the matrix powers of pp[] and rr[].
    !
    ! First 2*SSS+1 components are powers of pp[].
    ! Next  2*SSS   components are powers of rr[].
    !
    call multifab_build(pr, la, 4*SSS+1, nghost(uu), nodal)
    !
    ! Use these for local preconditioning.
    !
    call multifab_build(rh_local, la, ncomp(rh), nghost(rh), nodal)
    call multifab_build(aa_local, la, ncomp(aa), nghost(aa), nodal_flags(aa), stencil = .true.)

    if ( nodal_solve ) then
       call setval(rr, ZERO, all = .true.)
       call setval(rt, ZERO, all = .true.)
       call setval(pp, ZERO, all = .true.)
       call setval(ph, ZERO, all = .true.)
       call setval(pr, ZERO, all = .true.)
       call setval(tt, ZERO, all = .true.)
    end if

    call copy(rh_local, 1, rh, 1, nc = ncomp(rh), ng = nghost(rh))
    !
    ! Copy aa -> aa_local; gotta do it by hand since it's a stencil multifab.
    !
    do i = 1, nfabs(aa)
       pdst => dataptr(aa_local, i)
       psrc => dataptr(aa      , i)
       call cpy_d(pdst, psrc)
    end do
    !
    ! Make sure to do singular adjustment *before* diagonalization.
    !
    if ( singular ) then
       call multifab_build(ss, la, 1, ng_for_res, nodal)
       call setval(ss,ONE)
       tnorms(1) = dot(rh_local, ss, nodal_mask, local = .true.)
       tnorms(2) = dot(      ss, ss, nodal_mask, local = .true.)
       call parallel_reduce(rtnorms(1:2), tnorms(1:2), MPI_SUM)
       rho = rtnorms(1) / rtnorms(2)
       if ( parallel_IOProcessor() .and. verbose > 0 ) then
          print *,'...singular adjustment to rhs: ', rho
       endif
       call saxpy(rh_local,-rho,ss)
       call destroy(ss)
    end if

    call diag_initialize(aa_local,rh_local,mm)

    call copy(ph, uu, ng = nghost(ph))
    !
    ! Compute rr = aa * uu - rh.
    !
    call itsol_defect(aa_local, rr, rh_local, uu, mm, stencil_type, lcross, uniform_dh)

    call copy(rt,rr); call copy(pp,rr)
    !
    ! Elide some reductions by calculating local norms & then reducing all together.
    !
    tnorms(1) = norm_inf(rr,       local = .true.)
    tnorms(2) = norm_inf(rh_local, local = .true.)

    call parallel_reduce(rtnorms, tnorms, MPI_MAX)

    rnorm0 = rtnorms(1)
    bnorm  = rtnorms(2)

    delta         = dot(rt, rr, nodal_mask)
    L2_norm_of_rt = dsqrt(delta)

    if ( parallel_IOProcessor() .and. verbose > 0 ) then
       write(*,*) "   CABiCGStab: A and rhs have been rescaled. So has the error."
       write(unit=*, fmt='("    CABiCGStab: Initial error (error0) =        ",g15.8)') rnorm0
    end if 

    if ( itsol_converged(rr, bnorm, eps) .or. (delta.eq.zero) ) then
       if ( parallel_IOProcessor() .and. verbose > 0 ) then
          if ( rnorm0 < eps*bnorm ) then
             write(unit=*, fmt='("    CABiCGStab: Zero iterations: rnorm ",g15.8," < eps*bnorm ",g15.8)') rnorm0,eps*bnorm
          else if ( delta .eq. zero ) then
             write(unit=*, fmt='("    CABiCGStab: Zero iterations: delta == 0")')
          end if
       end if
       go to 100
    end if

    L2_norm_of_resid = 0

    BiCGStabFailed = .false. ; BiCGStabConverged = .false.

    niters = 0; m = 1

    do while (m <= max_iter .and. (.not. BiCGStabFailed) .and. (.not. BiCGStabConverged))
       !
       ! Compute the matrix powers on pp[] & rr[] (monomial basis).
       ! The 2*SSS+1 powers of pp[] followed by the 2*SSS powers of rr[].
       !
       call copy(PR,1,pp,1,1,0)
       call copy(ph,pp)

       do i = 2, 2*SSS+1
          call itsol_stencil_apply(aa_local, tt, ph, mm, stencil_type, lcross, uniform_dh)
          call copy(PR,i,tt,1,1,0)
          call copy(ph,1,tt,1,1,0)
       end do

       call copy(PR,2*SSS+2,rr,1,1,0)
       call copy(ph,rr)

       do i = 2*SSS+3,4*SSS+1
          call itsol_stencil_apply(aa_local, tt, ph, mm, stencil_type, lcross, uniform_dh)
          call copy(PR,i,tt,1,1,0)
          call copy(ph,1,tt,1,1,0)
       end do

       call BuildGramMatrix()

       aj = 0; aj(1)       = 1
       cj = 0; cj(2*SSS+2) = 1
       ej = 0

       do nit = 1, SSS
          call dgemv(one,  Tp, aj, zero,  Tpaj, 4*SSS+1, 4*SSS+1)
          call dgemv(one,  Tp, cj, zero,  Tpcj, 4*SSS+1, 4*SSS+1)
          call dgemv(one, Tpp, aj, zero, Tppaj, 4*SSS+1, 4*SSS+1)

          g_dot_Tpaj = dot_product(gg,Tpaj)

          if ( g_dot_Tpaj == zero ) then
             if ( parallel_IOProcessor() .and. verbose > 0 ) &
                  print*, "CGSolver_CABiCGStab: g_dot_Tpaj == 0, nit = ", nit
             BiCGStabFailed = .true.; ret = 1; exit
          end if

          alpha = delta / g_dot_Tpaj

          if ( is_an_inf(alpha) ) then
             if ( verbose > 1 .and. parallel_IOProcessor() ) &
                  print*, "CGSolver_CABiCGStab: alpha == inf, nit = ", nit
             BiCGStabFailed = .true.; ret = 2; exit
          end if

          temp1 = Tpcj - alpha * Tppaj
          call dgemv(one, G, temp1, zero, temp2, 4*SSS+1, 4*SSS+1)
          temp3 = cj - alpha * Tpaj

          omega_numerator   = dot_product(temp3, temp2)
          omega_denominator = dot_product(temp1, temp2)
          !
          ! NOTE: omega_numerator/omega_denominator can be 0/x or 0/0, but should never be x/0.
          !
          ! If omega_numerator==0, and ||s||==0, then convergence, x=x+alpha*aj.
          ! If omega_numerator==0, and ||s||!=0, then stabilization breakdown.
          !
          ! Partial update of ej must happen before the check on omega to ensure forward progress !!!
          !
          ej = ej + alpha * aj
          !
          ! ej has been updated so consider that we've done an iteration since
          ! even if we break out of the loop we'll be able to update "uu".
          !
          niters = niters + 1
          !
          ! Calculate the norm of Saad's vector 's' to check intra s-step convergence.
          !
          temp1 = cj - alpha * Tpaj

          call dgemv(one, G, temp1, zero, temp2, 4*SSS+1, 4*SSS+1)

          L2_norm_of_s = dot_product(temp1,temp2)

          L2_norm_of_resid = zero; if ( L2_norm_of_s > 0 ) L2_norm_of_resid = dsqrt(L2_norm_of_s)

          if ( L2_norm_of_resid < eps*L2_norm_of_rt ) then
             if ( verbose > 1 .and. (L2_norm_of_resid .eq. zero) .and. parallel_IOProcessor() ) &
                  print*, "CGSolver_CABiCGStab: L2 norm of s: ", L2_norm_of_s
             BiCGStabConverged = .true.; exit
          end if

          if ( omega_denominator .eq. zero ) then
             if ( verbose > 1 .and. parallel_IOProcessor() ) &
                print*, "CGSolver_CABiCGStab: omega_denominator == 0, nit = ", nit
             BiCGStabFailed = .true.; ret = 3; exit
          end if

          omega = omega_numerator / omega_denominator

          if ( verbose > 1 .and. parallel_IOProcessor() ) then
             if ( omega .eq. zero  ) print*, "CGSolver_CABiCGStab: omega == 0, nit = ", nit
             if ( is_an_inf(omega) ) print*, "CGSolver_CABiCGStab: omega == inf, nit = ", nit
          end if

          if ( omega .eq. zero ) then
             BiCGStabFailed = .true.; ret = 4; exit
          end if
          if ( is_an_inf(omega) ) then
             BiCGStabFailed = .true.; ret = 4; exit
          end if
          !
          ! Complete the update of ej & cj now that omega is known to be ok.
          !
          ej = ej +  omega          * cj
          ej = ej - (omega * alpha) * Tpaj
          cj = cj -  omega          * Tpcj
          cj = cj -          alpha  * Tpaj
          cj = cj + (omega * alpha) * Tppaj
          !
          ! Do an early check of the residual to determine convergence.
          !
          call dgemv(one, G, cj, zero, temp1, 4*SSS+1, 4*SSS+1)
          !
          ! sqrt( (cj,Gcj) ) == L2 norm of the intermediate residual in exact arithmetic.
          ! However, finite precision can lead to the norm^2 being < 0 (Jim Demmel).
          ! If cj_dot_Gcj < 0 we flush to zero and consider ourselves converged.
          !
          L2_norm_of_r = dot_product(cj,temp1)

          L2_norm_of_resid = zero; if ( L2_norm_of_r > 0 ) L2_norm_of_resid = dsqrt(L2_norm_of_r)

          if ( L2_norm_of_resid < eps*L2_norm_of_rt ) then
             if ( verbose > 1 .and. (L2_norm_of_resid .eq. zero) .and. parallel_IOProcessor() ) &
                  print*, "CGSolver_CABiCGStab: L2_norm_of_r: ", L2_norm_of_r
             BiCGStabConverged = .true.; exit
          end if

          delta_next = dot_product(gg,cj)

          if ( verbose > 1 .and. parallel_IOProcessor() ) then
             if ( delta_next .eq. zero  ) print*, "CGSolver_CABiCGStab: delta == 0, nit = ", nit
             if ( is_an_inf(delta_next) ) print*, "CGSolver_CABiCGStab: delta == inf, nit = ", nit
          end if
          if ( delta_next .eq. zero ) then
             BiCGStabFailed = .true.; ret = 5; exit
          end if
          if ( is_an_inf(delta_next) ) then
             BiCGStabFailed = .true.; ret = 5; exit
          end if

          beta = (delta_next/delta)*(alpha/omega)

          if ( verbose > 1 .and. parallel_IOProcessor() ) then
             if ( beta .eq. zero  ) print*, "CGSolver_CABiCGStab: beta == 0, nit = ", nit
             if ( is_an_inf(beta) ) print*, "CGSolver_CABiCGStab: beta == inf, nit = ", nit
          end if
          if ( beta .eq. zero ) then
             BiCGStabFailed = .true.; ret = 6; exit
          end if
          if ( is_an_inf(beta) ) then
             BiCGStabFailed = .true.; ret = 6; exit
          end if

          aj = cj +          beta  * aj
          aj = aj - (omega * beta) * Tpaj

          delta = delta_next
       end do
       !
       ! Update iterates.
       !
       do i = 1,4*SSS+1
          call saxpy(uu,1,ej(i),PR,i,1)
       end do

       call copy(pp,1,PR,1,1)
       call mult_mult(pp,aj(1))

       do i = 2,4*SSS+1
          call saxpy(pp,1,aj(i),PR,i,1)
       end do

       call copy(rr,1,PR,1,1)
       call mult_mult(rr,cj(1))

       do i = 2,4*SSS+1
          call saxpy(rr,1,cj(i),PR,i,1)
       end do

       if ( (.not. BiCGStabFailed) .and. (.not. BiCGStabConverged) ) m = m + SSS
    end do

    if ( parallel_IOProcessor() .and. verbose > 0 ) then
       write(unit=*, fmt='("    CABiCGStab: Final: Iteration  ", i3, " rel. err. ",g15.8)') niters, L2_norm_of_resid
       if ( BiCGStabConverged ) then
          write(unit=*, fmt='("    CABiCGStab: Converged: rnorm ",g15.8," < eps*bnorm ",g15.8)') &
               L2_norm_of_resid,eps*L2_norm_of_rt
       end if
    end if

    if ( L2_norm_of_resid > L2_norm_of_rt ) then
       call setval(uu,ZERO,all=.true.)
       if ( present(stat) ) stat = 1
       if ( parallel_IOProcessor() .and. verbose > 0 ) then
          print *,'   CABiCGStab: solution reset to zero'
       end if
    end if

    if ( m > max_iter ) then
       if ( present(stat) ) then
          stat = 1
       else
          call bl_error("CABiCGSolve: failed to converge");
       end if
    end if

100 continue

    call destroy(rh_local)
    call destroy(aa_local)
    call destroy(rr)
    call destroy(rt)
    call destroy(pp)
    call destroy(tt)
    call destroy(ph)
    call destroy(pr)

    call destroy(bpt)

  contains

    subroutine SetMonomialBasis ()

      Tp = zero

      do i = 1,2*SSS
         Tp(i+1,i) = one
      end do
      do i = 2*SSS+2, 4*SSS
         Tp(i+1,i) = one
      end do

      Tpp = zero

      do i = 1,2*SSS-1
         Tpp(i+2,i) = one
      end do
      do i = 2*SSS+2, 4*SSS-1
         Tpp(i+2,i) = one
      end do

    end subroutine SetMonomialBasis

    subroutine BuildGramMatrix ()

      integer, parameter :: Nrows = 4*SSS+1, Ncols = 4*SSS+2

      integer    :: mm, nn, cnt
      real(dp_t) :: Gram(Nrows, Ncols), tmp(Nrows*Ncols)

      do mm = 1, Nrows
         do nn = mm, Nrows
            Gram(mm,nn) = dot(PR, mm, PR, nn, nodal_mask = nodal_mask, local = .true.)
         end do
         Gram(mm,Ncols) = dot(PR, mm, rt,  1, nodal_mask = nodal_mask, local = .true.)
      end do
      !
      ! Fill in strict lower triangle using symmetry.
      !
      do mm = 1, Nrows
         do nn = 1, mm-1
            Gram(mm,nn) = Gram(nn,mm)
         end do
      end do
      !
      ! Reduce everything at once into "tmp"
      !
      call parallel_reduce(tmp, reshape(Gram,shape(tmp)), MPI_SUM)

      cnt = 1
      do nn = 1, Ncols
         do mm = 1, Nrows
            Gram(mm,nn) = tmp(cnt)
            cnt = cnt + 1
         end do
      end do
      !
      ! Form G[][] and g[] from Gram[][].
      !
      G(1:Nrows,1:Nrows) = Gram(1:Nrows,1:Nrows)
      !
      ! Last column goes to g[].
      !
      gg = Gram(:,Ncols)

    end subroutine BuildGramMatrix

  end subroutine itsol_CABiCGStab_solve

  subroutine itsol_CG_Solve(aa, uu, rh, mm, eps, max_iter, verbose, stencil_type, lcross, &
                            stat, singular_in, uniform_dh, nodal_mask)
    use bl_prof_module
    integer    , intent(in   ) :: max_iter, verbose, stencil_type
    logical    , intent(in   ) :: lcross
    real(dp_t) , intent(in   ) :: eps

    integer, intent(  out), optional :: stat
    logical, intent(in   ), optional :: singular_in
    logical, intent(in   ), optional :: uniform_dh
    type(multifab), intent(in), optional :: nodal_mask

    type( multifab), intent(in)    :: aa
    type( multifab), intent(inout) :: uu
    type( multifab), intent(in)    :: rh
    type(imultifab), intent(in)    :: mm

    type(multifab) :: rr, zz, pp, qq
    type(multifab) :: aa_local, rh_local
    real(kind = dp_t) :: rho_1, alpha, beta, bnorm, rho, rnorm, den, tres0
    type(layout) :: la
    integer :: i, ng_for_res
    logical :: nodal_solve, nodal(get_dim(rh))
    logical :: singular 
    integer :: cnt
    real(dp_t), pointer :: pdst(:,:,:,:), psrc(:,:,:,:)
    real(dp_t) :: tnorms(2), rtnorms(2)

    type(bl_prof_timer), save :: bpt

    call build(bpt, "its_CG_Solve")

    if ( present(stat) ) stat = 0

    singular    = .false.; if ( present(singular_in) ) singular = singular_in
    ng_for_res  = 0;       if ( nodal_q(rh)          ) ng_for_res = 1
    nodal_solve = .false.; if ( ng_for_res /= 0      ) nodal_solve = .true.

    nodal = nodal_flags(rh)

    la = get_layout(aa)
    call multifab_build(rr, la, 1, ng_for_res, nodal)
    call multifab_build(zz, la, 1, ng_for_res, nodal)
    call multifab_build(pp, la, 1, nghost(uu), nodal)
    call multifab_build(qq, la, 1, ng_for_res, nodal)

    if ( nodal_solve ) then
       call setval(rr,ZERO,all=.true.)
       call setval(zz,ZERO,all=.true.)
       call setval(qq,ZERO,all=.true.)
    end if
    call setval(pp, ZERO, all=.true.)

    ! Use these for local preconditioning
    call multifab_build(rh_local, la, ncomp(rh), nghost(rh), nodal)

    call multifab_build(aa_local, la, ncomp(aa), nghost(aa), nodal_flags(aa), stencil = .true.)

    call copy(rh_local, 1, rh, 1, nc = ncomp(rh), ng = nghost(rh))

    ! Copy aa -> aa_local; gotta do it by hand since it's a stencil multifab.
    do i = 1, nfabs(aa)
       pdst => dataptr(aa_local, i)
       psrc => dataptr(aa      , i)
       call cpy_d(pdst, psrc)
    end do

    call diag_initialize(aa_local,rh_local,mm)

    cnt = 0
    ! compute rr = aa * uu - rh_local
    call itsol_defect(aa_local, rr, rh_local, uu, mm, stencil_type, lcross, uniform_dh)  
    cnt = cnt + 1

    if ( singular .and. nodal_solve ) then
      call setval(zz,ONE)
      rho = dot(rr, zz, nodal_mask) / dot(zz,zz)
      call saxpy(rr,-rho,zz)
      call setval(zz,ZERO,all=.true.)
    end if
    !
    ! Elide some reductions by calculating local norms & then reducing all together.
    !
    tnorms(1) = norm_inf(rr,       local=.true.)
    tnorms(2) = norm_inf(rh_local, local=.true.)

    call parallel_reduce(rtnorms, tnorms, MPI_MAX)

    tres0 = rtnorms(1)
    bnorm = rtnorms(2)

    if ( parallel_IOProcessor() .and. verbose > 0) then
       write(unit=*, fmt='("          CG: Initial error (error0) =        ",g15.8)') tres0
    end if

    i = 0
    if ( itsol_converged(rr, bnorm, eps) ) then
       if (parallel_IOProcessor() .and. verbose > 0) then
          if (tres0 < eps*bnorm) then
             write(unit=*, fmt='("          CG: Zero iterations: rnorm ",g15.8," < eps*bnorm ",g15.8)') tres0,eps*bnorm
          end if
       end if
       go to 100
    end if

    rho_1 = ZERO

    do i = 1, max_iter
       call copy(zz,rr)
       rho = dot(rr, zz, nodal_mask)
       if ( i == 1 ) then
          call copy(pp, zz)
          call itsol_precon(aa_local, zz, rr, mm)
       else
          if ( rho_1 == ZERO ) then
             if ( present(stat) ) then
                call bl_warn("CG_solve: failure 1"); stat = 1; goto 100
             end if
             call bl_error("CG_solve: failure 1")
          end if
          beta = rho/rho_1
          call saxpy(pp, zz, beta, pp)
       end if
       call itsol_stencil_apply(aa_local, qq, pp, mm, stencil_type, lcross, uniform_dh) 
       cnt = cnt + 1
       den = dot(pp, qq, nodal_mask)
       if ( den == ZERO ) then
          if ( present(stat) ) then
             call bl_warn("CG_solve: breakdown in solver, going with what I have"); stat = 30; goto 100
          end if
          call bl_error("CG_solve: failure 1")
       end if
       alpha = rho/den
       call saxpy(uu,  alpha, pp)
       call saxpy(rr, -alpha, qq)
       if ( verbose > 1 ) then
          rnorm = norm_inf(rr)
          if ( parallel_IOProcessor() ) then
             write(unit=*, fmt='("          CG: Iteration        ",i4," rel. err. ",g15.8)') i,rnorm/bnorm
          end if
       end if
       if ( itsol_converged(rr, bnorm, eps, rrnorm = rnorm) ) exit
       rho_1 = rho
    end do

    if ( parallel_IOProcessor() .and. verbose > 0 ) then
       write(unit=*, fmt='("          CG: Final: Iteration  ", i3, " rel. err. ",g15.8)') i, rnorm/bnorm
       if ( rnorm < eps*bnorm ) then
          write(unit=*, fmt='("          CG: Converged: rnorm ",g15.8," < eps*bnorm ",g15.8)') rnorm,eps*bnorm
       end if
    end if

    if ( i > max_iter ) then
       if ( present(stat) ) then
          stat = 1
       else
          call bl_error("CG_solve: failed to converge");
       end if
    end if

100 continue

    call destroy(rr)
    call destroy(zz)
    call destroy(pp)
    call destroy(qq)

    call destroy(bpt)

    call destroy(aa_local)
    call destroy(rh_local)

  end subroutine itsol_CG_Solve

  subroutine itsol_precon(aa, uu, rh, mm, method)
    use bl_prof_module
    type(multifab), intent(in) :: aa
    type(multifab), intent(inout) :: uu
    type(multifab), intent(in) :: rh
    type(imultifab), intent(in) :: mm
    real(kind=dp_t), pointer, dimension(:,:,:,:) :: ap, up, rp
    integer, pointer, dimension(:,:,:,:) :: mp
    integer :: i, n, dm
    integer, intent(in), optional :: method
    integer :: lm
    type(bl_prof_timer), save :: bpt

    call build(bpt, "its_precon")

    lm = 1; if ( present(method) ) lm = method

    dm = get_dim(uu)

    select case (lm)
    case (0)
       call copy(uu, rh)
    case (1)
       do i = 1, nfabs(rh)
          rp => dataptr(rh, i)
          up => dataptr(uu, i)
          ap => dataptr(aa, i)
          mp => dataptr(mm, i)
          do n = 1, ncomp(uu)
             select case(dm)
             case (1)
                if ( cell_centered_q(rh) ) then
                   call jacobi_precon_1d(ap(:,:,1,1), up(:,1,1,n), rp(:,1,1,n), nghost(uu))
                else
                   call nodal_precon_1d(ap(:,:,1,1), up(:,1,1,n), rp(:,1,1,n), &
                                        mp(:,1,1,1),nghost(uu))
                end if
             case (2)
                if ( cell_centered_q(rh) ) then
                   call jacobi_precon_2d(ap(:,:,:,1), up(:,:,1,n), rp(:,:,1,n), nghost(uu))
                else
                   call nodal_precon_2d(ap(:,:,:,1), up(:,:,1,n), rp(:,:,1,n), &
                                        mp(:,:,1,1),nghost(uu))
                end if
             case (3)
                if ( cell_centered_q(rh) ) then
                   call jacobi_precon_3d(ap(:,:,:,:), up(:,:,:,n), rp(:,:,:,n), nghost(uu))
                else
                   call nodal_precon_3d(ap(:,:,:,:), up(:,:,:,n), rp(:,:,:,n), &
                                        mp(:,:,:,1),nghost(uu))
                end if
             end select
          end do
       end do
    end select

    call destroy(bpt)

  end subroutine itsol_precon

  subroutine diag_initialize(aa, rh, mm)
    use bl_prof_module
    type( multifab), intent(in) :: aa
    type( multifab), intent(in) :: rh
    type(imultifab), intent(in) :: mm

    real(kind=dp_t), pointer, dimension(:,:,:,:) :: ap, rp
    integer        , pointer, dimension(:,:,:,:) :: mp
    integer                                      :: i,dm
    integer                                      :: ng_a, ng_r, ng_m
    integer                                      :: lo(get_dim(rh)),hi(get_dim(rh))
    type(bl_prof_timer), save                    :: bpt

    call build(bpt, "diag_initialize")

    ng_a = nghost(aa)
    ng_r = nghost(rh)
    ng_m = nghost(mm)

    dm = get_dim(rh)

    do i = 1, nfabs(rh)
       rp => dataptr(rh, i)
       ap => dataptr(aa, i)
       mp => dataptr(mm, i)
       lo = lwb(get_box(rh,i))
       hi = upb(get_box(rh,i))
       select case(dm)
          case (1)
             if ( cell_centered_q(rh) ) then
                call diag_init_cc_1d(ap(:,:,1,1), ng_a, rp(:,1,1,1), ng_r, lo, hi)
             else
                call diag_init_nd_1d(ap(:,:,1,1), ng_a, rp(:,1,1,1), ng_r, mp(:,1,1,1), ng_m, lo, hi)
             end if
          case (2)
             if ( cell_centered_q(rh) ) then
                call diag_init_cc_2d(ap(:,:,:,1), ng_a, rp(:,:,1,1), ng_r, lo, hi)
             else
                call diag_init_nd_2d(ap(:,:,:,1), ng_a, rp(:,:,1,1), ng_r, mp(:,:,1,1), ng_m, lo, hi)
             end if
          case (3)
             if ( cell_centered_q(rh) ) then
                call diag_init_cc_3d(ap(:,:,:,:), ng_a, rp(:,:,:,1), ng_r, lo, hi)
             else
                call diag_init_nd_3d(ap(:,:,:,:), ng_a, rp(:,:,:,1), ng_r, mp(:,:,:,1), ng_m, lo, hi)
             end if
       end select
    end do

    call destroy(bpt)

  end subroutine diag_initialize

end module itsol_module

