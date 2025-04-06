package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:testing"

//------------------------------------------------------------

DAYS: [8]string = {
	"Invalid Index",
	"Monday",
	"Tuesday",
	"Wednesday",
	"Thursday",
	"Friday",
	"Saturday",
	"Sunday",
}

//------------------------------------------------------------

safe_array_value :: proc(array: [$N]$T, index := int(0)) -> T {
	return index >= 0 && index < N ? array[index] : T{}
}

@(test)
safe_array_value_test :: proc(t: ^testing.T) {
	testing.expect_value(t, safe_array_value(DAYS), "Invalid Index")
	testing.expect_value(t, safe_array_value(DAYS, 0), "Invalid Index")
	testing.expect_value(t, safe_array_value(DAYS, 1), "Monday")
	testing.expect_value(t, safe_array_value(DAYS, 2), "Tuesday")
	testing.expect_value(t, safe_array_value(DAYS, 3), "Wednesday")
	testing.expect_value(t, safe_array_value(DAYS, 4), "Thursday")
	testing.expect_value(t, safe_array_value(DAYS, 5), "Friday")
	testing.expect_value(t, safe_array_value(DAYS, 6), "Saturday")
	testing.expect_value(t, safe_array_value(DAYS, 7), "Sunday")
	testing.expect_value(t, safe_array_value(DAYS, 8), "")
	testing.expect_value(t, safe_array_value(DAYS, 9999), "")
}

//------------------------------------------------------------

safe_slice_value :: proc(slice: []$T, index := int(0)) -> T {
	return index >= 0 && index < len(slice) ? slice[index] : T{}
}

@(test)
safe_slice_value_test :: proc(t: ^testing.T) {
	testing.expect_value(t, safe_slice_value(DAYS[:]), "Invalid Index")
	testing.expect_value(t, safe_slice_value(DAYS[:], 0), "Invalid Index")
	testing.expect_value(t, safe_slice_value(DAYS[:], 1), "Monday")
	testing.expect_value(t, safe_slice_value(DAYS[:], 2), "Tuesday")
	testing.expect_value(t, safe_slice_value(DAYS[:], 3), "Wednesday")
	testing.expect_value(t, safe_slice_value(DAYS[:], 4), "Thursday")
	testing.expect_value(t, safe_slice_value(DAYS[:], 5), "Friday")
	testing.expect_value(t, safe_slice_value(DAYS[:], 6), "Saturday")
	testing.expect_value(t, safe_slice_value(DAYS[:], 7), "Sunday")
	testing.expect_value(t, safe_slice_value(DAYS[:], 8), "")
	testing.expect_value(t, safe_slice_value(DAYS[:], 9999), "")
}

//------------------------------------------------------------

main :: proc() {
	fmt.printfln("%s: main function", filepath.base(os.args[0]))
}

//------------------------------------------------------------
