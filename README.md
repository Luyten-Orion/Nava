# Nava (Placeholder Name)
Nava is a JVM bytecode manipulation library written in Nim! The goal is to allow
anyone to be able to manipulate and generate JVM bytecode, for usecases such as
compiler backends or processing the bytecode produced by another tool for validation.
If this project goes well, bindings to other languages may be done.

Nava does not, and will not attempt to be, an implementation of the JVM, a JIT or a
JVM to Nim transpiler. It is just a library for manipulating JVM bytecode.

## Motivation
The motivation for this project came from my increasing desire to make a tool to
generate JVM bytecode for a potential compiler backend in a language I create, and
for transpiling WebAssembly to JVM bytecode. For both of these, I refuse to touch
most existing JVM languages as I dislike them compared to how elegant Nim is, and I
feel like JNI to interact with the `ASM` library in Nim is not ideal since you have
to now lug around a JVM.

## Work In Progress
Currently I am focusing on implementing the structure of JVM class files and adding
the constraints according to the spec.

## To-Do
- Implementation
  - Reading
  - Writing
  - Manipulation Tools
- Tests
- Documentation