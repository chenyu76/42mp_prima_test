module framework_probe_m
    implicit none
    abstract interface
        function objective(x) result(f)
            real(8), intent(in) :: x(:)
            real(8) :: f
        end function
    end interface
    type :: problem
        integer :: n
        real(8), allocatable :: x0(:)
        procedure(objective), pointer, nopass :: fun => null()
    end type
    type :: history
        integer :: count = 0
        real(8), allocatable :: x(:, :), f(:)
    end type
contains
    function quadratic(x) result(f)
        real(8), intent(in) :: x(:)
        real(8) :: f
        f = sum(x*x)
    end function
    subroutine record_step(h, x, f)
        type(history), intent(inout) :: h
        real(8), intent(in) :: x(:), f
        h%count = h%count + 1
        h%x(:, h%count) = x
        h%f(h%count) = f
    end subroutine
    subroutine run_probe()
        type(problem) :: p
        type(history) :: h
        real(8) :: x(2), f
        integer :: i
        p%n = 2
        allocate(p%x0(p%n), h%x(p%n, 3), h%f(3))
        p%x0 = [1.0d0, 2.0d0]
        if (size(p%x0, dim=1) /= p%n) error stop 'Incorrect vector shape'
        p%fun => quadratic
        x = p%x0
        do i = 1, 3
            f = p%fun(x)
            call record_step(h, x, f)
            x = x / 2.0d0
        end do
        if (h%count /= 3) error stop 'Incorrect history count'
        if (any(h%f /= [5.0d0, 1.25d0, 0.3125d0])) error stop 'Incorrect values'
        if (any(h%x(:, 3) /= [0.25d0, 0.5d0])) error stop 'Incorrect shape or state'
        print *, 'FRAMEWORK_PROBE_PASS'
    end subroutine
end module
program framework_probe
    use framework_probe_m
    implicit none
    call run_probe()
end program
