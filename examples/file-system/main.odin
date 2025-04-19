package main

//------------------------------------------------------------
// Copyright 2025, Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//------------------------------------------------------------

import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"

//------------------------------------------------------------

TEST_DIR :: "test"

//------------------------------------------------------------

main :: proc() {
	//----------------------------------------
	{
		// get full path of current directory

		// full_path, ok := filepath.abs(".")
		// if !ok {printError("cwd: parse error")}

		full_path := os.get_current_directory()

		fmt.printf("\ncwd: %s\n\n", full_path)
	}
	//----------------------------------------
	{
		// if file of same name as test dir then remove it
		if !os.is_dir_path(TEST_DIR) {_ = os.remove(TEST_DIR)}

		// create test dir
		_ = os.make_directory(TEST_DIR)

	}
	//----------------------------------------
	{
		// write to file

		test_data :: "test data"

		handle, err := os.open(
			fmt.tprintf("%s/test.txt", TEST_DIR),
			os.O_CREATE | os.O_WRONLY,
			0o700,
		)
		if err != nil {
			fmt.eprintf("error creating file: %v\n\n", err)
		} else {

			defer os.close(handle)

			bytes_written, write_err := os.write_string(handle, test_data)
			if write_err != nil {
				fmt.eprintf("error writing to file: %v\n\n", write_err)
			}
		}

	}
	//----------------------------------------
	{
		// read from file

		handle, err := os.open(fmt.tprintf("%s/test.txt", TEST_DIR), os.O_RDONLY)
		if err != nil {
			fmt.eprintf("error opening file: %v\n\n", err)
		} else {

			defer os.close(handle)

			size, size_err := os.file_size(handle)
			if size_err != nil {
				fmt.println("size_error:", size_err)
			} else {
				fmt.println("size:", size)
			}

			buffer: [100]u8
			bytes_read, read_err := os.read(handle, buffer[:])
			if read_err != nil {
				fmt.eprintf("error reading from file: %v\n\n", read_err)
			} else {
				fmt.println("bytes_read:", bytes_read)
				fmt.println("buffer:", string(buffer[:bytes_read]))
			}
		}
		fmt.println()
	}
	//----------------------------------------
	{
		// open current dir

		handle, err := os.open(".")
		if err != nil {
			printError(err)
		} else {

			defer os.close(handle)

			// list dir entries

			dir_entries, err := os.read_dir(handle, -1)
			if err != nil {printError(err)}
			for dir_entry in dir_entries {
				fmt.printf(
					"is_dir: %v: name: %s (%s)\n",
					dir_entry.is_dir,
					dir_entry.name,
					dir_entry.fullpath,
				)
			}
			fmt.println()
		}
	}
	//----------------------------------------
}

//------------------------------------------------------------

printError :: proc(err: any) {
	fmt.eprintf("\n\n%v\n\n", err)
	os.exit(1)
}

//------------------------------------------------------------
