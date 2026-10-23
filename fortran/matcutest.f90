module matcutest_mod
   use problem_mod, only: problem
   implicit none
   private
   public :: get_matcutest_problems

contains

   function get_matcutest_problems(min_dimension, max_dimension) result(problems)
      integer, intent(in) :: min_dimension, max_dimension
      type(problem), allocatable :: problems(:)
      character(:), allocatable :: names(:)
      integer :: i
      interface
         function select_matcutest_problems(min_dimension, max_dimension) result(names)
            integer, intent(in) :: min_dimension, max_dimension
            character(:), allocatable :: names(:)
         end function select_matcutest_problems

         function load_matcutest_problem(names, index) result(p)
            import :: problem
            character(*), intent(in) :: names(:)
            integer, intent(in) :: index
            type(problem) :: p
         end function load_matcutest_problem
      end interface

      names = select_matcutest_problems(min_dimension, max_dimension)
      allocate(problems(size(names)))
      ! 42mp treats character-array indexing as substring extraction; index in MATLAB.
      do i = 1, size(names)
         problems(i) = load_matcutest_problem(names, i)
      end do
   end function get_matcutest_problems

end module matcutest_mod
