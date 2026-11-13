package main

import "core:strings"
//------------------------------------------------------------

import "core:testing"

//------------------------------------------------------------

@(test)
test_options1 :: proc(t: ^testing.T) {
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
}

//------------------------------------------------------------

@(test)
test_options2 :: proc(t: ^testing.T) {
	//------------------------------------------------------------
	options: OptionsResult
	err: Error
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

@(test)
test_options3 :: proc(t: ^testing.T) {
	//------------------------------------------------------------
	{
		Options :: struct {
			encoding:  string,
			mix_chars: bool,
		}
		options: Options

		made_up_field := getOptionsValue(options, "made_up_field")
		encoding, _ := getOptionsValue(options, "encoding").(string)
		mix_chars, _ := getOptionsValue(options, "mix_chars").(bool)

		testing.expect(t, made_up_field == nil)
		testing.expect_value(t, encoding, "")
		testing.expect_value(t, mix_chars, false)

		options.encoding = "base64"
		options.mix_chars = true

		encoding, _ = getOptionsValue(options, "encoding").(string)
		mix_chars, _ = getOptionsValue(options, "mix_chars").(bool)

		testing.expect_value(t, encoding, "base64")
		testing.expect_value(t, mix_chars, true)
	}
	//------------------------------------------------------------
}

//------------------------------------------------------------
