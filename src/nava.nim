## `nava` is a JVM bytecode manipulation library for Nim.
import std/tables

import ./nava/private/stew/endians2


#[Start of IO read/write procs]#
type SizedNum = uint8 | uint16 | uint32 | uint64 | int8 | int16 | int32 | int64 | float32 | float64


template unsignedSize(T: typedesc): typedesc =
  when sizeof(T) == 1:
    uint8

  elif sizeof(T) == 2:
    uint16

  elif sizeof(T) == 4:
    uint32

  elif sizeof(T) == 8:
    uint64

  else:
    {.error: "Deserialisation of `" & $T & "` is not implemented!".}


func extract[T: SizedNum](oa: openArray[byte], _: typedesc[T]): T {.raises: [ValueError].} =
  ## Extracts a value of type T from the given openArray, it MUST be the exact size of T
  ## or a `ValueError` will be raised. This uses BE for endianness. It's recommended to
  ## use `toOpenArray(startIndex, endIndex)` to extract a range and pass it to this proc.
  if oa.len < sizeof(T):
    raise newException(ValueError, "The buffer was to small to extract a " & $T & '!')

  elif oa.len > sizeof(T):
    raise newException(ValueError, "The buffer was to big to extract a " & $T & '!')

  cast[T](unsignedSize(T).fromBytesBE(oa.toOpenArray(0, sizeof(T) - 1)))


func deposit[T: SizedNum](value: T, oa: var openArray[byte]) {.raises: [ValueError].} =
  ## Deposits a value of type T to the given openArray, it MUST be the exact size of T
  ## or a `ValueError` will be raised. This uses BE for endianness. It's recommended to
  ## use `toOpenArray(startIndex, endIndex)` to extract a range and pass it to this proc.
  if oa.len < sizeof(T):
    raise newException(ValueError, "The buffer was to small to deposit a " & $T & '!')

  elif oa.len > sizeof(T):
    raise newException(ValueError, "The buffer was to big to deposit a " & $T & '!')

  let res = cast[unsignedSize(T)](value).toBytesBE()

  for i in 0..<sizeof(T):
    oa[i] = res[i]

#[End of IO read/write procs]#

