package main

//------------------------------------------------------------
// Copyright 2025 Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//------------------------------------------------------------

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:time"

//------------------------------------------------------------
DURATION :: 1 * time.Second
CR_CLEARLINE :: "\r\x1b[2K"
//------------------------------------------------------------
main :: proc() {
	//----------------------------------------
	countdown: int
	ok: bool
	//----------------------------------------
	if len(os.args) > 1 {
		//----------------------------------------
		if countdown, ok = strconv.parse_int(os.args[1], 10); ok == false {
			return
		}
		//----------------------------------------
		message: string
		if len(os.args) > 2 {
			message = os.args[2]
		} else {
			message = "Countdown"
		}
		//----------------------------------------
		for countdown > 0 {
			fmt.printf("%s%s...%d", CR_CLEARLINE, message, countdown)
			countdown -= 1
			time.sleep(DURATION)
		}
		//----------------------------------------
	}
	//----------------------------------------
	fmt.printf("%s", CR_CLEARLINE)
	//----------------------------------------
}
//------------------------------------------------------------
