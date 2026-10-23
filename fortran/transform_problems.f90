module tough_mod
   use problem_mod, only: problem, nonlinear_function
   use, intrinsic :: iso_fortran_env, only: real64, int64
   implicit none
   private
   public :: transform_problems, make_tough_problem

   integer, parameter :: tough_runs = 10
   integer(int64), parameter :: tough_seed = 0_int64
   real(real64), parameter :: noise_level = 0.2_real64
   logical, parameter :: with_failure = .true.
   logical, parameter :: invalid_linear = .true.
   logical, parameter :: fixed_variables = .true.
   integer(int64), parameter :: seed_modulus = 4294967296_int64

contains

   function transform_problems(problems) result(transformed)
      type(problem), intent(in) :: problems(:)
      type(problem), allocatable :: transformed(:)
      integer :: i, j, run, index
      integer(int64) :: name_seed, seed

      allocate (transformed(size(problems)*tough_runs))
      index = 0
      do i = 1, size(problems)
         ! Names keep variants reproducible when the problem collection is reordered.
         name_seed = 0_int64
         do j = 1, len(problems(i)%name)
            name_seed = name_seed + int(j, int64)*iachar(problems(i)%name(j:j))
         end do
         do run = 1, tough_runs
            seed = modulo(tough_seed + name_seed + 104729_int64*run, seed_modulus)
            index = index + 1
            transformed(index) = make_tough_problem(problems(i), seed)
         end do
      end do
   end function transform_problems

   function make_tough_problem(base, seed) result(p)
      type(problem), intent(in) :: base
      integer(int64), intent(in) :: seed
      type(problem) :: p
      integer, allocatable :: saved_state(:)
      real(real64), allocatable :: matrix(:, :), rhs(:)
      integer :: seed_size, i
      real(real64), allocatable :: lower(:), upper(:), scale(:)
      real(real64) :: sample
      character(10) :: seed_text

      call random_seed(size=seed_size)
      allocate (saved_state(seed_size))
      call random_seed(get=saved_state)
      call set_seed(seed)
      p = base
      write (seed_text, "(I10.10)") seed
      p%name = base%name//"_tough_"//seed_text
      do i = 1, size(p%x0)
         p%x0(i) = base%x0(i) + noise_level*max(1.0_real64, abs(base%x0(i)))*gaussian()
      end do
      allocate(lower(size(p%x0)), upper(size(p%x0)))
      ! Working bounds are finite; absent PRIMA bounds stay absent in the problem.
      lower(:) = -1.0e10_real64
      upper(:) = 1.0e10_real64
      if (size(p%lb) > 0) lower = max(-1.0e10_real64, p%lb)
      if (size(p%ub) > 0) upper = min(1.0e10_real64, p%ub)
      scale = noise_level*0.9_real64*min(1.0_real64, max(0.0_real64, upper - lower))
      if (size(p%lb) > 0) p%lb = perturb_bounds(p%lb, lower, scale)
      if (size(p%ub) > 0) p%ub = perturb_bounds(p%ub, upper, scale)
      if (fixed_variables .and. size(p%lb) > 0 .and. size(p%ub) > 0) then
         do i = 1, size(p%x0)
            if (.not. (finite(p%lb(i)) .and. finite(p%ub(i)))) cycle
            call random_number(sample)
            if (sample >= 0.2_real64) cycle
            call random_number(sample)
            if (sample < 0.5_real64) then
               p%ub(i) = p%lb(i)
            else
               p%lb(i) = p%ub(i)
            end if
         end do
      end if
      matrix = p%Aineq
      rhs = p%bineq
      call tough_linear_data(matrix, rhs)
      p%Aineq = matrix
      p%bineq = rhs
      matrix = p%Aeq
      rhs = p%beq
      call tough_linear_data(matrix, rhs)
      p%Aeq = matrix
      p%beq = rhs
      call random_seed(put=saved_state)
      ! Nested callbacks retain this variant's original problem and seed.
      p%objective => objective
      if (associated(base%nonlcon)) p%nonlcon => constraints

   contains

      function objective(x) result(value)
         real(real64), intent(in) :: x(:)
         real(real64) :: value
         value = contaminate(base%objective(x), x, seed, with_failure, 0)
      end function objective

      subroutine constraints(x, cineq, ceq)
         real(real64), intent(in) :: x(:)
         real(real64), allocatable, intent(out) :: cineq(:), ceq(:)
         procedure(nonlinear_function), pointer :: callback
         integer :: k
         callback => base%nonlcon
         call callback(x, cineq, ceq)
         ! Constraints may return nonfinite values, but never inject exceptions.
         do k = 1, size(cineq)
            cineq(k) = contaminate(cineq(k), x, seed, .false., 100000 + k)
         end do
         do k = 1, size(ceq)
            ceq(k) = contaminate(ceq(k), x, seed, .false., 200000 + k)
         end do
      end subroutine constraints

   end function make_tough_problem

   function perturb_bounds(original, working, scale) result(bounds)
      real(real64), intent(in) :: original(:), working(:), scale(:)
      real(real64), allocatable :: bounds(:)
      real(real64) :: sample
      integer :: i
      bounds = original
      do i = 1, size(bounds)
         if (.not. finite(bounds(i))) cycle
         call random_number(sample)
         bounds(i) = working(i) + scale(i)*(sample - 1.0_real64)
      end do
   end function perturb_bounds

   subroutine tough_linear_data(matrix, rhs)
      real(real64), intent(inout) :: matrix(:, :), rhs(:)
      integer :: i, j, pass
      real(real64) :: sample, bad_value, zero
      if (size(matrix) == 0) return
      do j = 1, size(matrix, 2)
         do i = 1, size(matrix, 1)
            matrix(i, j) = matrix(i, j) + noise_level*max(1.0_real64, abs(matrix(i, j)))*gaussian()
         end do
      end do
      do i = 1, size(rhs)
         rhs(i) = rhs(i) + noise_level*max(1.0_real64, abs(rhs(i)))*gaussian()
      end do
      if (.not. invalid_linear) return
      zero = 0.0_real64
      do pass = 1, 3
         select case (pass)
         case (1)
            bad_value = 1.0_real64/zero
         case (2)
            bad_value = -1.0_real64/zero
         case (3)
            bad_value = zero/zero
         end select
         do j = 1, size(matrix, 2)
            do i = 1, size(matrix, 1)
               call random_number(sample)
               if (sample > 0.97_real64) matrix(i, j) = bad_value
            end do
         end do
         do i = 1, size(rhs)
            call random_number(sample)
            if (sample > 0.97_real64) rhs(i) = bad_value
         end do
      end do
   end subroutine tough_linear_data

   function contaminate(original, x, seed, fail, salt) result(value)
      real(real64), intent(in) :: original, x(:)
      integer(int64), intent(in) :: seed
      logical, intent(in) :: fail
      integer, intent(in) :: salt
      real(real64) :: value, sample, zero
      integer, allocatable :: saved_state(:)
      integer :: seed_size, i
      integer(int64) :: local_seed, coordinate

      call random_seed(size=seed_size)
      allocate (saved_state(seed_size))
      call random_seed(get=saved_state)
      ! Evaluation noise depends on the point, not the evaluation order.
      local_seed = modulo(seed + salt, seed_modulus)
      ! Bound each coordinate before mixing so large points cannot overflow the seed.
      do i = 1, size(x)
         coordinate = int((atan(x(i))/acos(-1.0_real64) + 0.5_real64) &
                          *real(seed_modulus - 1_int64, real64), int64)
         local_seed = modulo(31_int64*local_seed + coordinate, seed_modulus)
      end do
      call set_seed(local_seed)
      value = original*(1.0_real64 + noise_level*gaussian())
      call random_number(sample)
      sample = 2.0_real64*sample - 1.0_real64
      ! Restore the caller's stream before any injected failure.
      call random_seed(put=saved_state)
      zero = 0.0_real64
      if (sample > 0.9_real64) then
         if (fail) error stop "Injected tough-problem evaluation failure."
         value = zero/zero
      else if (sample > 0.8_real64) then
         value = zero/zero
      else if (sample > 0.7_real64) then
         value = 1.0_real64/zero
      else if (sample < -0.9_real64) then
         value = -1.0e30_real64
      end if
   end function contaminate

   subroutine set_seed(seed)
      integer(int64), intent(in) :: seed
      integer :: parts(2)
      ! Two 16-bit words avoid signed-integer overflow for 32-bit seeds.
      parts(1) = int(modulo(seed, 65536_int64))
      parts(2) = int(seed/65536_int64)
      call random_seed(put=parts)
   end subroutine set_seed

   function gaussian() result(value)
      real(real64) :: value, u, v
      call random_number(u)
      call random_number(v)
      ! Box-Muller: clamp the first sample so log remains defined at zero.
      value = sqrt(-2.0_real64*log(max(tiny(1.0_real64), u)))*cos(2.0_real64*acos(-1.0_real64)*v)
   end function gaussian

   function finite(value) result(answer)
      real(real64), intent(in) :: value
      logical :: answer
      answer = abs(value) <= huge(value)
   end function finite

end module tough_mod
