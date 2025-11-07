package main

//------------------------------------------------------------

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
	err = struct_field_set_value(OptionsResult, &optionsResult, "encoding", "base64")
	//----------------------------------------
	testing.expect_value(t, optionsResult.encoding, "base64")
	testing.expect_value(t, err, nil)
	//----------------------------------------
	err = struct_field_set_value(OptionsResult, &optionsResult, "mix_chars", true)
	//----------------------------------------
	testing.expect_value(t, optionsResult.mix_chars, true)
	testing.expect_value(t, err, nil)
	//------------------------------------------------------------
}


//------------------------------------------------------------
