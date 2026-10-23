# TODO

```




    ┌───────────────────┐
    │ MatCutest         │
    └──┬────────────────┘
       ↓
    ┌───────────────────┐
    │ Problems          │
    └──┬────────────────┘       ┌──────────────────────────────────────────────────────┐
       │                        │ list of solver                                       │
       │                         ┌─────────┐      ┌─────────────────┐     ┌─────────┐
       │                     ┌──→│ matlab  ├─────→│ matlab solver A │───→ │ python  ├─┐
       ↓                     │   │ wrapper │      └─────────────────┘     │ wrapper │ │
  ┌───────────────────────┐  │   └─────────┘                              └─────────┘ │
  │ status listener       │  │                    ┌─────────────────┐                 │
  │                 init  ├──┤                    │ matlab solver B │                 │
  │                       │  │   ┌─────────┐      │                 │     ┌─────────┐ │
  │        record status  │  │   │ matlab  ├─────→input        output───→ │ python  ├─┴──┐
  │                       │  └──→│ wrapper │      │                 │     │ wrapper │    │
  │                       │      └─────────┘      └─────────────────┘     └─────────┘    │
  │                       │                                                              │
  │                       │     │ ......                                               │ │
  │            status     │     └──────────────────────────────────────────────────────┘ │
  └───────────────┬───────┘                                                              │
                  │                                                                      │
          ┌───────┴──────────────────────────────────────────────────────────────────────┘
          │
          ↓
    ┌───────────────────────────────────┐
    │  outputs                          │ ┌─                 Solver A      Solver B       ...
      ┌───────────────────────────────┐   │ ─────────────────────────────────────────────────────
      │               solver A output │   │ output
      │ problem 1                     ├───┤ ──────────┬──────────────────────────────────────────
      │               solver B output │   │ history x │ 1
      └───────────────────────────────┘   │           ├──────────────────────────────────────────
      ┌───────────────────────────────┐   │           │ 2
      │               solver A output │   │           ├──────────────────────────────────────────
      │ problem 2                     │   │           │ ...
      │               solver B output │   │ ──────────┼──────────────────────────────────────────
      └───────────────────────────────┘   │ history f │ 1
    │  ......                           │ │           ├──────────────────────────────────────────
    └───────────────────────────────────┘ │           │ 2
                                          │           ├──────────────────────────────────────────
                                          │           │ ...
                                          │ ──────────┴──────────────────────────────────────────
                                          │ ......
                                          │ find diff
                                          └─


```

## Test

```text
                                     ┌─example translation
             quick test              │
           ┌─(run when code change) ─┼─quick prima test
           │                         │
      test─┤                         └─some useless test suites written by AI
           │
           └─full prima test     ────test tough problem, full MatCUTest
             (This test)
```

## test that test is also a test

```
┌──────────────────────────────┐ The Translator ┌────────────────────────────┐
│ Test code written in Fortran │───────────────→│Test code written in MATLAB │
└──────────────────────────────┘                └────────────────────────────┘
  │                                               │
  └─── Only use as the input of the translator    └───── We only run this!
```

Benefit:

- Static Type
- Syntax Check
- Test the translator

## Gernerate Problem

```text
 ┌───────────┐
 │ MatCutest │
 └───────────┘
       ↓Problem Loader
 ┌───────────┐
 │ Problems  │
 └───────────┘
       ↓Problem wrapper
 ┌────────────────────────┐
 │ Value Recorded Problem │
 └────────────────────────┘
```

Value Recorded Problem 可以记录函数名以及每一次调用时的函数值，选点，Aeq beq等，整理为一个结构数组

## Compare Data

Each Solver gernerate a data tree.

Recursively compare the tree child by child.

Show only the diff of the tree.

```
 Solver A─┬─Problem A─┬─evalutions─┬─f─┬─$f_1$   Solver B─┬─Problem A─┬─evalutions─┬─f─┬─$f_1$
          │           │            │   ├─$f_2$            │           │            │   ├─$f_2$
          │           │            │   └─...              │           │            │   └─...
          │           ├─output     └─x─┬─$x_1$            │           ├─output     └─x─┬─$x_1$
          │           └─...            ├─$x_2$            │           └─...            ├─$x_2$
          │                            └─...              │                            └─...
          ├─Problem B─┬─evalutions─┬─f─┬─$f_1$            ├─Problem B─┬─evalutions─┬─f─┬─$f_1$
          │           │            │   ├─$f_2$            │           │            │   ├─$f_2$
          │           │            │   └─...              │           │            │   └─...
          └─...       ├─output     └─x─┬─$x_1$            └─...       ├─output     └─x─┬─$x_1$
                      └─...            ├─$x_2$                        └─...            ├─$x_2$
                                       └─...                                           └─...

```