type
  NavaClassVersion* = object
    major*, minor*: uint16

  NavaClass* = object
    version*: NavaClassVersion                     ## The version of the class file.
    constantPool*: NavaConstantPool                ## The constant pool of the class file.
    accessFlags*: set[NavaClassAccessFlag]         ## The access flags of the class file.
    thisClass*, superClass*: NavaConstantPoolIndex ## The this and super classes of the class file.
    interfaces*: seq[NavaConstantPoolIndex]        ## The interfaces of the class file.
    fields*: seq[NavaField]                        ## The fields of the class file.
    methods*: seq[NavaMethod]                      ## The methods of the class file.
    attributes*: seq[NavaAttribute]                ## The attributes of the class file.

  NavaClassAccessFlag* {.size(2).} = enum
    caPublic, caFinal, caSuper, caInterface, caAbstract, caSynthetic, caAnnotation, caEnum, caModule

  NavaFieldAccessFlag* {.size(2).} = enum
    faPublic, faPrivate, faProtected, faStatic, faFinal, faVolatile, faTransient, faSynthetic, faEnum

  NavaMethodAccessFlag* {.size(2).} = enum
    maPublic, maPrivate, maProtected, maStatic, maFinal, maSynchronised, maBridge, maVarargs, maNative,
    maAbstract, maStrict, maSynthetic

  NavaConstantPoolIndex* = distinct uint16       ## An index into the constant pool

  NavaConstantPool* = distinct seq[NavaConstant] ## The constant pool of the class file

  NavaMethodKind* {.size(1).} = enum
    mInvalid = 0'u8, mGetField, mGetStatic, mPutField, mPutStatic, mInvokeVirtual,
    mInvokeStatic, mInvokeSpecial, mNewInvokeSpecial, mInvokeInterface

  NavaConstantKind* {.size(1).} = enum
    ncInvalid = 0'u8, ncUtf8, ncInteger, ncFloat, ncLong, ncDouble, ncClass, ncString, ncFieldRef, ncMethodRef,
    ncInterfaceMethodRef, ncNameAndType, ncMethodHandle, ncMethodType, ncDynamic, ncInvokeDynamic, ncModule, ncPackage

  # TODO: Add https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.8 and more
  NavaConstant* = ref object # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4
    case kind*: NavaConstantKind # `tag`: `u1`
    # `info`: `u1[]`
    of ncInvalid:
      discard # Just so we can use discriminators

    of ncUtf8: # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.7
      ## Uses Modified UTF-8. Not null-terminated.
      text*: string # `bytes`: `u1[]`, `length`: `u2`, could be `seq[Rune]`?

    of ncInteger: # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.4
      intVal*: int32 # `bytes`: `u4`
    of ncFloat: # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.4
      floatVal*: float32 # `bytes`: `u4`

    of ncLong: # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.5
      longVal*: int64 # `high_bytes`: `u4`, `low_bytes`: `u4`
    of ncDouble: # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.5
      doubleVal*: float64 # `high_bytes`: `u4`, `low_bytes`: `u4`

    of ncClass: # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.1
      ## The constant pool entry must point to a UTF-8 info structure.
      cNameIndex*: NavaConstantPoolIndex # `name_index`: `u2`

    of ncString: # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.3
      ## The constant pool entry must point to a UTF-8 info structure.
      stringIndex*: NavaConstantPoolIndex # `string_index`: `u2`

    of {ncFieldRef, ncMethodRef, ncInterfaceMethodRef}: # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.2
      ## For interfaces it must be an interface type, for methods it must be a class type.
      classIndex*: NavaConstantPoolIndex # `class_index`: `u2`
      ## For FieldRefs it must be a field descriptor, for anything else it must be a method descriptor.
      ##  If the name of the method in a CONSTANT_Methodref_info structure begins with a '<' ('\u003c'),
      ## then the name must be the special name `<init>`, representing an instance initialisation method,
      ## and it's return type MUST be `void`.
      nameAndTypeIndex*: NavaConstantPoolIndex # `name_and_type_index`: `u2`

    of ncNameAndType: # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.6
      # Must be a utf8 info structure, representing a valid unqualified name or `<init>`. 
      ntNameIndex*: NavaConstantPoolIndex # `name_index`: `u2`
      ## Must be a utf8 info structure, representing a valid field or method descriptor.
      ntDescriptorIndex*: NavaConstantPoolIndex # `descriptor_index`: `u2`

    of ncMethodHandle: # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.8
      mhRefKind*: NavaMethodKind # `reference_kind`: `u1`
      # See `ConstantMethodHandleRestrictions` for what this can be.
      mhRefIndex*: NavaConstantPoolIndex # `reference_index`: `u2`

    of ncMethodType: # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.9
      ## Must be a method descriptor.
      mtDescriptorIndex*: NavaConstantPoolIndex # `descriptor_index`: `u2`

    of ncDynamic: # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.10
      ## Must be a valid index into the bootstrap methods table. Cycles are allowed but will fail
      ## during resolution in the JVM.
      dBootstrapMethodAttrIndex*: uint16 # `bootstrap_method_attr_index`: `u2`
      dNameAndTypeIndex*: NavaConstantPoolIndex # `name_and_type_index`: `u2`

    of ncInvokeDynamic: # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.10
      ## Must be a valid index into the bootstrap methods table.
      idBootstrapMethodAttrIndex*: uint16 # `bootstrap_method_attr_index`: `u2`
      idNameAndTypeIndex*: NavaConstantPoolIndex # `name_and_type_index`: `u2`

    of ncModule: # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.11
      ## Must be a valid index into the constant pool. Must be a utf8 info structure.
      mNameIndex*: NavaConstantPoolIndex # `name_index`: `u2`

    of ncPackage: # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.12
      ## Must be a valid index into the constant pool. Must be a utf8 info structure.
      pNameIndex*: NavaConstantPoolIndex # `name_index`: `u2`

  NavaField* = object # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.5
    accessFlags*: set[NavaFieldAccessFlag]  # `access_flags`: `u2`
    nameIndex*: NavaConstantPoolIndex       # `name_index`: `u2`
    descriptorIndex*: NavaConstantPoolIndex # `descriptor_index`: `u2`
    attributes*: seq[NavaAttribute]         # `attributes_count`: `u2`, `attributes`: `attribute_info[]`

  NavaMethod* = object # https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.6
    accessFlags*: set[NavaMethodAccessFlag] # `access_flags`: `u2`
    nameIndex*: NavaConstantPoolIndex       # `name_index`: `u2`
    descriptorIndex*: NavaConstantPoolIndex # `descriptor_index`: `u2`
    attributes*: seq[NavaAttribute]         # `attributes_count`: `u2`, `attributes`: `attribute_info[]`

  NavaAttribute* = object
    ## TODO

