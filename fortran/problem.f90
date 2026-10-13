module problem_mod
   use, intrinsic :: iso_fortran_env, only: real64
   implicit none
   private
   public :: problem

   abstract interface
      function objective_function(x) result(value)
         import :: real64
         real(real64), intent(in) :: x(:)
         real(real64) :: value
      end function objective_function

      function constraint_function(x) result(values)
         import :: real64
         real(real64), intent(in) :: x(:)
         real(real64), allocatable :: values(:)
      end function constraint_function
   end interface

   type :: problem
      character(:), allocatable :: name
      integer :: n
      real(real64), allocatable :: x0(:), xl(:), xu(:)
      ! Linear constraints: aub @ x <= bub and aeq @ x == beq.
      real(real64), allocatable :: aub(:, :), bub(:), aeq(:, :), beq(:)
      procedure(objective_function), pointer, nopass :: fun => null()
      ! Nonlinear constraints: cub(x) <= 0 and ceq(x) == 0.
      procedure(constraint_function), pointer, nopass :: cub => null(), ceq => null()
   end type problem
end module problem_mod
