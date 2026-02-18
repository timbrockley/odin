package main

//------------------------------------------------------------
// Copyright 2026 Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//------------------------------------------------------------

import "core:bufio"
import "core:fmt"
import "core:io"
import "core:mem/virtual"
import "core:os"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"
import "core:sys/posix"

//------------------------------------------------------------

config_filename :: ".keyvaldb.conf"

//------------------------------------------------------------

Error :: union #shared_nil {
	KeyValError,
	os.Error,
	os2.Error,
	bufio.Scanner_Error,
}

KeyValError :: enum {
	None,
	InvalidDatabaseName,
	InvalidDirectoryLocation,
	InvalidDatabaseFilepath,
	InvalidConfigFile,
	InvalidInstruction,
	DatabaseAlreadyExists,
	DatabaseDoesNotExist,
	InvalidKeyName,
	InvalidKeyFile,
	KeyDoesNotExist,
}

//------------------------------------------------------------

main :: proc() {
	//------------------------------------------------------------
	arena: virtual.Arena; context.allocator = virtual.arena_allocator(&arena)
	//------------------------------------------------------------
	output, err := process_arguments()
	//------------------------------------------------------------
	if err != nil {
		fmt.eprintln(err)
	} else {
		fmt.print(output)
	}
	//------------------------------------------------------------
	virtual.arena_destroy(&arena)
	//------------------------------------------------------------
	os.exit(err == nil ? 0 : 1)
	//------------------------------------------------------------
}

//------------------------------------------------------------

process_arguments :: proc() -> (string, Error) {
	//------------------------------------------------------------
	if len(os.args) == 1 ||
	   os.args[1] == "help" ||
	   os.args[1] == "--help" ||
	   os.args[1] == "-h" {return printHelp()}
	//----------------------------------------
	directory, instruction, key, value: string
	//----------------------------------------
	if len(os.args) > 1 {directory = strings.trim_right(os.args[1], "/")}
	if len(os.args) > 2 {instruction = os.args[2]}
	if len(os.args) > 3 {key = os.args[3]}
	if len(os.args) > 4 {value = os.args[4]}
	//----------------------------------------
	switch instruction {
	case "create":
		return createDatabase(directory)
	case "repair":
		return repairDatabase(directory)
	case "drop":
		return dropDatabase(directory)
	case "list":
		return listKeys(directory)
	case "set":
		return setKey(directory, key, value)
	case "get":
		return getKey(directory, key)
	case "mtime":
		return mtimeKey(directory, key)
	case "remove":
		return removeKey(directory, key)
	case:
		return "", .InvalidInstruction
	}
	//------------------------------------------------------------
}

//------------------------------------------------------------

createDatabase :: proc(directory: string) -> (string, Error) {
	//----------------------------------------
	if err := checkDirectoryPath(directory); err != nil {return "", err}
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if os.exists(directory) {
		if !os.is_dir(directory) {return "", .InvalidDatabaseFilepath}
		if os.exists(
			config_filepath,
		) {return "", .DatabaseAlreadyExists} else {return "", .InvalidConfigFile}
	} else {
		if err := os2.make_directory_all(directory); err != nil {return "", err}
	}
	//----------------------------------------
	if !os.exists(config_filepath) {
		if _, err := os2.create(config_filepath); err != nil {return "", err}
	}
	//----------------------------------------
	return "", nil
	//----------------------------------------
}

//------------------------------------------------------------

repairDatabase :: proc(directory: string) -> (string, Error) {
	//----------------------------------------
	if err := checkDirectoryPath(directory); err != nil {return "", err}
	//----------------------------------------
	if !os.exists(directory) {return "", .DatabaseDoesNotExist}
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if !os.exists(config_filepath) {
		if _, err := os2.create(config_filepath); err != nil {return "", err}
	}
	//----------------------------------------
	return "", nil
	//----------------------------------------
}

//------------------------------------------------------------

dropDatabase :: proc(directory: string) -> (string, Error) {
	//----------------------------------------
	if err := checkDirectoryPath(directory); err != nil {return "", err}
	//----------------------------------------
	if !os.exists(directory) {
		return "", .DatabaseDoesNotExist
	}
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if !os.exists(config_filepath) {
		return "", .InvalidConfigFile
	} else {
		if err := os2.remove_all(directory); err != nil {return "", err}
	}
	//----------------------------------------
	return "", nil
	//----------------------------------------
}

//------------------------------------------------------------

