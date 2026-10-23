module type_bound_probe_m
    implicit none
    type :: tracker
        integer :: count = 0
    contains
        procedure :: record
    end type
contains
    subroutine record(self)
        class(tracker), intent(inout) :: self
        self%count = self%count + 1
    end subroutine
end module
