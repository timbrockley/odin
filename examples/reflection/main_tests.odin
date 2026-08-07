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


//------------------------------------------------------------
