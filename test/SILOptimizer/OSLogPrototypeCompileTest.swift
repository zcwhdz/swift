// RUN: %target-swift-frontend -swift-version 5 -emit-sil -primary-file %s -Xllvm -sil-print-after=OSLogOptimization -o /dev/null 2>&1 | %FileCheck %s --check-prefix=CHECK --check-prefix=CHECK-%target-ptrsize
// RUN: %target-swift-frontend -enable-ownership-stripping-after-serialization -swift-version 5 -emit-sil -primary-file %s -Xllvm -sil-print-after=OSLogOptimization -o /dev/null 2>&1 |  %FileCheck %s --check-prefix=CHECK --check-prefix=CHECK-%target-ptrsize
// REQUIRES: OS=macosx || OS=ios || OS=tvos || OS=watchos

// Tests for the OSLogOptimization pass that performs compile-time analysis
// and optimization of the new os log prototype APIs. The tests here check
// whether specific compile-time constants such as the format string,
// the size of the byte buffer etc. are literals after the mandatory pipeline.

import OSLogPrototype
import Foundation

if #available(OSX 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {

  // CHECK-LABEL: @${{.*}}testSimpleInterpolationL_
  func testSimpleInterpolation(h: Logger) {
    h.log(level: .debug, "Minimum integer value: \(Int.min)")

    // Check if there is a call to _os_log_impl with a literal format string.
    // CHECK-DAG is used here as it is easier to perform the checks backwards
    // from uses to the definitions.

    // CHECK-DAG: builtin "globalStringTablePointer"([[STRING:%[0-9]+]] : $String)
    // We need to wade through some borrows and copy values here.
    // CHECK-DAG: [[STRING]] = begin_borrow [[STRING2:%[0-9]+]]
    // CHECK-DAG: [[STRING2]] = copy_value [[STRING3:%[0-9]+]]
    // CHECK-DAG: [[STRING3]] = begin_borrow [[STRING4:%[0-9]+]]
    // CHECK-DAG: [[STRING4]] = apply [[STRING_INIT:%[0-9]+]]([[LIT:%[0-9]+]],
    // CHECK-DAG: [[STRING_INIT]] = function_ref @$sSS21_builtinStringLiteral17utf8CodeUnitCount7isASCIISSBp_BwBi1_tcfC
    // CHECK-DAG: [[LIT]] = string_literal utf8 "Minimum integer value: %ld"

    // Check if the size of the argument buffer is a constant.

    // CHECK-DAG: [[ALLOCATE:%[0-9]+]] = function_ref @$sSp8allocate8capacitySpyxGSi_tFZ
    // CHECK-DAG: apply [[ALLOCATE]]<UInt8>([[BUFFERSIZE:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[BUFFERSIZE]] = struct $Int ([[BUFFERSIZELIT:%[0-9]+]]
    // CHECK-64-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int64, 12
    // CHECK-32-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int32, 8

    // Check whether the header bytes: premable and argument count are constants.

    // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
    // CHECK-DAG: apply [[SERIALIZE]]([[PREAMBLE:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[PREAMBLE]] =  struct $UInt8 ([[PREAMBLELIT:%[0-9]+]] : $Builtin.Int8)
    // CHECK-DAG: [[PREAMBLELIT]] = integer_literal $Builtin.Int8, 0

    // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
    // CHECK-DAG: apply [[SERIALIZE]]([[ARGCOUNT:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[ARGCOUNT]] =  struct $UInt8 ([[ARGCOUNTLIT:%[0-9]+]] : $Builtin.Int8)
    // CHECK-DAG: [[ARGCOUNTLIT]] = integer_literal $Builtin.Int8, 1

    // Check whether argument array is folded. We need not check the contents of
    // the array which is checked by a different test suite.

    // CHECK-DAG: [[FOREACH:%[0-9]+]] = function_ref @$sSTsE7forEachyyy7ElementQzKXEKF
    // CHECK-DAG: try_apply [[FOREACH]]<Array<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>>({{%.*}}, [[ARGSARRAYADDR:%[0-9]+]])
    // CHECK-DAG: store_borrow [[ARGSARRAY2:%[0-9]+]] to [[ARGSARRAYADDR]]
    // We need to wade through some borrows and copy values here.
    // CHECK-DAG: [[ARGSARRAY2]] = begin_borrow [[ARGSARRAY3:%[0-9]+]]
    // CHECK-DAG: [[ARGSARRAY3]] = copy_value [[ARGSARRAY4:%[0-9]+]]
    // CHECK-DAG: [[ARGSARRAY4]] = begin_borrow [[ARGSARRAY:%[0-9]+]]
    // CHECK-DAG: ([[ARGSARRAY]], {{%.*}}) = destructure_tuple [[ARRAYINITRES:%[0-9]+]]
    // CHECK-DAG: [[ARRAYINITRES]] = apply [[ARRAYINIT:%[0-9]+]]<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>([[ARRAYSIZE:%[0-9]+]])
    // CHECK-DAG: [[ARRAYINIT]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
    // CHECK-DAG: [[ARRAYSIZE]] = integer_literal $Builtin.Word, 3
  }

  // CHECK-LABEL: @${{.*}}testInterpolationWithFormatOptionsL_
  func testInterpolationWithFormatOptions(h: Logger) {
    h.log(level: .info, "Maximum unsigned integer value: \(UInt.max, format: .hex)")

    // Check if there is a call to _os_log_impl with a literal format string.

    // CHECK-DAG: builtin "globalStringTablePointer"([[STRING:%[0-9]+]] : $String)
    // CHECK-DAG: [[STRING]] = begin_borrow [[STRING2:%[0-9]+]]
    // CHECK-DAG: [[STRING2]] = copy_value [[STRING3:%[0-9]+]]
    // CHECK-DAG: [[STRING3]] = begin_borrow [[STRING4:%[0-9]+]]
    // CHECK-DAG: [[STRING4]] = apply [[STRING_INIT:%[0-9]+]]([[LIT:%[0-9]+]],
    // CHECK-DAG: [[STRING_INIT]] = function_ref @$sSS21_builtinStringLiteral17utf8CodeUnitCount7isASCIISSBp_BwBi1_tcfC
    // CHECK-DAG: [[LIT]] = string_literal utf8 "Maximum unsigned integer value: %lx"

    // Check if the size of the argument buffer is a constant.

    // CHECK-DAG: [[ALLOCATE:%[0-9]+]] = function_ref @$sSp8allocate8capacitySpyxGSi_tFZ
    // CHECK-DAG: apply [[ALLOCATE]]<UInt8>([[BUFFERSIZE:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[BUFFERSIZE]] = struct $Int ([[BUFFERSIZELIT:%[0-9]+]]
    // CHECK-64-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int64, 12
    // CHECK-32-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int32, 8

    // Check whether the header bytes: premable and argument count are constants.

    // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
    // CHECK-DAG: apply [[SERIALIZE]]([[PREAMBLE:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[PREAMBLE]] =  struct $UInt8 ([[PREAMBLELIT:%[0-9]+]] : $Builtin.Int8)
    // CHECK-DAG: [[PREAMBLELIT]] = integer_literal $Builtin.Int8, 0

    // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
    // CHECK-DAG: apply [[SERIALIZE]]([[ARGCOUNT:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[ARGCOUNT]] =  struct $UInt8 ([[ARGCOUNTLIT:%[0-9]+]] : $Builtin.Int8)
    // CHECK-DAG: [[ARGCOUNTLIT]] = integer_literal $Builtin.Int8, 1

    // Check whether argument array is folded. We need not check the contents of
    // the array which is checked by a different test suite.

    // CHECK-DAG: [[FOREACH:%[0-9]+]] = function_ref @$sSTsE7forEachyyy7ElementQzKXEKF
    // CHECK-DAG: try_apply [[FOREACH]]<Array<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>>({{%.*}}, [[ARGSARRAYADDR:%[0-9]+]])
    // CHECK-DAG: store_borrow [[ARGSARRAY2:%[0-9]+]] to [[ARGSARRAYADDR]]
    // CHECK-DAG: [[ARGSARRAY2]] = begin_borrow [[ARGSARRAY3:%[0-9]+]]
    // CHECK-DAG: [[ARGSARRAY3]] = copy_value [[ARGSARRAY4:%[0-9]+]]
    // CHECK-DAG: [[ARGSARRAY4]] = begin_borrow [[ARGSARRAY:%[0-9]+]]
    // CHECK-DAG: ([[ARGSARRAY]], {{%.*}}) = destructure_tuple [[ARRAYINITRES:%[0-9]+]]
    // CHECK-DAG: [[ARRAYINITRES]] = apply [[ARRAYINIT:%[0-9]+]]<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>([[ARRAYSIZE:%[0-9]+]])
    // CHECK-DAG: [[ARRAYINIT]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
    // CHECK-DAG: [[ARRAYSIZE]] = integer_literal $Builtin.Word, 3
  }

  // CHECK-LABEL: @${{.*}}testInterpolationWithFormatOptionsAndPrivacyL_
  func testInterpolationWithFormatOptionsAndPrivacy(h: Logger) {
    let privateID: UInt = 0x79abcdef
    h.log(
      level: .error,
      "Private Identifier: \(privateID, format: .hex, privacy: .private)")

    // Check if there is a call to _os_log_impl with a literal format string.

    // CHECK-DAG: builtin "globalStringTablePointer"([[STRING:%[0-9]+]] : $String)
    // CHECK-DAG: [[STRING]] = begin_borrow [[STRING2:%[0-9]+]]
    // CHECK-DAG: [[STRING2]] = copy_value [[STRING3:%[0-9]+]]
    // CHECK-DAG: [[STRING3]] = begin_borrow [[STRING4:%[0-9]+]]
    // CHECK-DAG: [[STRING4]] = apply [[STRING_INIT:%[0-9]+]]([[LIT:%[0-9]+]],
    // CHECK-DAG: [[STRING_INIT]] = function_ref @$sSS21_builtinStringLiteral17utf8CodeUnitCount7isASCIISSBp_BwBi1_tcfC
    // CHECK-DAG: [[LIT]] = string_literal utf8 "Private Identifier: %{private}lx"

    // Check if the size of the argument buffer is a constant.

    // CHECK-DAG: [[ALLOCATE:%[0-9]+]] = function_ref @$sSp8allocate8capacitySpyxGSi_tFZ
    // CHECK-DAG: apply [[ALLOCATE]]<UInt8>([[BUFFERSIZE:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[BUFFERSIZE]] = struct $Int ([[BUFFERSIZELIT:%[0-9]+]]
    // CHECK-64-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int64, 12
    // CHECK-32-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int32, 8

    // Check whether the header bytes: premable and argument count are constants.

    // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
    // CHECK-DAG: apply [[SERIALIZE]]([[PREAMBLE:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[PREAMBLE]] =  struct $UInt8 ([[PREAMBLELIT:%[0-9]+]] : $Builtin.Int8)
    // CHECK-DAG: [[PREAMBLELIT]] = integer_literal $Builtin.Int8, 1

    // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
    // CHECK-DAG: apply [[SERIALIZE]]([[ARGCOUNT:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[ARGCOUNT]] =  struct $UInt8 ([[ARGCOUNTLIT:%[0-9]+]] : $Builtin.Int8)
    // CHECK-DAG: [[ARGCOUNTLIT]] = integer_literal $Builtin.Int8, 1

    // Check whether argument array is folded. We need not check the contents of
    // the array which is checked by a different test suite.

    // CHECK-DAG: [[FOREACH:%[0-9]+]] = function_ref @$sSTsE7forEachyyy7ElementQzKXEKF
    // CHECK-DAG: try_apply [[FOREACH]]<Array<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>>({{%.*}}, [[ARGSARRAYADDR:%[0-9]+]])
    // CHECK-DAG: store_borrow [[ARGSARRAY2:%[0-9]+]] to [[ARGSARRAYADDR]]
    // CHECK-DAG: [[ARGSARRAY2]] = begin_borrow [[ARGSARRAY3:%[0-9]+]]
    // CHECK-DAG: [[ARGSARRAY3]] = copy_value [[ARGSARRAY4:%[0-9]+]]
    // CHECK-DAG: [[ARGSARRAY4]] = begin_borrow [[ARGSARRAY:%[0-9]+]]
    // CHECK-DAG: ([[ARGSARRAY]], {{%.*}}) = destructure_tuple [[ARRAYINITRES:%[0-9]+]]
    // CHECK-DAG: [[ARRAYINITRES]] = apply [[ARRAYINIT:%[0-9]+]]<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>([[ARRAYSIZE:%[0-9]+]])
    // CHECK-DAG: [[ARRAYINIT]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
    // CHECK-DAG: [[ARRAYSIZE]] = integer_literal $Builtin.Word, 3
  }

  // CHECK-LABEL: @${{.*}}testInterpolationWithMultipleArgumentsL_
  func testInterpolationWithMultipleArguments(h: Logger) {
    let privateID = 0x79abcdef
    let filePermissions: UInt = 0o777
    let pid = 122225
    h.log(
      level: .error,
      """
      Access prevented: process \(pid, privacy: .public) initiated by \
      user: \(privateID, privacy: .private) attempted resetting \
      permissions to \(filePermissions, format: .octal)
      """)

    // Check if there is a call to _os_log_impl with a literal format string.

    // CHECK-DAG: builtin "globalStringTablePointer"([[STRING:%[0-9]+]] : $String)
    // CHECK-DAG: [[STRING]] = begin_borrow [[STRING2:%[0-9]+]]
    // CHECK-DAG: [[STRING2]] = copy_value [[STRING3:%[0-9]+]]
    // CHECK-DAG: [[STRING3]] = begin_borrow [[STRING4:%[0-9]+]]
    // CHECK-DAG: [[STRING4]] = apply [[STRING_INIT:%[0-9]+]]([[LIT:%[0-9]+]],
    // CHECK-DAG: [[STRING_INIT]] = function_ref @$sSS21_builtinStringLiteral17utf8CodeUnitCount7isASCIISSBp_BwBi1_tcfC
    // CHECK-DAG: [[LIT]] = string_literal utf8 "Access prevented: process %{public}ld initiated by user: %{private}ld attempted resetting permissions to %lo"

    // Check if the size of the argument buffer is a constant.

    // CHECK-DAG: [[ALLOCATE:%[0-9]+]] = function_ref @$sSp8allocate8capacitySpyxGSi_tFZ
    // CHECK-DAG: apply [[ALLOCATE]]<UInt8>([[BUFFERSIZE:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[BUFFERSIZE]] = struct $Int ([[BUFFERSIZELIT:%[0-9]+]]
    // CHECK-64-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int64, 32
    // CHECK-32-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int32, 20

    // Check whether the header bytes: premable and argument count are constants.

    // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
    // CHECK-DAG: apply [[SERIALIZE]]([[PREAMBLE:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[PREAMBLE]] =  struct $UInt8 ([[PREAMBLELIT:%[0-9]+]] : $Builtin.Int8)
    // CHECK-DAG: [[PREAMBLELIT]] = integer_literal $Builtin.Int8, 1

    // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
    // CHECK-DAG: apply [[SERIALIZE]]([[ARGCOUNT:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[ARGCOUNT]] =  struct $UInt8 ([[ARGCOUNTLIT:%[0-9]+]] : $Builtin.Int8)
    // CHECK-DAG: [[ARGCOUNTLIT]] = integer_literal $Builtin.Int8, 3

    // Check whether argument array is folded. We need not check the contents of
    // the array which is checked by a different test suite.

    // CHECK-DAG: [[FOREACH:%[0-9]+]] = function_ref @$sSTsE7forEachyyy7ElementQzKXEKF
    // CHECK-DAG: try_apply [[FOREACH]]<Array<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>>({{%.*}}, [[ARGSARRAYADDR:%[0-9]+]])
    // CHECK-DAG: store_borrow [[ARGSARRAY2:%[0-9]+]] to [[ARGSARRAYADDR]]
    // CHECK-DAG: [[ARGSARRAY2]] = begin_borrow [[ARGSARRAY3:%[0-9]+]]
    // CHECK-DAG: [[ARGSARRAY3]] = copy_value [[ARGSARRAY4:%[0-9]+]]
    // CHECK-DAG: [[ARGSARRAY4]] = begin_borrow [[ARGSARRAY:%[0-9]+]]
    // CHECK-DAG: ([[ARGSARRAY]], {{%.*}}) = destructure_tuple [[ARRAYINITRES:%[0-9]+]]
    // CHECK-DAG: [[ARRAYINITRES]] = apply [[ARRAYINIT:%[0-9]+]]<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>([[ARRAYSIZE:%[0-9]+]])
    // CHECK-DAG: [[ARRAYINIT]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
    // CHECK-DAG: [[ARRAYSIZE]] = integer_literal $Builtin.Word, 9
  }

  // CHECK-LABEL: @${{.*}}testLogMessageWithoutDataL_
  func testLogMessageWithoutData(h: Logger) {
    // FIXME: here `ExpressibleByStringLiteral` conformance of OSLogMessage
    // is used. In this case, the constant evaluation begins from the apply of
    // the "string.makeUTF8: initializer. The constant evaluator ends up using
    // the backward mode to identify the string_literal inst passed to the
    // initializer. Eliminate  reliance on this backward mode by starting from
    // the string_literal inst, instead of initialization instruction.
    h.log("A message with no data")

    // Check if there is a call to _os_log_impl with a literal format string.

    // CHECK-DAG: builtin "globalStringTablePointer"([[STRING:%[0-9]+]] : $String)
    // CHECK-DAG: [[STRING]] = begin_borrow [[STRING2:%[0-9]+]]
    // CHECK-DAG: [[STRING2]] = copy_value [[STRING3:%[0-9]+]]
    // CHECK-DAG: [[STRING3]] = begin_borrow [[STRING4:%[0-9]+]]
    // CHECK-DAG: [[STRING4]] = apply [[STRING_INIT:%[0-9]+]]([[LIT:%[0-9]+]],
    // CHECK-DAG: [[STRING_INIT]] = function_ref @$sSS21_builtinStringLiteral17utf8CodeUnitCount7isASCIISSBp_BwBi1_tcfC
    // CHECK-DAG: [[LIT]] = string_literal utf8 "A message with no data"

    // Check if the size of the argument buffer is a constant.

    // CHECK-DAG: [[ALLOCATE:%[0-9]+]] = function_ref @$sSp8allocate8capacitySpyxGSi_tFZ
    // CHECK-DAG: apply [[ALLOCATE]]<UInt8>([[BUFFERSIZE:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[BUFFERSIZE]] = struct $Int ([[BUFFERSIZELIT:%[0-9]+]]
    // CHECK-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int{{[0-9]+}}, 2

    // Check whether the header bytes: premable and argument count are constants.

    // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
    // CHECK-DAG: apply [[SERIALIZE]]([[PREAMBLE:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[PREAMBLE]] =  struct $UInt8 ([[PREAMBLELIT:%[0-9]+]] : $Builtin.Int8)
    // CHECK-DAG: [[PREAMBLELIT]] = integer_literal $Builtin.Int8, 0

    // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
    // CHECK-DAG: apply [[SERIALIZE]]([[ARGCOUNT:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[ARGCOUNT]] =  struct $UInt8 ([[ARGCOUNTLIT:%[0-9]+]] : $Builtin.Int8)
    // CHECK-DAG: [[ARGCOUNTLIT]] = integer_literal $Builtin.Int8, 0

    // Check whether argument array is folded.

    // CHECK-DAG: [[FOREACH:%[0-9]+]] = function_ref @$sSTsE7forEachyyy7ElementQzKXEKF
    // CHECK-DAG: try_apply [[FOREACH]]<Array<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>>({{%.*}}, [[ARGSARRAYADDR:%[0-9]+]])
    // CHECK-DAG: store_borrow [[ARGSARRAY2:%[0-9]+]] to [[ARGSARRAYADDR]]
    // CHECK-DAG: [[ARGSARRAY2]] = begin_borrow [[ARGSARRAY3:%[0-9]+]]
    // CHECK-DAG: [[ARGSARRAY3]] = copy_value [[ARGSARRAY4:%[0-9]+]]
    // CHECK-DAG: [[ARGSARRAY4]] = begin_borrow [[ARGSARRAY:%[0-9]+]]
    // CHECK-DAG: ([[ARGSARRAY]], {{%.*}}) = destructure_tuple [[ARRAYINITRES:%[0-9]+]]
    // CHECK-DAG: [[ARRAYINITRES]] = apply [[ARRAYINIT:%[0-9]+]]<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>([[ARRAYSIZE:%[0-9]+]])
    // CHECK-DAG: [[ARRAYINIT]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
    // CHECK-DAG: [[ARRAYSIZE]] = integer_literal $Builtin.Word, 0
  }

  // CHECK-LABEL: @${{.*}}testEscapingOfPercentsL_
  func testEscapingOfPercents(h: Logger) {
    h.log("Process failed after 99% completion")
    // CHECK-DAG: builtin "globalStringTablePointer"([[STRING:%[0-9]+]] : $String)
    // CHECK-DAG: [[STRING]] = begin_borrow [[STRING2:%[0-9]+]]
    // CHECK-DAG: [[STRING2]] = copy_value [[STRING3:%[0-9]+]]
    // CHECK-DAG: [[STRING3]] = begin_borrow [[STRING4:%[0-9]+]]
    // CHECK-DAG: [[STRING4]] = apply [[STRING_INIT:%[0-9]+]]([[LIT:%[0-9]+]],
    // CHECK-DAG: [[STRING_INIT]] = function_ref @$sSS21_builtinStringLiteral17utf8CodeUnitCount7isASCIISSBp_BwBi1_tcfC
    // CHECK-DAG: [[LIT]] = string_literal utf8 "Process failed after 99%% completion"
  }

  // CHECK-LABEL: @${{.*}}testDoublePercentsL_
  func testDoublePercents(h: Logger) {
    h.log("Double percents: %%")
    // CHECK-DAG: builtin "globalStringTablePointer"([[STRING:%[0-9]+]] : $String)
    // CHECK-DAG: [[STRING]] = begin_borrow [[STRING2:%[0-9]+]]
    // CHECK-DAG: [[STRING2]] = copy_value [[STRING3:%[0-9]+]]
    // CHECK-DAG: [[STRING3]] = begin_borrow [[STRING4:%[0-9]+]]
    // CHECK-DAG: [[STRING4]] = apply [[STRING_INIT:%[0-9]+]]([[LIT:%[0-9]+]],
    // CHECK-DAG: [[STRING_INIT]] = function_ref @$sSS21_builtinStringLiteral17utf8CodeUnitCount7isASCIISSBp_BwBi1_tcfC
    // CHECK-DAG: [[LIT]] = string_literal utf8 "Double percents: %%%%"
  }

  // CHECK-LABEL: @${{.*}}testSmallFormatStringsL_
  func testSmallFormatStrings(h: Logger) {
    h.log("a")
    // CHECK-DAG: builtin "globalStringTablePointer"([[STRING:%[0-9]+]] : $String)
    // CHECK-DAG: [[STRING]] = begin_borrow [[STRING2:%[0-9]+]]
    // CHECK-DAG: [[STRING2]] = copy_value [[STRING3:%[0-9]+]]
    // CHECK-DAG: [[STRING3]] = begin_borrow [[STRING4:%[0-9]+]]
    // CHECK-DAG: [[STRING4]] = apply [[STRING_INIT:%[0-9]+]]([[LIT:%[0-9]+]],
    // CHECK-DAG: [[STRING_INIT]] = function_ref @$sSS21_builtinStringLiteral17utf8CodeUnitCount7isASCIISSBp_BwBi1_tcfC
    // CHECK-DAG: [[LIT]] = string_literal utf8 "a"
  }

  /// A stress test that checks whether the optimizer handle messages with more
  /// than 48 interpolated expressions. Interpolated expressions beyond this
  /// limit must be ignored.
  // CHECK-LABEL: @${{.*}}testMessageWithTooManyArgumentsL_
  func testMessageWithTooManyArguments(h: Logger) {
    h.log(
      level: .error,
      """
      \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \
      \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \
      \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \
      \(1) \(1) \(1) \(1) \(1) \(48) \(49)
      """)

    // Check if there is a call to _os_log_impl with a literal format string.

    // CHECK-DAG: builtin "globalStringTablePointer"([[STRING:%[0-9]+]] : $String)
    // CHECK-DAG: [[STRING]] = begin_borrow [[STRING2:%[0-9]+]]
    // CHECK-DAG: [[STRING2]] = copy_value [[STRING3:%[0-9]+]]
    // CHECK-DAG: [[STRING3]] = begin_borrow [[STRING4:%[0-9]+]]
    // CHECK-DAG: [[STRING4]] = apply [[STRING_INIT:%[0-9]+]]([[LIT:%[0-9]+]],
    // CHECK-DAG: [[STRING_INIT]] = function_ref @$sSS21_builtinStringLiteral17utf8CodeUnitCount7isASCIISSBp_BwBi1_tcfC
    // CHECK-DAG: [[LIT]] = string_literal utf8 "%ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld "

    // Check if the size of the argument buffer is a constant.

    // CHECK-DAG: [[ALLOCATE:%[0-9]+]] = function_ref @$sSp8allocate8capacitySpyxGSi_tFZ
    // CHECK-DAG: apply [[ALLOCATE]]<UInt8>([[BUFFERSIZE:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[BUFFERSIZE]] = struct $Int ([[BUFFERSIZELIT:%[0-9]+]]
    // CHECK-64-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int64, 482
    // CHECK-32-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int32, 290

    // Check whether the header bytes: premable and argument count are constants.

    // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
    // CHECK-DAG: apply [[SERIALIZE]]([[PREAMBLE:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[PREAMBLE]] =  struct $UInt8 ([[PREAMBLELIT:%[0-9]+]] : $Builtin.Int8)
    // CHECK-DAG: [[PREAMBLELIT]] = integer_literal $Builtin.Int8, 0

    // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
    // CHECK-DAG: apply [[SERIALIZE]]([[ARGCOUNT:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[ARGCOUNT]] =  struct $UInt8 ([[ARGCOUNTLIT:%[0-9]+]] : $Builtin.Int8)
    // CHECK-DAG: [[ARGCOUNTLIT]] = integer_literal $Builtin.Int8, 48

    // Check whether argument array is folded.

    // CHECK-DAG: [[FOREACH:%[0-9]+]] = function_ref @$sSTsE7forEachyyy7ElementQzKXEKF
    // CHECK-DAG: try_apply [[FOREACH]]<Array<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>>({{%.*}}, [[ARGSARRAYADDR:%[0-9]+]])
    // CHECK-DAG: store_borrow [[ARGSARRAY2:%[0-9]+]] to [[ARGSARRAYADDR]]
    // CHECK-DAG: [[ARGSARRAY2]] = begin_borrow [[ARGSARRAY3:%[0-9]+]]
    // CHECK-DAG: [[ARGSARRAY3]] = copy_value [[ARGSARRAY4:%[0-9]+]]
    // CHECK-DAG: [[ARGSARRAY4]] = begin_borrow [[ARGSARRAY:%[0-9]+]]
    // CHECK-DAG: ([[ARGSARRAY]], {{%.*}}) = destructure_tuple [[ARRAYINITRES:%[0-9]+]]
    // CHECK-DAG: [[ARRAYINITRES]] = apply [[ARRAYINIT:%[0-9]+]]<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>([[ARRAYSIZE:%[0-9]+]])
    // CHECK-DAG: [[ARRAYINIT]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
    // CHECK-DAG: [[ARRAYSIZE]] = integer_literal $Builtin.Word, 144
  }

  // CHECK-LABEL: @${{.*}}testInt32InterpolationL_
  func testInt32Interpolation(h: Logger) {
    h.log("32-bit integer value: \(Int32.min)")

    // Check if there is a call to _os_log_impl with a literal format string.

    // CHECK-DAG: builtin "globalStringTablePointer"([[STRING:%[0-9]+]] : $String)
    // CHECK-DAG: [[STRING]] = begin_borrow [[STRING2:%[0-9]+]]
    // CHECK-DAG: [[STRING2]] = copy_value [[STRING3:%[0-9]+]]
    // CHECK-DAG: [[STRING3]] = begin_borrow [[STRING4:%[0-9]+]]
    // CHECK-DAG: [[STRING4]] = apply [[STRING_INIT:%[0-9]+]]([[LIT:%[0-9]+]],
    // CHECK-DAG: [[STRING_INIT]] = function_ref @$sSS21_builtinStringLiteral17utf8CodeUnitCount7isASCIISSBp_BwBi1_tcfC
    // CHECK-DAG: [[LIT]] = string_literal utf8 "32-bit integer value: %d"

    // Check if the size of the argument buffer is a constant.

    // CHECK-DAG: [[ALLOCATE:%[0-9]+]] = function_ref @$sSp8allocate8capacitySpyxGSi_tFZ
    // CHECK-DAG: apply [[ALLOCATE]]<UInt8>([[BUFFERSIZE:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[BUFFERSIZE]] = struct $Int ([[BUFFERSIZELIT:%[0-9]+]]
    // CHECK-64-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int64, 8
    // CHECK-32-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int32, 8

    // Check whether the header bytes: premable and argument count are constants.

    // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
    // CHECK-DAG: apply [[SERIALIZE]]([[PREAMBLE:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[PREAMBLE]] =  struct $UInt8 ([[PREAMBLELIT:%[0-9]+]] : $Builtin.Int8)
    // CHECK-DAG: [[PREAMBLELIT]] = integer_literal $Builtin.Int8, 0

    // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
    // CHECK-DAG: apply [[SERIALIZE]]([[ARGCOUNT:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[ARGCOUNT]] =  struct $UInt8 ([[ARGCOUNTLIT:%[0-9]+]] : $Builtin.Int8)
    // CHECK-DAG: [[ARGCOUNTLIT]] = integer_literal $Builtin.Int8, 1
  }

  // CHECK-LABEL: @${{.*}}testDynamicStringArgumentsL_
  func testDynamicStringArguments(h: Logger) {
    let concatString = "hello" + " - " + "world"
    let interpolatedString = "\(31) trillion digits of pi are known so far"

    h.log("""
      concat: \(concatString, privacy: .public) \
      interpolated: \(interpolatedString, privacy: .private)
      """)

    // Check if there is a call to _os_log_impl with a literal format string.
    // CHECK-DAG is used here as it is easier to perform the checks backwards
    // from uses to the definitions.

    // CHECK-DAG: builtin "globalStringTablePointer"([[STRING:%[0-9]+]] : $String)
    // CHECK-DAG: [[STRING]] = begin_borrow [[STRING2:%[0-9]+]]
    // CHECK-DAG: [[STRING2]] = copy_value [[STRING3:%[0-9]+]]
    // CHECK-DAG: [[STRING3]] = begin_borrow [[STRING4:%[0-9]+]]
    // CHECK-DAG: [[STRING4]] = apply [[STRING_INIT:%[0-9]+]]([[LIT:%[0-9]+]],
    // CHECK-DAG: [[STRING_INIT]] = function_ref @$sSS21_builtinStringLiteral17utf8CodeUnitCount7isASCIISSBp_BwBi1_tcfC
    // CHECK-DAG: [[LIT]] = string_literal utf8 "concat: %{public}s interpolated: %{private}s"

    // Check if the size of the argument buffer is a constant.

    // CHECK-DAG: [[ALLOCATE:%[0-9]+]] = function_ref @$sSp8allocate8capacitySpyxGSi_tFZ
    // CHECK-DAG: apply [[ALLOCATE]]<UInt8>([[BUFFERSIZE:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[BUFFERSIZE]] = struct $Int ([[BUFFERSIZELIT:%[0-9]+]]
    // CHECK-64-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int64, 22
    // CHECK-32-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int32, 14

    // Check whether the header bytes: premable and argument count are constants.

    // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
    // CHECK-DAG: apply [[SERIALIZE]]([[PREAMBLE:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[PREAMBLE]] =  struct $UInt8 ([[PREAMBLELIT:%[0-9]+]] : $Builtin.Int8)
    // CHECK-DAG: [[PREAMBLELIT]] = integer_literal $Builtin.Int8, 3

    // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
    // CHECK-DAG: apply [[SERIALIZE]]([[ARGCOUNT:%[0-9]+]], {{%.*}})
    // CHECK-DAG: [[ARGCOUNT]] =  struct $UInt8 ([[ARGCOUNTLIT:%[0-9]+]] : $Builtin.Int8)
    // CHECK-DAG: [[ARGCOUNTLIT]] = integer_literal $Builtin.Int8, 2

    // Check whether argument array is folded. We need not check the contents of
    // the array which is checked by a different test suite.

    // CHECK-DAG: [[FOREACH:%[0-9]+]] = function_ref @$sSTsE7forEachyyy7ElementQzKXEKF
    // CHECK-DAG: try_apply [[FOREACH]]<Array<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>>({{%.*}}, [[ARGSARRAYADDR:%[0-9]+]])
    // CHECK-DAG: store_borrow [[ARGSARRAY2:%[0-9]+]] to [[ARGSARRAYADDR]]
    // CHECK-DAG: [[ARGSARRAY2]] = begin_borrow [[ARGSARRAY3:%[0-9]+]]
    // CHECK-DAG: [[ARGSARRAY3]] = copy_value [[ARGSARRAY4:%[0-9]+]]
    // CHECK-DAG: [[ARGSARRAY4]] = begin_borrow [[ARGSARRAY:%[0-9]+]]
    // CHECK-DAG: ([[ARGSARRAY]], {{%.*}}) = destructure_tuple [[ARRAYINITRES:%[0-9]+]]
    // CHECK-DAG: [[ARRAYINITRES]] = apply [[ARRAYINIT:%[0-9]+]]<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>([[ARRAYSIZE:%[0-9]+]])
    // CHECK-DAG: [[ARRAYINIT]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
    // CHECK-DAG: [[ARRAYSIZE]] = integer_literal $Builtin.Word, 6
  }

  // CHECK-LABEL: @${{.*}}testNSObjectInterpolationL_
  func testNSObjectInterpolation(h: Logger) {
    let nsArray: NSArray = [0, 1, 2]
    let nsDictionary: NSDictionary = [1 : ""]
    h.log("""
      NSArray: \(nsArray, privacy: .public) \
      NSDictionary: \(nsDictionary, privacy: .private)
      """)
      // Check if there is a call to _os_log_impl with a literal format string.
      // CHECK-DAG is used here as it is easier to perform the checks backwards
      // from uses to the definitions.

      // CHECK-DAG: builtin "globalStringTablePointer"([[STRING:%[0-9]+]] : $String)
      // CHECK-DAG: [[STRING]] = begin_borrow [[STRING2:%[0-9]+]]
      // CHECK-DAG: [[STRING2]] = copy_value [[STRING3:%[0-9]+]]
      // CHECK-DAG: [[STRING3]] = begin_borrow [[STRING4:%[0-9]+]]
      // CHECK-DAG: [[STRING4]] = apply [[STRING_INIT:%[0-9]+]]([[LIT:%[0-9]+]],
      // CHECK-DAG: [[STRING_INIT]] = function_ref @$sSS21_builtinStringLiteral17utf8CodeUnitCount7isASCIISSBp_BwBi1_tcfC
      // CHECK-DAG: [[LIT]] = string_literal utf8 "NSArray: %{public}@ NSDictionary: %{private}@"

      // Check if the size of the argument buffer is a constant.

      // CHECK-DAG: [[ALLOCATE:%[0-9]+]] = function_ref @$sSp8allocate8capacitySpyxGSi_tFZ
      // CHECK-DAG: apply [[ALLOCATE]]<UInt8>([[BUFFERSIZE:%[0-9]+]], {{%.*}})
      // CHECK-DAG: [[BUFFERSIZE]] = struct $Int ([[BUFFERSIZELIT:%[0-9]+]]
      // CHECK-64-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int64, 22
      // CHECK-32-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int32, 14

      // Check whether the header bytes: premable and argument count are constants.

      // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
      // CHECK-DAG: apply [[SERIALIZE]]([[PREAMBLE:%[0-9]+]], {{%.*}})
      // CHECK-DAG: [[PREAMBLE]] =  struct $UInt8 ([[PREAMBLELIT:%[0-9]+]] : $Builtin.Int8)
      // CHECK-DAG: [[PREAMBLELIT]] = integer_literal $Builtin.Int8, 3

      // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
      // CHECK-DAG: apply [[SERIALIZE]]([[ARGCOUNT:%[0-9]+]], {{%.*}})
      // CHECK-DAG: [[ARGCOUNT]] =  struct $UInt8 ([[ARGCOUNTLIT:%[0-9]+]] : $Builtin.Int8)
      // CHECK-DAG: [[ARGCOUNTLIT]] = integer_literal $Builtin.Int8, 2

      // Check whether argument array is folded. We need not check the contents of
      // the array which is checked by a different test suite.

      // CHECK-DAG: [[FOREACH:%[0-9]+]] = function_ref @$sSTsE7forEachyyy7ElementQzKXEKF
      // CHECK-DAG: try_apply [[FOREACH]]<Array<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>>({{%.*}}, [[ARGSARRAYADDR:%[0-9]+]])
      // CHECK-DAG: store_borrow [[ARGSARRAY2:%[0-9]+]] to [[ARGSARRAYADDR]]
      // CHECK-DAG: [[ARGSARRAY2]] = begin_borrow [[ARGSARRAY3:%[0-9]+]]
      // CHECK-DAG: [[ARGSARRAY3]] = copy_value [[ARGSARRAY4:%[0-9]+]]
      // CHECK-DAG: [[ARGSARRAY4]] = begin_borrow [[ARGSARRAY:%[0-9]+]]
      // CHECK-DAG: ([[ARGSARRAY]], {{%.*}}) = destructure_tuple [[ARRAYINITRES:%[0-9]+]]
      // CHECK-DAG: [[ARRAYINITRES]] = apply [[ARRAYINIT:%[0-9]+]]<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>([[ARRAYSIZE:%[0-9]+]])
      // CHECK-DAG: [[ARRAYINIT]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
      // CHECK-DAG: [[ARRAYSIZE]] = integer_literal $Builtin.Word, 6
  }

  // CHECK-LABEL: @${{.*}}testDoubleInterpolationL_
  func testDoubleInterpolation(h: Logger) {
    let twoPi = 2 * 3.14
    h.log("Tau = \(twoPi)")
      // Check if there is a call to _os_log_impl with a literal format string.
      // CHECK-DAG is used here as it is easier to perform the checks backwards
      // from uses to the definitions.

      // CHECK-DAG: builtin "globalStringTablePointer"([[STRING:%[0-9]+]] : $String)
      // CHECK-DAG: [[STRING]] = begin_borrow [[STRING2:%[0-9]+]]
      // CHECK-DAG: [[STRING2]] = copy_value [[STRING3:%[0-9]+]]
      // CHECK-DAG: [[STRING3]] = begin_borrow [[STRING4:%[0-9]+]]
      // CHECK-DAG: [[STRING4]] = apply [[STRING_INIT:%[0-9]+]]([[LIT:%[0-9]+]],
      // CHECK-DAG: [[STRING_INIT]] = function_ref @$sSS21_builtinStringLiteral17utf8CodeUnitCount7isASCIISSBp_BwBi1_tcfC
      // CHECK-DAG: [[LIT]] = string_literal utf8 "Tau = %f"

      // Check if the size of the argument buffer is a constant.

      // CHECK-DAG: [[ALLOCATE:%[0-9]+]] = function_ref @$sSp8allocate8capacitySpyxGSi_tFZ
      // CHECK-DAG: apply [[ALLOCATE]]<UInt8>([[BUFFERSIZE:%[0-9]+]], {{%.*}})
      // CHECK-DAG: [[BUFFERSIZE]] = struct $Int ([[BUFFERSIZELIT:%[0-9]+]]
      // CHECK-64-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int64, 12
      // CHECK-32-DAG: [[BUFFERSIZELIT]] = integer_literal $Builtin.Int32, 12

      // Check whether the header bytes: premable and argument count are constants.

      // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
      // CHECK-DAG: apply [[SERIALIZE]]([[PREAMBLE:%[0-9]+]], {{%.*}})
      // CHECK-DAG: [[PREAMBLE]] =  struct $UInt8 ([[PREAMBLELIT:%[0-9]+]] : $Builtin.Int8)
      // CHECK-DAG: [[PREAMBLELIT]] = integer_literal $Builtin.Int8, 0

      // CHECK-DAG: [[SERIALIZE:%[0-9]+]] = function_ref @$s14OSLogPrototype9serialize_2atys5UInt8V_SpyAEGztF
      // CHECK-DAG: apply [[SERIALIZE]]([[ARGCOUNT:%[0-9]+]], {{%.*}})
      // CHECK-DAG: [[ARGCOUNT]] =  struct $UInt8 ([[ARGCOUNTLIT:%[0-9]+]] : $Builtin.Int8)
      // CHECK-DAG: [[ARGCOUNTLIT]] = integer_literal $Builtin.Int8, 1

      // Check whether argument array is folded. The contents of the array is
      // not checked here, but is checked by a different test suite.

      // CHECK-DAG: [[FOREACH:%[0-9]+]] = function_ref @$sSTsE7forEachyyy7ElementQzKXEKF
      // CHECK-DAG: try_apply [[FOREACH]]<Array<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>>({{%.*}}, [[ARGSARRAYADDR:%[0-9]+]])
      // CHECK-DAG: store_borrow [[ARGSARRAY2:%[0-9]+]] to [[ARGSARRAYADDR]]
      // CHECK-DAG: [[ARGSARRAY2]] = begin_borrow [[ARGSARRAY3:%[0-9]+]]
      // CHECK-DAG: [[ARGSARRAY3]] = copy_value [[ARGSARRAY4:%[0-9]+]]
      // CHECK-DAG: [[ARGSARRAY4]] = begin_borrow [[ARGSARRAY:%[0-9]+]]
      // CHECK-DAG: ([[ARGSARRAY]], {{%.*}}) = destructure_tuple [[ARRAYINITRES:%[0-9]+]]
      // CHECK-DAG: [[ARRAYINITRES]] = apply [[ARRAYINIT:%[0-9]+]]<(inout UnsafeMutablePointer<UInt8>, inout Array<AnyObject>) -> ()>([[ARRAYSIZE:%[0-9]+]])
      // CHECK-DAG: [[ARRAYINIT]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
      // CHECK-DAG: [[ARRAYSIZE]] = integer_literal $Builtin.Word, 3
  }

  // CHECK-LABEL: @${{.*}}testDeadCodeEliminationL_
  func testDeadCodeElimination(
    h: Logger,
    number: Int,
    num32bit: Int32,
    string: String
  ) {
    h.log("A message with no data")
    h.log("smallstring")
    h.log(
      level: .error,
      """
      A message with many interpolations \(number), \(num32bit), \(string), \
      and a suffix
      """)
    h.log(
      level: .info,
      """
      \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \
      \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \
      \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \(1) \
      \(1) \(1) \(1) \(1) \(1) \(48) \(49)
      """)
    let concatString = string + ":" + String(number)
    h.log("\(concatString)")
      // CHECK-NOT: OSLogMessage
      // CHECK-NOT: OSLogInterpolation
      // CHECK-LABEL: end sil function '${{.*}}testDeadCodeEliminationL_
  }
}

protocol Proto {
  var property: String { get set }
}

// Test capturing of address-only types in autoclosures.

if #available(OSX 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
  // CHECK-LABEL: @${{.*}}testInterpolationOfExistentialsL_
  func testInterpolationOfExistentials(h: Logger, p: Proto) {
    h.debug("A protocol's property \(p.property)")
  }

  // CHECK-LABEL: @${{.*}}testInterpolationOfGenericsL_
  func testInterpolationOfGenerics<T : Proto>(h: Logger, p: T) {
    h.debug("A generic argument's property \(p.property)")
  }
}

