#+feature global-context

package main

import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"
import "core:strings"
import "core:testing"

// arena: vmem.Arena
// allocator := vmem.arena_allocator(&arena)

allocator: mem.Allocator

//------------------------------------------------------------
// init / deinit functions
//------------------------------------------------------------

@(init)
init_test :: proc() {
	//----------------------------------------
	allocator = context.allocator
	//----------------------------------------
}

// @(fini)
// deinit_test :: proc() {vmem.arena_destroy(&arena)}

//------------------------------------------------------------
// linux functions
//------------------------------------------------------------

when ODIN_OS != .Windows {

	@(test)
	powerCheckLinux_test :: proc(t: ^testing.T) {
		//----------------------------------------
		power_status, err := powerCheckLinux(allocator)
		//----------------------------------------
		if err != nil {
			testing.expect_value(t, power_status, PowerStatus.Unknown)
			testing.expect_value(t, err, PowerCheckError.PowerStatusUnknown)
		} else {
			testing.expect(
				t,
				power_status == PowerStatus.Battery || power_status == PowerStatus.Mains,
			)
		}
		//----------------------------------------
	}

	@(test)
	powerCheckFilePath_test :: proc(t: ^testing.T) {
		//----------------------------------------
		power_status, err := powerCheckFilePath(allocator)
		//----------------------------------------
		if err != nil {
			testing.expect_value(t, power_status, PowerStatus.Unknown)
			testing.expect_value(t, err, PowerCheckError.PowerStatusUnknown)
		} else {
			testing.expect(
				t,
				power_status == PowerStatus.Battery || power_status == PowerStatus.Mains,
			)
		}
		//----------------------------------------
	}

	@(test)
	findPSFilePath_test :: proc(t: ^testing.T) {
		//----------------------------------------
		file_path, err := findPSFilePath(allocator)
		//----------------------------------------
		if err != nil {
			testing.expect_value(t, file_path, "")
			testing.expect_value(t, err, PowerCheckError.FilePathNotFound)
		} else {
			testing.expect(t, strings.has_prefix(file_path, PS_SEARCH_PATH))
			testing.expect(t, len(file_path) > len(PS_SEARCH_PATH))
		}
		//----------------------------------------
	}

	@(test)
	powerCheck_upower_test :: proc(t: ^testing.T) {
		//----------------------------------------
		power_status, err := powerCheck_upower(allocator)
		//----------------------------------------
		if err != nil {
			testing.expect_value(t, power_status, PowerStatus.Unknown)
			testing.expect_value(t, err, PowerCheckError.PowerStatusUnknown)
		} else {
			testing.expect(
				t,
				power_status == PowerStatus.Battery || power_status == PowerStatus.Mains,
			)
		}
		//----------------------------------------
	}

	//------------------------------------------------------------
	// macos functions
	//------------------------------------------------------------

	@(test)
	powerCheckMacOS_test :: proc(t: ^testing.T) {
		//----------------------------------------
		power_status, err := powerCheckMacOS(allocator)
		//----------------------------------------
		if err != nil {
			testing.expect_value(t, power_status, PowerStatus.Unknown)
			testing.expect_value(t, err, PowerCheckError.PowerStatusUnknown)
		} else {
			testing.expect(
				t,
				power_status == PowerStatus.Battery || power_status == PowerStatus.Mains,
			)
		}
		//----------------------------------------
	}

	@(test)
	powerCheck_pmset_test :: proc(t: ^testing.T) {
		//----------------------------------------
		power_status, err := powerCheck_pmset(allocator)
		//----------------------------------------
		if err != nil {
			testing.expect_value(t, power_status, PowerStatus.Unknown)
			testing.expect_value(t, err, PowerCheckError.PowerStatusUnknown)
		} else {
			testing.expect(
				t,
				power_status == PowerStatus.Battery || power_status == PowerStatus.Mains,
			)
		}
		//----------------------------------------
	}

}

//------------------------------------------------------------
// windows functions
//------------------------------------------------------------

when ODIN_OS == .Windows {
	//----------------------------------------
	@(test)
	powerCheckWindows_test :: proc(t: ^testing.T) {
		//----------------------------------------
		power_status, err := powerCheckWindows()
		//----------------------------------------
		if err != nil {
			testing.expect_value(t, power_status, PowerStatus.Unknown)
			testing.expect_value(t, err, PowerCheckError.PowerStatusUnknown)
		} else {
			testing.expect(
				t,
				power_status == PowerStatus.Battery || power_status == PowerStatus.Mains,
			)
		}
		//----------------------------------------
	}
	//----------------------------------------
}

//------------------------------------------------------------
