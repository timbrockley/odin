package main

// Copyright 2025, Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.

import "core:fmt"
import os "core:os/os2"
import "core:strings"

//------------------------------------------------------------

process_start :: proc(
	command: []string,
) -> (
	exitCode: int,
	stdOutput: string,
	stdError: string,
	error: os.Error,
) {
	r_out, w_out := os.pipe() or_return
	defer os.close(r_out)

	r_err, w_err := os.pipe() or_return
	defer os.close(r_err)

	processHandle := os.process_start(
		{command = command, stdout = w_out, stderr = w_err},
	) or_return

	os.close(w_out)
	os.close(w_err)

	stdout_bytes := os.read_entire_file(r_out, context.temp_allocator) or_return
	stderr_bytes := os.read_entire_file(r_err, context.temp_allocator) or_return

	processState := os.process_wait(processHandle) or_return

	return processState.exit_code, string(stdout_bytes), string(stderr_bytes), nil
}


//------------------------------------------------------------

main :: proc() {
	//----------------------------------------
	exitCode, stdOutput, stdError, err := process_start({"upower", "--dump"})
	//----------------------------------------
	if err != nil {
		fmt.eprintf("process error: %s\n", err)
		os.exit(1)
	}
	//----------------------------------------
	if len(stdError) > 0 {
		fmt.eprint(stdError)
	}
	//----------------------------------------
	if (exitCode > 0) {
		fmt.eprintf("invalid exit code: %d\n", exitCode)
		os.exit(exitCode)
	}
	//----------------------------------------
	usingBattery := false
	lineMatched := false

	lines := strings.split(stdOutput, "\n")

	for line in lines {
		if strings.index(line, "on-battery:") != -1 {
			usingBattery = strings.index(line, "yes") != -1
			lineMatched = true
			break
		}
	}

	if !lineMatched {
		fmt.eprint("unable to check power supply status\n")
		os.exit(1)
	}
	//----------------------------------------
	if (len(os.args) > 1) {
		switch os.args[1] {
		case "battery":
			os.exit(usingBattery ? 0 : 1)
		case "mains":
			os.exit(!usingBattery ? 0 : 1)
		case:
			fmt.eprint("invalid arguments\n")
			os.exit(1)
		}
	}
	//----------------------------------------
	if (usingBattery) {
		fmt.print("power supply: battery power\n")
	} else {
		fmt.print("power supply: mains power\n")
	}
	//----------------------------------------
}

//------------------------------------------------------------
