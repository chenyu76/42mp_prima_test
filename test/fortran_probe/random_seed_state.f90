program random_seed_state
  implicit none
  interface
    subroutine seed_probe(seed, values)
      integer, intent(in) :: seed(:)
      real(8), intent(out) :: values(:)
    end subroutine
  end interface
  type :: sample_t
    integer :: count
    integer, allocatable :: seed(:)
    real(8) :: values(4)
  end type
  type(sample_t) :: item, boxes(2)
  integer :: n, i, random_index
  integer, allocatable :: seed(:), saved(:), long_seed(:), sliced_seed(:)
  real(8) :: first(6), repeated(6), matrix(2,3), scalar, buffer(6)
  real(8), allocatable :: empty(:)

  call random_seed()
  call random_seed(n)
  if (n <= 0) error stop 'seed size'
  allocate(seed(n), saved(n), long_seed(n+3), sliced_seed(n+2), empty(0))
  seed = [(17-i, i=1,n)]
  long_seed = 0
  long_seed(1:n) = seed
  call random_seed(put=seed)
  call random_number(first)
  call random_seed(put=seed)
  call random_number(harvest=repeated)
  if (any(first /= repeated)) error stop 'repeated seed'
  call seed_probe(seed, repeated)
  if (any(first /= repeated)) error stop 'report probe'

  call random_seed(get=saved)
  call random_number(first)
  call random_seed(put=saved)
  call random_number(repeated)
  if (any(first /= repeated)) error stop 'restore position'

  call random_seed(put=seed)
  call random_number(first)
  call random_seed(put=long_seed)
  call random_number(repeated)
  if (any(first /= repeated)) error stop 'long seed prefix'
  call random_seed(get=long_seed)
  call random_number(first)
  call random_seed(put=long_seed)
  call random_number(repeated)
  if (any(first /= repeated)) error stop 'long snapshot'

  call random_seed(get=saved)
  call random_seed(size=item%count)
  if (item%count /= n) error stop 'component size'
  allocate(item%seed(n))
  call random_seed(get=item%seed)
  call random_number(first)
  call random_seed(put=saved)
  call random_number(repeated)
  if (any(first /= repeated)) error stop 'queries changed state'
  call random_seed(put=item%seed)
  call random_number(repeated)
  if (any(first /= repeated)) error stop 'component restore'

  sliced_seed = -7
  call random_seed(get=sliced_seed(2:n+1))
  if (sliced_seed(1) /= -7 .or. sliced_seed(n+2) /= -7) error stop 'GET slice boundary'
  call random_number(first)
  call random_seed(put=sliced_seed(2:n+1))
  call random_number(repeated)
  if (any(first /= repeated)) error stop 'slice restore'

  call random_seed(get=saved)
  call random_number(empty)
  call random_number(first)
  call random_seed(put=saved)
  call random_number(repeated)
  if (any(first /= repeated)) error stop 'empty consumed state'

  call random_number(scalar)
  call random_number(matrix)
  if (scalar < 0 .or. scalar >= 1) error stop 'scalar range'
  if (any(matrix < 0) .or. any(matrix >= 1)) error stop 'matrix range'
  if (size(matrix,1) /= 2 .or. size(matrix,2) /= 3) error stop 'matrix shape'
  if (size(first) /= 6 .or. any(first < 0) .or. any(first >= 1)) error stop 'vector range'

  item%values = -1
  call random_number(harvest=item%values)
  if (any(item%values < 0) .or. any(item%values >= 1)) error stop 'component random'
  buffer = -1
  call random_number(buffer(2:5:2))
  if (buffer(1) /= -1 .or. buffer(3) /= -1 .or. buffer(5) /= -1 .or. buffer(6) /= -1) &
    error stop 'strided slice boundary'
  if (buffer(2) < 0 .or. buffer(2) >= 1 .or. buffer(4) < 0 .or. buffer(4) >= 1) &
    error stop 'strided slice range'

  random_index = 23
  boxes(1)%values = -1
  boxes(2)%values = -1
  call random_number(boxes(select_box())%values(1))
  if (boxes(1)%values(1) < 0) error stop 'selected box'
  if (any(boxes(2)%values /= -1)) error stop 'selector evaluated twice'
  if (select_box() /= 2) error stop 'selector count'
  if (random_index /= 23) error stop 'temporary collision'
  buffer = -1
  call random_number(buffer(select_element()))
  if (buffer(2) < 0 .or. any(buffer(3:6) /= -1)) error stop 'element output'
  if (select_element() /= 3) error stop 'element selector count'
  print *, 'RANDOM_SEED_STATE_PASS'
contains
  integer function select_box()
    integer, save :: calls = 0
    calls = calls + 1
    select_box = calls
  end function
  integer function select_element()
    integer, save :: calls = 1
    calls = calls + 1
    select_element = calls
  end function
end program
