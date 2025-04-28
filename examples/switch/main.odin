#+feature dynamic-literals

package main

import "core:fmt"

main :: proc() {
	//----------------------------------------
	switch arch := ODIN_ARCH; arch {
	case .i386, .wasm32, .arm32:
		fmt.println("32 bit")
	case .amd64, .wasm64p32, .arm64, .riscv64:
		fmt.println("64 bit")
	case .Unknown:
		fmt.println("Unknown architecture")
	}
	//----------------------------------------
	#partial switch arch := ODIN_ARCH; arch {
	case .i386, .wasm32, .arm32:
		fmt.println("32 bit")
	case .amd64, .wasm64p32, .arm64, .riscv64:
		fmt.println("64 bit")
	case .Unknown:
		fmt.println("Unknown architecture")
	case:
		fmt.println("default case")
	}
	//----------------------------------------
	ArgValue :: union {
		bool,
		string,
	}
	optionsMap := map[string]ArgValue {
		"-a"        = true, // invalid
		"-h"        = true,
		"--help"    = true,
		"-v"        = true,
		"--version" = true,
		"-b"        = "true", // invalid
		"-i"        = "input.txt",
		"--input"   = "input.txt",
		"-o"        = "output.txt",
		"--output"  = "output.txt",
	}
	//----------------------------------------
	fmt.println()
	//----------------------------------------
	for key, value in optionsMap {
		//--------------------
		switch _ in value {
		case bool:
			switch key {
			case "-h", "-help", "--help":
				fmt.printfln("help: %v: %v", key, value)
			case "-v", "-version", "--version":
				fmt.printfln("version: %v: %v", key, value)
			case:
				fmt.printfln("invalid bool argument %v: %v", key, value)
			}
		case string:
			switch key {
			case "-i", "-input", "--input":
				fmt.printfln("input: %v: %v", key, value)
			case "-o", "-output", "--output":
				fmt.printfln("output: %v: %v", key, value)
			case:
				fmt.printfln("invalid string argument %v: %v", key, value)
			}
		}
		//--------------------
	}
	//----------------------------------------
	fmt.println()
	//----------------------------------------
}
