package main

//------------------------------------------------------------
// Copyright 2026 Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//------------------------------------------------------------

import "core:fmt"
import "core:os/os2"

//------------------------------------------------------------

TEST_DIR :: "test"

//------------------------------------------------------------

main :: proc() {
	//----------------------------------------
	{
		// get full path of current working directory

		full_path, err := os2.get_working_directory(context.allocator)
		if err != nil {
			fmt.eprintf("error creating file: %v\n\n", err)
		}

		fmt.printf("\nget_working_directory: %s\n\n", full_path)
	}
	//----------------------------------------
	{
		// if file of same name as test dir then remove it
		if !os2.is_directory(TEST_DIR) {_ = os2.remove(TEST_DIR)}

		// create test dir
		_ = os2.make_directory_all(TEST_DIR, 0o700)
	}
	//----------------------------------------
	{
		// write to file

		test_data :: "test data"

		handle, err := os2.open(
			fmt.tprintf("%s/test.txt", TEST_DIR),
			os2.O_CREATE | os2.O_WRONLY,
			os2.perm_number(0o700),
		)
		if err != nil {
			fmt.eprintf("error creating file: %v\n\n", err)
		} else {

			defer os2.close(handle)

			bytes_written, write_err := os2.write_string(handle, test_data)
			if write_err != nil {
				fmt.eprintf("error writing to file: %v\n\n", write_err)
			}
		}
	}
	//----------------------------------------
	{
		// read from file

		handle, err := os2.open(fmt.tprintf("%s/test.txt", TEST_DIR), os2.O_RDONLY)
		if err != nil {
			fmt.eprintf("error opening file: %v\n\n", err)
		} else {

			defer os2.close(handle)

			size, size_err := os2.file_size(handle)
			if size_err != nil {
				fmt.println("size_error:", size_err)
			} else {
				fmt.println("size:", size)
			}

			buffer: [100]u8
			bytes_read, read_err := os2.read(handle, buffer[:])
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
		// open current dir and list file details

		handle, err := os2.open(".")
		if err != nil {
			printError(err)
		} else {

			defer os2.close(handle)

			// list dir entries

			dir_entries, err := os2.read_directory(handle, -1, context.allocator)
			if err != nil {printError(err)}
			for dir_entry in dir_entries {
				fmt.printf(
					"%v: name: %s (%s)\n",
					dir_entry.type,
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
	os2.exit(1)
}

//------------------------------------------------------------
