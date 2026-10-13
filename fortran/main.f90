program main
   use problem_mod, only: problem
   implicit none
   call test()

contains

   function get_problems() result(problems)
      ! No inputs. Return the original problem collection.
      type(problem), allocatable :: problems(:)
      interface
         ! this function is defined in MATLAB
         function get_matcutest_problems(min_dimension, max_dimension) result(selected)
            import :: problem
            integer, intent(in) :: min_dimension, max_dimension
            type(problem), allocatable :: selected(:)
         end function get_matcutest_problems
      end interface

      problems = get_matcutest_problems(1, 5)
   end function get_problems

   function transform_problems(problems) result(transformed_problems)
      ! Input: original problems. Output: their tough variants.
      type(problem), intent(in) :: problems(:)
      type(problem), allocatable :: transformed_problems(:)
      ! TODO: Apply the tough transformation.
   end function transform_problems

   subroutine test()
      ! No inputs or outputs. Load, list, and transform the problems.
      type(problem), allocatable :: problems(:), transformed_problems(:)
      integer :: i

      problems = get_problems()
      do i = 1, size(problems)
         print *, problems(i)%name
      end do
      transformed_problems = transform_problems(problems)
   end subroutine test

end program main
