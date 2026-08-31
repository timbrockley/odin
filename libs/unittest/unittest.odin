#+feature global-context

package unittest

import "base:runtime"
import "core:bytes"
import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:path/filepath"
import "core:reflect"
import "core:sync"
import "core:sync/chan"
import "core:time"

//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
RESET :: "\x1B[0m"; BLUE :: "\x1B[34m"; MAGENTA :: "\x1B[35m"; RED :: "\x1B[31m"; GREEN :: "\x1B[32m"
//--------------------------------------------------------------------------------
start_time_ns: i64
count_passed, count_failed: int
//--------------------------------------------------------------------------------
mutex: sync.Mutex
cond: sync.Cond
waitCondition: bool
channels: map[string]chan.Chan(bool)
//--------------------------------------------------------------------------------
arena: virtual.Arena
allocator: mem.Allocator = virtual.arena_allocator(&arena)
// allocator: mem.Allocator
//--------------------------------------------------------------------------------
options: OptionsResult
//--------------------------------------------------------------------------------
default_options := OptionsResult {
	show_passes = false,
}
//--------------------------------------------------------------------------------
OptionsUnion :: struct {
	show_passes: union {
		bool,
	},
}
//--------------------------------------------------------------------------------
OptionsResult :: struct {
	show_passes: bool,
}
//--------------------------------------------------------------------------------
UnittestError :: union #shared_nil {
	ChannelError,
	mem.Allocator_Error,
}
//--------------------------------------------------------------------------------
ChannelError :: enum {
	None,
	SendSignalError,
	ReceiveSignalError,
	InvalidStructType,
	InvalidStructInstance,
	InvalidStructField,
	InvalidValue,
	InvalidValueType,
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
@(init)
setContext :: proc() {
	//----------------------------------------
	// allocator = context.allocator
	channels = make(map[string]chan.Chan(bool), allocator)
	//----------------------------------------
}
//--------------------------------------------------------------------------------
@(fini)
cleanup :: proc() {
	delete(channels)
	virtual.arena_destroy(&arena)
}
// cleanup :: proc() {delete(channels)}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
init :: proc(_options: OptionsUnion = {}) {
	//-----------------------------------------------------------
	options, _ = newOptionsReflect(_options)
	//-----------------------------------------------------------
	start_time_ns = time.time_to_unix_nano(time.now())
	//-----------------------------------------------------------
	printLine()
	//-----------------------------------------------------------
}
//--------------------------------------------------------------------------------
initBroadcast :: proc() {
	sync.mutex_lock(&mutex); defer sync.mutex_unlock(&mutex)
	waitCondition = true
	sync.cond_broadcast(&cond)
}
//--------------------------------------------------------------------------------
initWait :: proc() {
	sync.mutex_lock(&mutex); defer sync.mutex_unlock(&mutex)
	for !waitCondition {sync.cond_wait(&cond, &mutex)}
}
//--------------------------------------------------------------------------------
getChannel :: proc(name: string) -> (chan.Chan(bool), UnittestError) {
	//----------------------------------------
	sync.mutex_lock(&mutex)
	defer sync.mutex_unlock(&mutex)

	channel, exists := channels[name]
	if (!exists) {
		err: UnittestError
		channel, err = chan.create(chan.Chan(bool), allocator)
		if err != nil {return {}, err}
		channels[name] = channel
	}

	return channel, nil
	//----------------------------------------
}
//--------------------------------------------------------------------------------
sendSignal :: proc(name: string, broadcast: bool = false) -> UnittestError {
	if (broadcast) {initBroadcast()}
	channel, err := getChannel(name); if err != nil {return err}
	if success := chan.send(channel, true); !success {return .SendSignalError}
	return nil
}
//--------------------------------------------------------------------------------
receiveSignal :: proc(name: string, wait: bool = false) -> UnittestError {
	if (wait) {initWait()}
	channel, err := getChannel(name); if err != nil {return err}
	if _, ok := chan.recv(channel); !ok {return .ReceiveSignalError}
	return nil
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
printActual :: proc() {printColour(BLUE, "ACTUAL")}
printExpected :: proc() {printColour(MAGENTA, "EXPECTED")}
printPass :: proc(loc: runtime.Source_Code_Location = {}) {
	if loc.line > 0 {printf("(%d) ", loc.line)}
	printColour(GREEN, "PASS")
}
printFail :: proc(loc: runtime.Source_Code_Location = {}) {
	if loc.line > 0 {printfln("(%d) [%s]", loc.line, filepath.base(loc.file_path))}
	printColour(RED, "FAIL")
}
printColour :: proc(colour: string, string: string) {
	fmt.eprint(colour); fmt.print(string); fmt.eprint(RESET)
}
print := fmt.print
printf := fmt.printf
println := fmt.println
printfln := fmt.printfln
//--------------------------------------------------------------------------------
printLine :: proc() {fmt.println(
		"--------------------------------------------------------------------------------",
	)}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
compareTypeID :: proc(name: string, actual: typeid, expected: typeid, loc := #caller_location) {
	//-----------------------------------------------------------
	if actual == expected {
		//----------------------------------------
		if options.show_passes {
			printPass(loc)
			printfln(": %s", name)
		}
		//----------------------------------------
		count_passed += 1
		//----------------------------------------
	} else {
		//----------------------------------------
		printFail(loc); printfln(":     %s", name)
		//----------------------------------------
		printActual(); printfln(":   %v", actual)
		//----------------------------------------
		printExpected(); printfln(": %v", expected)
		//----------------------------------------
		printLine()
		//----------------------------------------
		count_failed += 1
		//----------------------------------------
	}
	//-----------------------------------------------------------
}
//--------------------------------------------------------------------------------
compareString :: proc(name: string, actual: string, expected: string, loc := #caller_location) {
	//-----------------------------------------------------------
	if actual == expected {
		//----------------------------------------
		if options.show_passes {
			printPass(loc)
			printfln(": %s", name)
			printLine()
		}
		//----------------------------------------
		count_passed += 1
		//----------------------------------------
	} else {
		//----------------------------------------
		printFail(loc); printfln(":     %s", name)
		//----------------------------------------
		printActual(); printfln(":   %s", actual)
		//----------------------------------------
		printExpected(); printfln(": %s", expected)
		//----------------------------------------
		printLine()
		//----------------------------------------
		count_failed += 1
		//----------------------------------------
	}
	//-----------------------------------------------------------
}
//--------------------------------------------------------------------------------
compareCString :: proc(name: string, actual: cstring, expected: cstring, loc := #caller_location) {
	//-----------------------------------------------------------
	if actual == expected {
		//----------------------------------------
		if options.show_passes {
			printPass(loc)
			printfln(": %s", name)
			printLine()
		}
		//----------------------------------------
		count_passed += 1
		//----------------------------------------
	} else {
		//----------------------------------------
		printFail(loc); printfln(":     %s", name)
		//----------------------------------------
		printActual(); printfln(":   %s", actual)
		//----------------------------------------
		printExpected(); printfln(": %s", expected)
		//----------------------------------------
		printLine()
		//----------------------------------------
		count_failed += 1
		//----------------------------------------
	}
	//-----------------------------------------------------------
}
//--------------------------------------------------------------------------------
compareBytes :: proc(name: string, actual: []byte, expected: []byte, loc := #caller_location) {
	//-----------------------------------------------------------
	if bytes.equal(actual, expected) {
		//----------------------------------------
		if options.show_passes {
			printPass(loc)
			printfln(": %s", name)
			printLine()
		}
		//----------------------------------------
		count_passed += 1
		//----------------------------------------
	} else {
		//----------------------------------------
		printFail(loc); printfln(":     %s", name)
		//----------------------------------------
		printActual(); printfln(":   %v", actual)
		//----------------------------------------
		printExpected(); printfln(": %v", expected)
		//----------------------------------------
		printLine()
		//----------------------------------------
		count_failed += 1
		//----------------------------------------
	}
	//-----------------------------------------------------------
}
//--------------------------------------------------------------------------------
compareByte :: proc(name: string, actual: byte, expected: byte, loc := #caller_location) {
	//-----------------------------------------------------------
	if actual == expected {
		//----------------------------------------
		if options.show_passes {
			printPass(loc)
			printfln(": %s", name)
			printLine()
		}
		//----------------------------------------
		count_passed += 1
		//----------------------------------------
	} else {
		//----------------------------------------
		printFail(loc); printfln(":     %s", name)
		//----------------------------------------
		printActual(); printfln(":   %v", actual)
		//----------------------------------------
		printExpected(); printfln(": %v", expected)
		//----------------------------------------
		printLine()
		//----------------------------------------
		count_failed += 1
		//----------------------------------------
	}
	//-----------------------------------------------------------
}
//--------------------------------------------------------------------------------
compareInteger :: proc(
	name: string,
	#any_int actual: int,
	#any_int expected: int,
	loc := #caller_location,
) {
	//-----------------------------------------------------------
	if actual == expected {
		//----------------------------------------
		if options.show_passes {
			printPass(loc)
			printfln(": %s", name)
			printLine()
		}
		//----------------------------------------
		count_passed += 1
		//----------------------------------------
	} else {
		//----------------------------------------
		printFail(loc); printfln(":     %s", name)
		//----------------------------------------
		printActual(); printfln(":   %v", actual)
		//----------------------------------------
		printExpected(); printfln(": %v", expected)
		//----------------------------------------
		printLine()
		//----------------------------------------
		count_failed += 1
		//----------------------------------------
	}
	//-----------------------------------------------------------
}
//--------------------------------------------------------------------------------
compareFloat :: proc(name: string, actual: f64, expected: f64, loc := #caller_location) {
	//-----------------------------------------------------------
	if actual == expected {
		//----------------------------------------
		if options.show_passes {
			printPass(loc)
			printfln(": %s", name)
			printLine()
		}
		//----------------------------------------
		count_passed += 1
		//----------------------------------------
	} else {
		//----------------------------------------
		printFail(loc); printfln(":     %s", name)
		//----------------------------------------
		printActual(); printfln(":   %v", actual)
		//----------------------------------------
		printExpected(); printfln(": %v", expected)
		//----------------------------------------
		printLine()
		//----------------------------------------
		count_failed += 1
		//----------------------------------------
	}
	//-----------------------------------------------------------
}
//--------------------------------------------------------------------------------
compareBool :: proc(name: string, actual: bool, expected: bool, loc := #caller_location) {
	//-----------------------------------------------------------
	if actual == expected {
		//----------------------------------------
		if options.show_passes {
			printPass(loc)
			printfln(": %s", name)
			printLine()
		}
		//----------------------------------------
		count_passed += 1
		//----------------------------------------
	} else {
		//----------------------------------------
		printFail(loc); printfln(":     %s", name)
		//----------------------------------------
		printActual(); printfln(":   %v", actual)
		//----------------------------------------
		printExpected(); printfln(": %v", expected)
		//----------------------------------------
		printLine()
		//----------------------------------------
		count_failed += 1
		//----------------------------------------
	}
	//-----------------------------------------------------------
}
//--------------------------------------------------------------------------------
compareNull :: proc(name: string, actual: $T, loc := #caller_location) {
	//-----------------------------------------------------------
	if actual == nil {
		//----------------------------------------
		if options.show_passes {
			printPass(loc)
			printfln(": %s", name)
			printLine()
		}
		//----------------------------------------
		count_passed += 1
		//----------------------------------------
	} else {
		//----------------------------------------
		printFail(loc); printfln(":     %s", name)
		//----------------------------------------
		printActual(); printfln(":   %v", actual)
		//----------------------------------------
		printExpected(); println(": nil")
		//----------------------------------------
		printLine()
		//----------------------------------------
		count_failed += 1
		//----------------------------------------
	}
	//-----------------------------------------------------------
}
//--------------------------------------------------------------------------------
compareEnum :: proc(name: string, actual: $T, expected: T, loc := #caller_location) {
	//-----------------------------------------------------------
	if actual == expected {
		//----------------------------------------
		if options.show_passes {
			printPass(loc)
			printfln(": %s", name)
			printLine()
		}
		//----------------------------------------
		count_passed += 1
		//----------------------------------------
	} else {
		//----------------------------------------
		printFail(loc); printfln(":     %s", name)
		//----------------------------------------
		printActual(); printfln(":   %v", actual)
		//----------------------------------------
		printExpected(); printfln(": %v", expected)
		//----------------------------------------
		printLine()
		//----------------------------------------
		count_failed += 1
		//----------------------------------------
	}
	//-----------------------------------------------------------
}
//--------------------------------------------------------------------------------
compareError :: proc(name: string, actual: $T, expected: T, loc := #caller_location) {
	//-----------------------------------------------------------
	if actual == expected {
		//----------------------------------------
		if options.show_passes {
			printPass(loc)
			printfln(": %s", name)
			printLine()
		}
		//----------------------------------------
		count_passed += 1
		//----------------------------------------
	} else {
		//----------------------------------------
		printFail(loc); printfln(":     %s", name)
		//----------------------------------------
		printActual(); printfln(":   %v", actual)
		//----------------------------------------
		printExpected(); printfln(": %v", expected)
		//----------------------------------------
		printLine()
		//----------------------------------------
		count_failed += 1
		//----------------------------------------
	}
	//-----------------------------------------------------------
}
//--------------------------------------------------------------------------------
test :: proc(name: string, condition: bool, loc := #caller_location) {
	//-----------------------------------------------------------
	if condition {
		//----------------------------------------
		if options.show_passes {
			printPass(loc)
			printfln(": %s", name)
			printLine()
		}
		//----------------------------------------
		count_passed += 1
		//----------------------------------------
	} else {
		//----------------------------------------
		printFail(loc); printfln(":     %s", name)
		//----------------------------------------
		printActual(); printfln(":   %v", condition)
		//----------------------------------------
		printExpected(); println(": true")
		//----------------------------------------
		printLine()
		//----------------------------------------
		count_failed += 1
		//----------------------------------------
	}
	//-----------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
ptrToBytes :: proc(ptr: [^]byte, #any_int len: int) -> []byte {return ptr[:len]}
rawptrToBytes :: proc(ptr: rawptr, #any_int len: int) -> []byte {return (cast([^]byte)ptr)[:len]}
//--------------------------------------------------------------------------------
bytesToString :: proc {
	bytesSliceToString,
	ptrToString,
	rawptrToString,
}
bytesSliceToString :: proc(b: []byte) -> string {
	return string(b)
}
ptrToString :: proc(ptr: ^[]byte, #any_int len: int) -> string {
	return ptr == nil ? "" : string(ptr[:len])
}
rawptrToString :: proc(ptr: rawptr, #any_int len: int) -> string {
	return ptr == nil ? "" : string((cast([^]byte)ptr)[:len])
}
//--------------------------------------------------------------------------------
bytesToCString :: proc {
	bytesSliceToCString,
	ptrToCString,
	rawptrToCString,
}
bytesSliceToCString :: proc(b: []byte) -> cstring {
	if len(b) == 0 do return nil
	b[len(b) - 1] = 0 // force last byte to be zero incase not properly null terminated
	return cstring(&b[0])
}
ptrToCString :: proc(ptr: ^byte) -> cstring {
	return ptr == nil ? nil : cstring(ptr)
}
rawptrToCString :: proc(ptr: rawptr) -> cstring {
	return ptr == nil ? nil : cstring(ptr)
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
newOptionsReflect :: proc(options: OptionsUnion) -> (OptionsResult, UnittestError) {
	//------------------------------------------------------------
	optionsResult := default_options
	//------------------------------------------------------------
	id := typeid_of(OptionsUnion)
	count := reflect.struct_field_count(id)
	//------------------------------------------------------------
	for index := 0; index < count; index += 1 {
		//------------------------------------------------------------
		field := reflect.struct_field_at(id, index)
		value := reflect.struct_field_value(options, field)
		//------------------------------------------------------------
		if reflect.is_nil(value) {continue}
		//------------------------------------------------------------
		err := setOptionsValue(&optionsResult, field.name, value)
		if err != nil {return optionsResult, err}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	return optionsResult, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
setOptionsValue :: proc(structInstance: ^$T, field_name: string, value: any) -> UnittestError {
	//------------------------------------------------------------
	struct_field := reflect.struct_field_by_name(typeid_of(T), field_name)
	//------------------------------------------------------------
	if struct_field.type == nil {return .InvalidStructType}
	//------------------------------------------------------------
	if value == nil || value.data == nil {return .InvalidValue}
	//------------------------------------------------------------
	struct_field_ptr := rawptr(uintptr(structInstance) + struct_field.offset)
	//------------------------------------------------------------
	mem.copy(struct_field_ptr, value.data, struct_field.type.size)
	//------------------------------------------------------------
	return nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
printSummary :: proc() {
	//-----------------------------------------------------------
	printf("PASSED = %d", count_passed)
	//-----------------------------------------------------------
	if count_failed > 0 {printf(", FAILED = %d", count_failed)}
	//-----------------------------------------------------------
	if (start_time_ns > 0) {
		//-----------------------------------
		duration_ns := time.time_to_unix_nano(time.now()) - start_time_ns
		duration_ms := duration_ns / 1_000_000
		//-----------------------------------
		printfln(" (%d ms)", duration_ms)
		//-----------------------------------
	}
	//-----------------------------------------------------------
	printLine()
	//-----------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
main :: proc() {
	//-----------------------------------------------------------
	init()
	//-----------------------------------------------------------
	compareTypeID("compareTypeID pass", i64, i64)
	compareTypeID("compareTypeID fail", i32, i64)

	compareString("compareString pass", "foo", "foo")
	compareString("compareString fail", "bar", "foo")

	compareCString("compareCString pass", "foo", "foo")
	compareCString("compareCString fail", "bar", "foo")

	compareBytes("compareBytes pass", []byte{'f', 'o', 'o'}, []byte{'f', 'o', 'o'})
	compareBytes("compareBytes fail", []byte{'b', 'a', 'r'}, []byte{'f', 'o', 'o'})

	compareByte("compareByte pass", 42, 42)
	compareByte("compareByte fail", 0, 42)

	compareEnum("compareEnum pass", ChannelError.SendSignalError, ChannelError.SendSignalError)
	compareEnum("compareEnum fail", ChannelError.None, ChannelError.SendSignalError)

	compareInteger("compareInteger pass", -42, -42)
	compareInteger("compareInteger fail", 0, -42)

	compareFloat("compareFloat pass", 42.42, 42.42)
	compareFloat("compareFloat fail", 0, 42.42)

	compareBool("compareBool pass", true, true)
	compareBool("compareBool fail", false, true)

	null: rawptr; compareNull("compareNull pass", null)
	null_int := 42; null = &null_int; compareNull("compareNull fail", null)

	err := ChannelError.None; compareError("compareError pass", err, nil)
	err = nil; compareError("compareError pass", err, nil)
	compareError("compareError pass", ChannelError.SendSignalError, ChannelError.SendSignalError)

	compareError("compareError fail", err, ChannelError.SendSignalError)
	err = ChannelError.SendSignalError; compareError("compareError fail", err, nil)
	compareError(
		"compareError fail",
		ChannelError.ReceiveSignalError,
		ChannelError.SendSignalError,
	)

	test("test pass", 42 == 42)
	test("test fail", 0 == 42)
	//------------------------------------------------------------
	printSummary()
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
