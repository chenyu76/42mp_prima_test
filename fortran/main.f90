program main
   use problem_mod, only: problem
   implicit none
   call test()

contains

   function get_problems() result(problems)
      use matcutest_mod, only: get_matcutest_problems
      type(problem), allocatable :: problems(:)

      problems = get_matcutest_problems(1, 5)
   end function get_problems

   subroutine test()
      use tough_mod, only: transform_problems
      type(problem), allocatable :: problems(:), transformed_problems(:)
      integer :: i

      problems = get_problems()
      do i = 1, size(problems)
         print *, problems(i)%name
      end do
      transformed_problems = transform_problems(problems)
   end subroutine test

end program main