listKeys :: proc(directory: string) -> (string, Error) {
	//----------------------------------------
	if err := checkDirectoryPath(directory); err != nil {return "", err}
	//----------------------------------------
	if !os.exists(directory) {
		return "", .DatabaseDoesNotExist
	}
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if !os.exists(config_filepath) {
		return "", .InvalidConfigFile
	}
	//----------------------------------------
	entries, err := os2.read_all_directory_by_path(directory, context.allocator)
	if err != nil {return "", err}
	//----------------------------------------
	if len(entries) < 2 {return "no key-value pairs exist\n", nil}
	//----------------------------------------
	buffer := strings.builder_make()
	defer strings.builder_destroy(&buffer)
	//----------------------------------------
	max_key_len := 3 // maybe updated below
	//----------------------------------------
	Row :: struct {
		key:   string,
		value: string,
	}
	//----------------------------------------
	rows := [dynamic]Row{}
	defer delete(rows)
	//----------------------------------------
	for entry in entries {
		//----------------------------------------
		if entry.type != .Regular {continue}
		if entry.name == "" {continue}
		if entry.name == config_filename {continue}
		if !checkKeyName(entry.name) {continue}
		//----------------------------------------
		key := entry.name
		value, err := getKey(directory, key)
		if err != nil {return "", err}
		//----------------------------------------
		append(&rows, Row{key = key, value = escapeString(value)})
		//----------------------------------------
		if len(key) > max_key_len {max_key_len = len(key)}
		//----------------------------------------
	}
	//----------------------------------------
	strings.write_string(&buffer, fmt.aprintf("\n%-*s%s\n", max_key_len + 2, "KEY", "VALUE"))
	//----------------------------------------
	for row in rows {
		strings.write_string(&buffer, fmt.aprintf("%-*s%s\n", max_key_len + 2, row.key, row.value))
	}
	//----------------------------------------
	strings.write_string(&buffer, "\n")
	//----------------------------------------
	return strings.clone(strings.to_string(buffer)), nil
	//----------------------------------------
}

//------------------------------------------------------------

setKey :: proc(directory, key, value: string) -> (string, Error) {
	//----------------------------------------
	if err := checkDirectoryPath(directory); err != nil {return "", err}
	//----------------------------------------
	if !os.exists(directory) {
		return "", .DatabaseDoesNotExist
	}
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if !os.exists(config_filepath) {
		return "", .InvalidConfigFile
	}
	//----------------------------------------
	if !checkKeyName(key) {return "", .InvalidKeyName}
	//----------------------------------------
	_value := value
	//----------------------------------------
	// if value is blank then check stdin
	if _value == "" && !posix.isatty(posix.STDIN_FILENO) {
		//----------------------------------------
		lines: [dynamic]string
		defer delete(lines)
		//----------------------------------------
		scanner: bufio.Scanner
		stdin := os.stream_from_handle(os.stdin)
		bufio.scanner_init(&scanner, stdin)
		//----------------------------------------
		for {
			if !bufio.scanner_scan(&scanner) {
				break
			}
			append(&lines, bufio.scanner_text(&scanner))
		}
		if err := bufio.scanner_error(&scanner); err != nil {
			return "", err
		}
		//----------------------------------------
		_value = strings.join(lines[:], "\n")
		//----------------------------------------
	}
	//----------------------------------------
	filepath := filepath.join([]string{directory, key})
	//----------------------------------------
	if os.exists(filepath) && !os.is_file(filepath) {
		return "", .InvalidKeyFile
	}
	//----------------------------------------
	if err := os.write_entire_file_or_err(filepath, transmute([]byte)_value, true);
	   err != nil {return "", err}
	//----------------------------------------
	return "", nil
	//----------------------------------------
}

//------------------------------------------------------------

getKey :: proc(directory, key: string) -> (string, Error) {
	//----------------------------------------
	if err := checkDirectoryPath(directory); err != nil {return "", err}
	//----------------------------------------
	if !os.exists(directory) {
		return "", .DatabaseDoesNotExist
	}
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if !os.exists(config_filepath) {
		return "", .InvalidConfigFile
	}
	//----------------------------------------
	if !checkKeyName(key) {return "", .InvalidKeyName}
	//----------------------------------------
	filepath := filepath.join([]string{directory, key})
	//----------------------------------------
	if os.exists(filepath) && !os.is_file(filepath) {
		return "", .InvalidKeyFile
	}
	//----------------------------------------
	data, err := os.read_entire_file_or_err(filepath)
	if err != nil {
		// if err == os.ENOENT {return "", .KeyDoesNotExist} else {return "", err}
		if err == os.ENOENT {return "", nil} else {return "", err}
	}
	//----------------------------------------
	return string(data), nil
	//----------------------------------------
}

//------------------------------------------------------------

mtimeKey :: proc(directory, key: string) -> (string, Error) {
	//----------------------------------------
	if err := checkDirectoryPath(directory); err != nil {return "", err}
	//----------------------------------------
	if !os.exists(directory) {
		return "", .DatabaseDoesNotExist
	}
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if !os.exists(config_filepath) {
		return "", .InvalidConfigFile
	}
	//----------------------------------------
	if !checkKeyName(key) {return "", .InvalidKeyName}
	//----------------------------------------
	filepath := filepath.join([]string{directory, key})
	//----------------------------------------
	if !os.exists(filepath) {return "", .KeyDoesNotExist}
	//----------------------------------------
	if os.exists(filepath) && !os.is_file(filepath) {
		return "", .InvalidKeyFile
	}
	//----------------------------------------
	file_info, err := os2.stat(filepath, context.allocator)
	if err != nil {return "", err}
	//----------------------------------------
	return fmt.aprintf("%s", file_info.modification_time), nil
	//----------------------------------------
}

