module problem_mod
   use, intrinsic :: iso_fortran_env, only: real64
   implicit none
   private
   public :: problem, nonlinear_function

   abstract interface
      function objective_function(x) result(value)
         import :: real64
         real(real64), intent(in) :: x(:)
         real(real64) :: value
      end function objective_function

      subroutine nonlinear_function(x, cineq, ceq)
         import :: real64
         real(real64), intent(in) :: x(:)
         real(real64), allocatable, intent(out) :: cineq(:), ceq(:)
      end subroutine nonlinear_function
   end interface

   type :: problem
      character(:), allocatable :: name
      procedure(objective_function), pointer, nopass :: objective => null()
      real(real64), allocatable :: x0(:), lb(:), ub(:)
      ! PRIMA uses Aineq*x <= bineq and Aeq*x == beq.
      real(real64), allocatable :: Aineq(:, :), bineq(:), Aeq(:, :), beq(:)
      ! nonlcon returns cineq(x) <= 0 and ceq(x) == 0 together.
      procedure(nonlinear_function), pointer, nopass :: nonlcon => null()
   end type problem
end module problem_mod
