# TODO

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

(已放弃)

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
 │ MatCutest │ (A struct)
 └───────────┘
       ↓Problem Loader
 ┌───────────┐
 │ Problems  │  (A struct)
 └───────────┘
       ↓toughing
 ┌─────────────────┐
 │ tough Problems  │  (A struct)
 └─────────────────┘
       ↓Problem wrapper
 ┌────────────────────────┐
 │ Value Recorded Problem │  (A class providing interface)
 └────────────────────────┘
```

Value Recorded Problem 可以记录函数名以及每一次调用时的函数值，选点，Aeq beq等，整理为一个结构数组

## flow

1. get problem
2. tough problem
3. wrap problem
4. run problem in two solver
5. compare result

## Compare Data

Each Solver gernerate a data tree. In Matlab, it is nested struct.

Recursively compare the tree child by child.

Show only the diff of the tree.

The comparing function should work for any nested struct.

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
