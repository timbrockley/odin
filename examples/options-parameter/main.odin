package main

//------------------------------------------------------------
// Copyright 2025 Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//------------------------------------------------------------

import "core:fmt"
import "core:os"
import "core:path/filepath"

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

//--------------------------------------------
main :: proc() {
	//---------------------------------------
	fmt.printfln("%s: main function", filepath.base(os.args[0]))
	//---------------------------------------
}
//------------------------------------------------------------
