package main

//------------------------------------------------------------
// Copyright 2025 Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//------------------------------------------------------------

import "core:fmt"
import "core:mem"
import os "core:os/os2"
import "core:strings"

//------------------------------------------------------------

PS_SEARCH_PATH :: "/sys/class/power_supply"

PowerStatus :: enum {
	Unknown,
	Mains,
	Battery,
}

Error :: union {
	PowerCheckError,
	os.Error,
	mem.Allocator_Error,
}

PowerCheckError :: enum {
	FilePathNotFound,
	ReadError,
	PowerStatusUnknown,
	ProcessNotFound,
	InvalidExitCode,
	GetSystemPowerStatusError,
}

//------------------------------------------------------------

main :: proc() {
	//----------------------------------------
	allocator := context.allocator
	//----------------------------------------
	power_status: PowerStatus
	err: Error
	//----------------------------------------
	when ODIN_OS == .Linux {
		power_status, err = powerCheckLinux(allocator)
	} else when ODIN_OS == .Darwin {
		power_status, err = powerCheckMacOS(allocator)
	} else when ODIN_OS == .Windows {
		power_status, err = powerCheckWindows()
	} else {
		fmt.eprint("Unsupported OS\n")
		os.exit(1)
	}
	//----------------------------------------
	if err != nil {fmt.eprintln(err); os.exit(1)}
	//----------------------------------------
	if (len(os.args) > 1) {
		switch os.args[1] {
		case "mains":
			os.exit(power_status == .Mains ? 0 : 1)
		case "battery":
			os.exit(power_status == .Battery ? 0 : 1)
		case:
			fmt.eprint("invalid arguments\n")
			os.exit(1)
		}
	}
	//----------------------------------------
	if (power_status == .Mains) {
		fmt.print("power supply: mains power\n")
	} else if (power_status == .Battery) {
		fmt.print("power supply: battery power\n")
	} else {
		fmt.print("power supply: unknown source\n")
	}
	//----------------------------------------
}

//------------------------------------------------------------
// linux functions
//------------------------------------------------------------

powerCheckLinux :: proc(allocator: mem.Allocator) -> (PowerStatus, Error) {
	//----------------------------------------
	power_status, err := powerCheckFilePath(allocator)
	if err == nil {return power_status, nil} else {return powerCheck_upower(allocator)}
	//----------------------------------------
}

powerCheckFilePath :: proc(allocator: mem.Allocator) -> (PowerStatus, Error) {
	//----------------------------------------
	file_path, file_err := findPSFilePath(allocator)
	if file_err != nil {return .Unknown, file_err}
	//----------------------------------------
	handle, handle_err := os.open(file_path, os.O_RDONLY)
	if handle_err != nil {return .Unknown, handle_err} else {
		//----------------------------------------
		defer os.close(handle)
		//----------------------------------------
		buffer: [1]u8
		bytes_read, read_err := os.read(handle, buffer[:])
		if read_err != nil {return .Unknown, read_err} else {
			if bytes_read == 0 {return .Unknown, .ReadError}
			return buffer[0] == '1' ? .Mains : .Battery, nil
		}
		//----------------------------------------
	}
	//----------------------------------------
	return .Unknown, .PowerStatusUnknown
	//----------------------------------------
}

findPSFilePath :: proc(allocator: mem.Allocator) -> (string, Error) {
	//----------------------------------------
	handle, err := os.open(PS_SEARCH_PATH)
	if err != nil {return "", err} else {
		//----------------------------------------
		defer os.close(handle)
		//----------------------------------------
		dir_entries, err := os.read_dir(handle, -1, allocator)
		if err != nil {return "", err}
		//----------------------------------------
		for dir_entry in dir_entries {
			if strings.has_prefix(dir_entry.name, "AC") {
				return fmt.aprintf(
						"%s/%s/online",
						PS_SEARCH_PATH,
						dir_entry.name,
						allocator = allocator,
					),
					nil
			}
		}
		//----------------------------------------
	}
	//----------------------------------------
	return "", .FilePathNotFound
	//----------------------------------------
}

powerCheck_upower :: proc(allocator: mem.Allocator) -> (PowerStatus, Error) {
	//----------------------------------------
	stdout, err := ProcessExec(allocator, {"upower", "--dump"})
	if err != nil {return .Unknown, err}
	//----------------------------------------
	defer delete(stdout, allocator)
	//----------------------------------------
	using_battery := false
	line_matched := false

	lines := strings.split(stdout, "\n", allocator)
	defer delete(lines, allocator)

	for line in lines {
		if strings.index(line, "on-battery:") != -1 {
			using_battery = strings.index(line, "yes") != -1
			line_matched = true
			break
		}
	}

	if !line_matched {return .Unknown, .PowerStatusUnknown}

	return !using_battery ? .Mains : .Battery, nil
	//----------------------------------------
}

//------------------------------------------------------------
// macos functions
//------------------------------------------------------------

powerCheckMacOS :: proc(allocator: mem.Allocator) -> (PowerStatus, Error) {
	//----------------------------------------
	return powerCheck_pmset(allocator)
	//----------------------------------------
}

powerCheck_pmset :: proc(allocator: mem.Allocator) -> (PowerStatus, Error) {
	//----------------------------------------
	stdout, err := ProcessExec(allocator, {"pmset", "-g", "batt"})
	if err != nil {return .Unknown, err}
	//----------------------------------------
	defer delete(stdout, allocator)
	//----------------------------------------
	using_battery := false
	line_matched := false

	lines := strings.split(stdout, "\n", allocator)
	defer delete(lines, allocator)

	for line in lines {
		if strings.index(line, "Now drawing") != -1 {
			using_battery = strings.index(line, "Battery Power") != -1
			line_matched = true
			break
		}
	}

	if !line_matched {return .Unknown, .PowerStatusUnknown}

	return !using_battery ? .Mains : .Battery, nil
	//----------------------------------------
}

//------------------------------------------------------------
// linux and macos functions
//------------------------------------------------------------

ProcessExec :: proc(allocator: mem.Allocator, command: []string) -> (string, Error) {
	//----------------------------------------
	state, stdout, stderr, err := os.process_exec(
		{command = command, stdout = nil, stderr = nil},
		allocator,
	)
	if err != nil {
		if err == .Not_Exist {return "", .ProcessNotFound} else {return "", err}
	}
	//----------------------------------------
	defer delete(stdout, allocator)
	defer delete(stderr, allocator)
	//----------------------------------------
	if len(stderr) > 0 {fmt.eprint(string(stderr))}
	if (state.exit_code > 0) {return "", .InvalidExitCode}
	//----------------------------------------
	return strings.clone(string(stdout), allocator), nil
	//----------------------------------------
}

//------------------------------------------------------------
// windows functions
//------------------------------------------------------------

import "core:sys/windows"

//------------------------------------------------------------
when ODIN_OS == .Windows {
	//----------------------------------------
	powerCheckWindows :: proc() -> (PowerStatus, Error) {
		//----------------------------------------
		status: windows.SYSTEM_POWER_STATUS
		//----------------------------------------
		if windows.GetSystemPowerStatus(&status) == windows.FALSE {
			return .Unknown, .GetSystemPowerStatusError
		}
		//----------------------------------------
		return status.ACLineStatus == .Online ? .Mains : .Battery, nil
		//----------------------------------------
	}
	//----------------------------------------
}
//------------------------------------------------------------