//------------------------------------------------------------

removeKey :: proc(directory, key: string) -> (string, Error) {
	//----------------------------------------
	if err := checkDirectoryPath(directory); err != nil {return "", err}
	//----------------------------------------
	if !os.exists(directory) {
		return "", .DatabaseDoesNotExist
	}
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if !os.exists(config_filepath) {
		return "", .InvalidConfigFile
	}
	//----------------------------------------
	if !checkKeyName(key) {return "", .InvalidKeyName}
	//----------------------------------------
	filepath := filepath.join([]string{directory, key})
	//----------------------------------------
	if os.exists(filepath) && !os.is_file(filepath) {
		return "", .InvalidKeyFile
	}
	//----------------------------------------
	err := os.remove(filepath)
	if err != nil {
		// if err == os.ENOENT {return "", .KeyDoesNotExist} else {return "", err}
		if err == os.ENOENT {return "", nil} else {return "", err}
	}
	//----------------------------------------
	return "", nil
	//----------------------------------------
}

//------------------------------------------------------------

printHelp :: proc() -> (string, Error) {
	//------------------------------------------------------------
	buffer := strings.builder_make()
	defer strings.builder_destroy(&buffer)
	//------------------------------------------------------------
	cmd_name := filepath.base(os.args[0])
	//------------------------------------------------------------
	lines := []string {
		"<DATABASE_DIRECTORY> create",
		"<DATABASE_DIRECTORY> repair",
		"<DATABASE_DIRECTORY> drop",
		"<DATABASE_DIRECTORY> list",
		"<DATABASE_DIRECTORY> set <KEY> <VALUE>",
		"<DATABASE_DIRECTORY> set <KEY> <<< \"STDIN_DATA\"",
		"<DATABASE_DIRECTORY> get <KEY>",
		"<DATABASE_DIRECTORY> mtime <KEY>",
		"<DATABASE_DIRECTORY> remove <KEY>",
	}
	//------------------------------------------------------------
	strings.write_string(&buffer, "\n")
	for line in lines {
		strings.write_string(&buffer, fmt.aprintf("%s %s\n", cmd_name, line))
	}
	strings.write_string(&buffer, "\n")
	//------------------------------------------------------------
	return strings.clone(strings.to_string(buffer)), nil
	//------------------------------------------------------------
}

//------------------------------------------------------------

checkDirectoryPath :: proc(directory: string) -> Error {
	//------------------------------------------------------------
	switch directory {
	case "", "/", "/root", "/tmp", "~":
		return .InvalidDirectoryLocation
	}
	//------------------------------------------------------------
	home_directory := os.get_env_alloc("HOME")
	if home_directory != "" && directory == home_directory {
		return .InvalidDirectoryLocation
	}
	//------------------------------------------------------------
	if !checkDirectoryName(filepath.base(directory)) {return .InvalidDatabaseName}
	//------------------------------------------------------------
	return nil
	//------------------------------------------------------------
}

//------------------------------------------------------------

checkDirectoryName :: proc(name: string) -> bool {
	//------------------------------------------------------------
	if name == "" {return false}
	//------------------------------------------------------------
	for char in name {
		switch char {
		case '.', '_', '0' ..= '9', 'A' ..= 'Z', 'a' ..= 'z':
			continue
		case:
			return false
		}
	}
	//------------------------------------------------------------
	return true
	//------------------------------------------------------------
}

//------------------------------------------------------------

checkKeyName :: proc(name: string) -> bool {
	//------------------------------------------------------------
	if name == "" || name == config_filename {return false}
	//------------------------------------------------------------
	for char in name {
		switch char {
		case '_', '0' ..= '9', 'A' ..= 'Z', 'a' ..= 'z':
			continue
		case:
			return false
		}
	}
	//------------------------------------------------------------
	return true
	//------------------------------------------------------------
}

//------------------------------------------------------------

escapeString :: proc(data: string) -> string {
	//------------------------------------------------------------
	if len(data) == 0 {
		return data
	}
	//------------------------------------------------------------
	output := make([]u8, len(data))
	//------------------------------------------------------------
	for i := 0; i < len(data); i += 1 {
		switch data[i] {
		case 0x00 ..= 0x20, 0x7F:
			output[i] = 0x20
		case:
			output[i] = data[i]
		}
	}
	//------------------------------------------------------------
	return string(output)
	//------------------------------------------------------------
}

//------------------------------------------------------------
