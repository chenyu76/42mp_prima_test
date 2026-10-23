# MatCUTEst migration blockers

The proposed migration moves problem selection and loading from handwritten
MATLAB adapters into Fortran, translated by the installed `42mp` command.
Translation of the probes below currently produces incorrect or unresolved
MATLAB expressions. Production adapters remain in place until migration can
be verified. No translator or MatCUTEst dependency files were modified.

## Reproduction

From the project root, choose a fresh output directory and run:

```sh
42mp -r fortran/test -o /tmp/matcutest-migration-review/ \
    fortran/test/character_array_index.f90 \
    fortran/test/matcutest_interop_probe.f90
```

The generated code demonstrates each issue without requiring MatCUTEst.

## 1. Character-array indexing becomes character extraction

Source: `character_array_index.f90`, `select_name`.

```fortran
name = names(index)
```

Actual MATLAB:

```matlab
name = extract(names, index_custom);
```

Expected: `name = names(index_custom);` for a MATLAB string array.
With `names = ["HS71"; "HS10"]` and index 2, the expected result is `"HS10"`.
The generated expression instead extracts the second character of each string.
This blocks selecting a problem name in the Fortran loading loop.

## 2. Derived-type constructor remains an unresolved MATLAB call

Source: `matcutest_interop_probe.f90`, `make_selection`.

```fortran
requirements = selection(min_dimension, max_dimension, .false.)
```

Actual MATLAB:

```matlab
requirements = selection(min_dimension, max_dimension, false);
```

The generated class only defines `selection_default`, which takes no field
arguments. It defines no `selection` function. The expression must construct
a struct with the supplied `mindim`, `maxdim`, and `is_feasibility` values.
Field assignments could avoid this constructor, but the source is valid
Fortran and the generated call is unresolved.

## 3. External MATLAB string conversion is renamed

Source: `matcutest_interop_probe.f90`, `convert_names`.

An explicit external interface named `string` is intended to call MATLAB's
existing conversion function on the cell array returned by `secup`.

Actual MATLAB:

```matlab
names = string_custom(values);
```

No `string_custom` implementation is generated or supplied. This is an
external MATLAB interoperability limitation: external declarations do not
currently provide a reliable way to preserve this MATLAB function name.
It should not be treated as a Fortran intrinsic named `string`.

## Scope of verification

Both probes were translated with the installed `42mp` executable and their
generated MATLAB was inspected. No MATLAB runtime result is claimed here.
The complete loader migration has not passed validation or been installed
into production code. Procedure-pointer calls through an explicitly declared
`str2func` interface translated correctly in a separate exploratory probe;
that alone does not verify the complete callback implementation.
