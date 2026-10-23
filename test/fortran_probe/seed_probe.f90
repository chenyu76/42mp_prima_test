subroutine seed_probe(seed, values)
    implicit none
    integer, intent(in) :: seed(:)
    real(8), intent(out) :: values(2)
    call random_seed(put=seed)
    call random_number(values)
end subroutine
