module matcutest_interop_probe
   implicit none
   type :: selection
      integer :: mindim, maxdim
      logical :: is_feasibility
   end type selection
contains
   function make_selection(min_dimension, max_dimension) result(requirements)
      integer, intent(in) :: min_dimension, max_dimension
      type(selection) :: requirements
      requirements = selection(min_dimension, max_dimension, .false.)
   end function make_selection

   function convert_names(values) result(names)
      character(*), intent(in) :: values(:)
      character(:), allocatable :: names(:)
      interface
         function string(values) result(names)
            character(*), intent(in) :: values(:)
            character(:), allocatable :: names(:)
         end function string
      end interface
      names = string(values)
   end function convert_names
end module matcutest_interop_probe
