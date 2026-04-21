package main

//------------------------------------------------------------
// Copyright 2025 Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//------------------------------------------------------------

import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:reflect"

//------------------------------------------------------------

Error :: union {
	ReflectError,
}

ReflectError :: enum {
	InvalidStructType,
	InvalidStructInstance,
	InvalidStructField,
	InvalidValue,
	InvalidValueType,
}

//------------------------------------------------------------

OptionsUnion :: struct {
	encoding:  union {
		string,
	},
	mix_chars: union {
		bool,
	},
}

OptionsResult :: struct {
	encoding:  string,
	mix_chars: bool,
}

default_options := OptionsResult {
	encoding  = "",
	mix_chars = true,
}

newOptions :: proc(options: OptionsUnion) -> OptionsResult {
	return OptionsResult {
		encoding = options.encoding != nil ? options.encoding.? : default_options.encoding,
		mix_chars = options.mix_chars != nil ? options.mix_chars.? : default_options.mix_chars,
	}
}

newOptionsReflect :: proc(options: OptionsUnion) -> (OptionsResult, Error) {

	optionsResult := default_options

	id := typeid_of(OptionsUnion)
	count := reflect.struct_field_count(id)

	for index := 0; index < count; index += 1 {
		field := reflect.struct_field_at(id, index)
		value := reflect.struct_field_value(options, field)

		if reflect.is_nil(value) {continue}

		err := struct_field_set_value(OptionsResult, &optionsResult, field.name, value)

		if err != nil {return optionsResult, err}
	}

	return optionsResult, nil
}

//--------------------------------------------

main :: proc() {
	//---------------------------------------
	fmt.printfln("%s: main function", filepath.base(os.args[0]))
	//---------------------------------------
}

//------------------------------------------------------------

@(require_results)
struct_field_set_value :: proc(
	$T: typeid,
	structInstance: ^T,
	field_name: string,
	value: any,
) -> Error {
	//----------------------------------------
	struct_field := reflect.struct_field_by_name(typeid_of(T), field_name)
	//----------------------------------------
	if struct_field.type == nil {return .InvalidStructType}
	//----------------------------------------
	if value == nil || value.data == nil {return .InvalidValue}
	//----------------------------------------
	struct_field_ptr := rawptr(uintptr(structInstance) + struct_field.offset)
	//----------------------------------------
	mem.copy(struct_field_ptr, value.data, struct_field.type.size)
	//----------------------------------------
	return nil
	//----------------------------------------
}

//------------------------------------------------------------
