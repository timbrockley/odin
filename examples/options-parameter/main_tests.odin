package main

//------------------------------------------------------------

import "core:testing"

//------------------------------------------------------------

@(test)
test_main :: proc(t: ^testing.T) {
	//----------------------------------------
	options: OptionsResult
	//----------------------------------------
	options = newOptions({})
	testing.expect_value(t, options.encoding, "")
	testing.expect_value(t, options.mix_chars, true)
	//----------------------------------------
	options = newOptions({encoding = "base64"})
	testing.expect_value(t, options.encoding, "base64")
	testing.expect_value(t, options.mix_chars, true)
	//----------------------------------------
	options = newOptions({mix_chars = false})
	testing.expect_value(t, options.encoding, "")
	testing.expect_value(t, options.mix_chars, false)
	//----------------------------------------
	default_options.encoding = "base64"
	default_options.mix_chars = false
	//----------------------------------------
	options = newOptions({})
	testing.expect_value(t, options.encoding, "base64")
	testing.expect_value(t, options.mix_chars, false)
	//----------------------------------------
}


//------------------------------------------------------------
