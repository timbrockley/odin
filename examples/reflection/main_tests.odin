package main

//------------------------------------------------------------

import "core:reflect"
import "core:testing"

//------------------------------------------------------------

@(test)
test_main :: proc(t: ^testing.T) {
	//------------------------------------------------------------
	err: Error
	//----------------------------------------
	OptionsResult :: struct {
		encoding:  string,
		mix_chars: bool,
	}
	//----------------------------------------
	optionsResult := OptionsResult{}
	//----------------------------------------
	testing.expect_value(t, optionsResult.encoding, "")
	testing.expect_value(t, optionsResult.mix_chars, false)
	//----------------------------------------
	err = setStructFieldValue(&optionsResult, "encoding", "base64")
	//----------------------------------------
	testing.expect_value(t, optionsResult.encoding, "base64")
	testing.expect_value(t, err, nil)
	//----------------------------------------
	err = setStructFieldValue(&optionsResult, "mix_chars", true)
	//----------------------------------------
	testing.expect_value(t, optionsResult.mix_chars, true)
	testing.expect_value(t, err, nil)
	//------------------------------------------------------------
}

@(test)
test_setStructField :: proc(t: ^testing.T) {
	//------------------------------------------------------------
	foo := Foo {
		x = 0,
	}

	id := typeid_of(Foo)
	field := reflect.struct_field_by_name(id, "x")

	err := setStructField(&foo, field, 42)

	testing.expect_value(t, foo.x, 42)
	testing.expect_value(t, err, nil)
	//------------------------------------------------------------
}

//------------------------------------------------------------
