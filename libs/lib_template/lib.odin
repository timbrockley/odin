package lib

//------------------------------------------------------------
// Copyright Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//------------------------------------------------------------

import "core:fmt"
import "core:os"
import "core:path/filepath"

Error :: union #shared_nil {
	LibError,
}

LibError :: enum {
	None,
	InvalidInput,
}

//------------------------------------------------------------

add :: proc(a, b: int) -> (int, Error) {
	return a + b, nil
}

//------------------------------------------------------------

sub :: proc(a, b: int) -> (int, Error) {
	return a - b, nil
}

//------------------------------------------------------------

main :: proc() {
	//---------------------------------------
	fmt.printfln("%s: main function", filepath.base(os.args[0]))
	//---------------------------------------
}

//------------------------------------------------------------
