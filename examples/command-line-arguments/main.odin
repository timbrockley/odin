package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:reflect"
import "core:strings"

//------------------------------------------------------------

Options :: struct {
	help:    bool `-h, --help, Show this help message`,
	version: bool `-v, --version, Show version information`,
	input:   string `-i, --input, Input file`,
	output:  string `-o, --output, Output file`,
}

Error :: enum {
	None,
	InvalidArgument,
}

ArgValue :: union {
	bool,
	string,
}

//------------------------------------------------------------

main :: proc() {
	//----------------------------------------
	options, options_map, arguments, err := processArguments()
	// defer delete(options_map) // optional as will be freed when out of scope
	// defer delete(arguments) // optional as will be freed when out of scope
	//----------------------------------------
	if err != .None {
		fmt.println("\nError:", err)
	}
	fmt.println("\nProcessed Options Map =", options_map)
	fmt.println("\nProcessed Options Struct = ", options)
	fmt.println("\nProcessed Arguments = ", arguments)
	//----------------------------------------
	printHelp()
	//----------------------------------------
}

//------------------------------------------------------------

processArguments :: proc(
) -> (
	options: Options,
	options_map: map[string]ArgValue,
	arguments: [dynamic]string,
	err: Error,
) {
	//----------------------------------------
	arguments = make([dynamic]string, 0, 0)
	//----------------------------------------
	options_map = map[string]ArgValue{}
	//----------------------------------------
	for arg in os.args[1:] {
		//--------------------
		if strings.index(arg, "-") == 0 {
			//--------------------
			index := strings.index(arg, ":")
			//--------------------
			if index == -1 || arg == ":" {
				options_map[arg] = true
			} else {
				argSplit := strings.split(arg, ":")
				// defer delete(argSplit) // optional as will be freed when out of scope
				//--------------------
				key := index == 0 ? ":" : argSplit[0]
				value := argSplit[1]
				options_map[key] = value
				//--------------------
			}
			//--------------------
		} else {
			//--------------------
			append(&arguments, arg)
			//--------------------
		}
		//----------------------------------------
	}
	//----------------------------------------
	options = Options{}
	err = .None
	//----------------------------------------
	for key, value in options_map {
		//--------------------
		switch _ in value {
		case bool:
			switch key {
			case "-h", "-help", "--help":
				options.help = true
			case "-v", "-version", "--version":
				options.version = true
			case:
				err = .InvalidArgument // may happen more than once but ok for intended purpose
			}
		case string:
			switch key {
			case "-i", "-input", "--input":
				options.input = value.(string)
			case "-o", "-output", "--output":
				options.output = value.(string)
			case:
				err = .InvalidArgument // may happen more than once but ok for intended purpose
			}
		}
		//--------------------
	}
	//----------------------------------------
	return options, options_map, arguments, err
	//----------------------------------------
}

//------------------------------------------------------------

printHelp :: proc() {
	fmt.println()
	fmt.printfln("Usage: %s [options] arguments...", filepath.base(os.args[0]))
	fmt.println()
	fmt.println("Options:")
	for i in 0 ..< reflect.struct_field_count(Options) {
		fmt.printfln("  %s", reflect.struct_field_at(Options, i).tag)
	}
	fmt.println()
}

//------------------------------------------------------------
