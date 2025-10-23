package main

import "core:fmt"
import "core:text/regex"
import "core:text/regex/common"

main :: proc() {
	// Define the pattern and the replacement string
	pattern: string = "world"
	replacement: string = "Odin"
	input: string = "Hello, World! and the second world and the third world"

	flags := regex.Flags{regex.Flag.Case_Insensitive}

	// Compile the regular expression
	re, err := regex.create(pattern, flags)
	if err != nil {
		fmt.println("Failed to compile regex:", err)
		return
	}

	// Perform the regex match and replace
	capture, success := regex.match_and_allocate_capture(re, input)
	if success {
		// output: string = input[:capture.pos[0][0]] + replacement + input[capture.pos[0][1]:]
		output: string = ""
		fmt.println("Original string:", input)
		fmt.println(capture)
	} else {
		fmt.println("No match found.")
	}

	// Clean up
	regex.destroy_regex(re)
}
