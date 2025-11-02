package main

//------------------------------------------------------------

import "core:testing"

//------------------------------------------------------------

@(test)
test_main :: proc(t: ^testing.T) {
	//------------------------------------------------------------
	options: OptionsResult
	err: Error
	//------------------------------------------------------------
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
	//------------------------------------------------------------
	default_options.encoding = ""
	default_options.mix_chars = true
	//------------------------------------------------------------
	options, err = newOptionsReflect({})
	testing.expect_value(t, options.encoding, "")
	testing.expect_value(t, options.mix_chars, true)
	testing.expect_value(t, err, nil)
	//----------------------------------------
	options, err = newOptionsReflect({encoding = "base64"})
	testing.expect_value(t, options.encoding, "base64")
	testing.expect_value(t, options.mix_chars, true)
	testing.expect_value(t, err, nil)
	//----------------------------------------
	options, err = newOptionsReflect({mix_chars = false})
	testing.expect_value(t, options.encoding, "")
	testing.expect_value(t, options.mix_chars, false)
	testing.expect_value(t, err, nil)
	//----------------------------------------
	default_options.encoding = "base64"
	default_options.mix_chars = false
	//----------------------------------------
	options, err = newOptionsReflect({})
	testing.expect_value(t, options.encoding, "base64")
	testing.expect_value(t, options.mix_chars, false)
	testing.expect_value(t, err, nil)
	//------------------------------------------------------------
}


//------------------------------------------------------------
