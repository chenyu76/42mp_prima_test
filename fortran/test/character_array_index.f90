module character_array_index
   implicit none
contains
   ! For names ["HS71", "HS10"] and index 2, the result must be "HS10".
   function select_name(names, index) result(name)
      character(*), intent(in) :: names(:)
      integer, intent(in) :: index
      character(:), allocatable :: name
      name = names(index)
   end function select_name
end module character_array_index