proc cv(major: uint16; minor = 0'u16): NavaClassVersion = NavaClassVersion(major: major, minor: minor)

const
  MagicNumber = 0xCAFEBABE'u32 # The magic number of the JVM class file.

  ConstantIntroducedIn: Table[NavaConstantKind, NavaClassVersion] = {
    ncUtf8: cv(45'u16, 3'u16),
    ncInteger: cv(45'u16, 3'u16),
    ncFloat: cv(45'u16, 3'u16),
    ncLong: cv(45'u16, 3'u16),
    ncDouble: cv(45'u16, 3'u16),
    ncClass: cv(45'u16, 3'u16),
    ncString: cv(45'u16, 3'u16),
    ncFieldRef: cv(45'u16, 3'u16),
    ncMethodRef: cv(45'u16, 3'u16),
    ncInterfaceMethodRef: cv(45'u16, 3'u16),
    ncNameAndType: cv(45'u16, 3'u16),
    ncMethodHandle: cv(51'u16),
    ncMethodType: cv(51'u16),
    ncDynamic: cv(53'u16),
    ncInvokeDynamic: cv(51'u16),
    ncModule: cv(53'u16),
    ncPackage: cv(53'u16),
  }.toTable


  #[
    From https://docs.oracle.com/javase/specs/jvms/se22/html/jvms-4.html#jvms-4.4.8

    If the value of the reference_kind item is 5 (REF_invokeVirtual), 6 (REF_invokeStatic), 7 (REF_invokeSpecial),
    or 9 (REF_invokeInterface), the name of the method represented by a CONSTANT_Methodref_info structure or a
    CONSTANT_InterfaceMethodref_info structure must not be `<init>` or `<clinit>`.

    If the value is 8 (REF_newInvokeSpecial), the name of the method represented by a CONSTANT_Methodref_info
    structure must be `<init>`.
  ]#
  ConstantMethodHandleRestrictions: Table[set[NavaMethodKind], Table[NavaClassVersion, seq[NavaConstantKind]]] = {
    {mGetField, mGetStatic, mPutField, mPutStatic}: {cv(0): @[ncFieldRef]}.toTable,
    {mInvokeVirtual, mNewInvokeSpecial}: {cv(0): @[ncMethodRef]}.toTable,
    {mInvokeStatic, mInvokeSpecial}: {
      cv(0): @[ncMethodRef],
      cv(52): @[ncMethodRef, ncInterfaceMethodRef]
    }.toTable,
    {mInvokeInterface}: {cv(0): @[ncInterfaceMethodRef]}.toTable
  }.toTable


  MethodAccessFlagAddedRemovedIn: Table[NavaMethodAccessFlag, tuple[added: NavaClassVersion, removed: NavaClassVersion]] = {
    maPublic: (cv(0), cv(0)),
    maPrivate: (cv(0), cv(0)),
    maProtected: (cv(0), cv(0)),
    maStatic: (cv(0), cv(0)),
    maFinal: (cv(0), cv(0)),
    maSynchronised: (cv(0), cv(0)),
    maBridge: (cv(0), cv(0)),
    maVarargs: (cv(0), cv(0)),
    maNative: (cv(0), cv(0)),
    maAbstract: (cv(0), cv(0)),
    maStrict: (cv(46), cv(60)),
    maSynthetic: (cv(0), cv(0))
  }.toTable

  MethodMutuallyExclusiveFlags: seq[set[NavaMethodAccessFlag]] = @[
    {maPublic, maPrivate, maProtected}
  ]

  MethodFlagsExcludedByClassFlags: Table[NavaClassAccessFlag, set[NavaMethodAccessFlag]] = {
    caInterface: {maProtected, maFinal, maSynchronised, maNative},
    caAbstract: {maPrivate, maStatic, maFinal, maSynchronised, maNative, maStrict}
  }.toTable

  MethodFlagsRequiredByClass: Table[NavaClassAccessFlag, Table[NavaClassVersion, seq[set[NavaMethodAccessFlag]]]] = {
    caInterface: {
      cv(0): @[{maAbstract, maPublic}],
      cv(52): @[{maPublic}, {maPrivate}]
    }.toTable
  }.toTable

  MethodFlagsRequiredByName: Table[string, Table[NavaClassVersion, set[NavaMethodAccessFlag]]] = {
    "<clinit>": {cv(51): {maStatic}}.toTable
  }.toTable

  # TODO: `<init>` as the name *and* void return type must be true.
  MethodFlagsPermittedByName: Table[string, set[NavaMethodAccessFlag]] = {
    "<init>": {maPublic, maPrivate, maProtected, maVarargs, maSynthetic, maStrict}
  }.toTable
