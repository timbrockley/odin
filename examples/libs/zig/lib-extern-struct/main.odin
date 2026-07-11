package main

import "core:fmt"
import "core:strings"

//--------------------------------------------------------------------------------
// extern definitions
//--------------------------------------------------------------------------------

ExampleEnum :: enum u8 {
	no  = 0,
	yes = 1,
}

ExampleRawString :: struct {
	ptr: [^]u8,
	len: uintptr,
}

Self :: struct {
	example_byte:       u8,
	example_enum:       ExampleEnum,
	example_raw_string: ExampleRawString,
}

//--------------------------------------------------------------------------------
// extern functions
//--------------------------------------------------------------------------------

foreign import lib "libextern.so"
foreign lib {
	//----------------------------------------
	setByte :: proc(self: ^Self, byte_value: u8) -> bool ---
	getByte :: proc(self: ^Self) -> u8 ---
	setEnum :: proc(self: ^Self, enum_value: ExampleEnum) -> bool ---
	getEnum :: proc(self: ^Self) -> ExampleEnum ---
	setRawString :: proc(self: ^Self, raw_string: ExampleRawString) -> bool ---
	getRawString :: proc(self: ^Self) -> ExampleRawString ---
	//----------------------------------------
}

//--------------------------------------------------------------------------------
// wrapper functions
//--------------------------------------------------------------------------------

setString :: proc(self: ^Self, raw_string: string) -> bool {
	return setRawString(
		self,
		ExampleRawString{ptr = raw_data(raw_string), len = uintptr(len(raw_string))},
	)
}

//----------------------------------------

getString :: proc(self: ^Self) -> string {
	raw := getRawString(self)
	return string(raw.ptr[:raw.len])
}

//--------------------------------------------------------------------------------
// main
//--------------------------------------------------------------------------------

main :: proc() {
	//--------------------------------------------------------------------------------

	self := Self {
		example_byte = 0,
		example_enum = .no,
		example_raw_string = ExampleRawString{ptr = nil, len = 0},
	}

	//--------------------------------------------------------------------------------
	{
		//----------------------------------------
		self_byte := getByte(&self)
		test_byte := self_byte == 0

		fmt.printf("(%v) self_byte = %v\n", test_byte, self_byte)

		//----------------------------------------

		self_enum := getEnum(&self)
		test_enum := self_enum == .no

		fmt.printf("(%v) self_enum = %v\n", test_enum, self_enum)

		//----------------------------------------

		new_string := getString(&self)
		test_string := "" == new_string

		fmt.printf("(%v) new_string = \"%s\"\n", test_string, new_string)

		fmt.println()

		//----------------------------------------
	}

	//--------------------------------------------------------------------------------
	{
		//----------------------------------------

		_ = setByte(&self, 1)

		//----------------------------------------

		self_byte := getByte(&self)
		test_byte := self_byte == 1

		fmt.printf("(%v) self_byte = %v\n", test_byte, self_byte)

		//----------------------------------------

		_ = setEnum(&self, .yes)

		//----------------------------------------

		self_enum := getEnum(&self)
		test_enum := self_enum == .yes

		fmt.printf("(%v) self_enum = %v\n", test_enum, self_enum)

		//----------------------------------------

		_ = setString(&self, "new_string")

		//----------------------------------------

		new_string := getString(&self)
		test_string := new_string == "new_string"

		fmt.printf("(%v) new_string = \"%s\"\n", test_string, new_string)

		fmt.println()

		//----------------------------------------
	}

	//--------------------------------------------------------------------------------
}
