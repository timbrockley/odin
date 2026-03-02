package main

//------------------------------------------------------------
// Copyright 2026 Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//------------------------------------------------------------

import "core:bufio"
import "core:fmt"
import "core:mem/virtual"
import "core:os/os2"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import "core:sys/posix"

//------------------------------------------------------------

config_filename :: ".keyvaldb.conf"

//------------------------------------------------------------

Error :: union #shared_nil {
	KeyValError,
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
	os2.exit(err == nil ? 0 : 1)
	//------------------------------------------------------------
}

//------------------------------------------------------------

process_arguments :: proc() -> (string, Error) {
	//------------------------------------------------------------
	if len(os2.args) == 1 ||
	   os2.args[1] == "help" ||
	   os2.args[1] == "--help" ||
	   os2.args[1] == "-h" {return printHelp()}
	//----------------------------------------
	directory, instruction, key, value: string
	//----------------------------------------
	if len(os2.args) > 1 {directory = strings.trim_right(os2.args[1], "/")}
	if len(os2.args) > 2 {instruction = os2.args[2]}
	if len(os2.args) > 3 {key = os2.args[3]}
	if len(os2.args) > 4 {value = os2.args[4]}
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
	if os2.exists(directory) {
		if !os2.is_directory(directory) {return "", .InvalidDatabaseFilepath}
		if os2.exists(
			config_filepath,
		) {return "", .DatabaseAlreadyExists} else {return "", .InvalidConfigFile}
	} else {
		if err := os2.make_directory_all(directory); err != nil {return "", err}
	}
	//----------------------------------------
	if !os2.exists(config_filepath) {
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
	if !os2.exists(directory) {return "", .DatabaseDoesNotExist}
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if !os2.exists(config_filepath) {
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
	if !os2.exists(directory) {return "", .DatabaseDoesNotExist}
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if !os2.exists(config_filepath) {return "", .InvalidConfigFile} else {
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
	if !os2.exists(directory) {return "", .DatabaseDoesNotExist}
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if !os2.exists(config_filepath) {return "", .InvalidConfigFile}
	//----------------------------------------
	entries, err := os2.read_all_directory_by_path(directory, context.allocator)
	if err != nil {return "", err}
	//----------------------------------------
	if len(entries) < 2 {return "no key-value pairs exist\n", nil}
	//----------------------------------------
	max_key_len := 3 // maybe updated below
	//----------------------------------------
	Row :: struct {
		key:   string,
		value: []u8,
	}
	//----------------------------------------
	rows := [dynamic]Row{}
	//----------------------------------------
	slice.sort_by(entries, proc(a, b: os2.File_Info) -> bool {
		return a.name < b.name
	})
	//----------------------------------------
	for entry in entries {
		//----------------------------------------
		if entry.type != .Regular {continue}
		if entry.name == "" {continue}
		if entry.name == config_filename {continue}
		if !checkKeyName(entry.name) {continue}
		//----------------------------------------
		key := entry.name
		//----------------------------------------
		key_filepath := filepath.join([]string{directory, key})
		//----------------------------------------
		value, err := os2.read_entire_file_from_path(key_filepath, context.allocator)
		if err != nil {return "", err}
		//----------------------------------------
		escapeBytes(value)
		//----------------------------------------
		append(&rows, Row{key = key, value = value})
		//----------------------------------------
		if len(key) > max_key_len {max_key_len = len(key)}
		//----------------------------------------
	}
	//----------------------------------------
	buffer := strings.builder_make()
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
	if !os2.exists(directory) {return "", .DatabaseDoesNotExist}
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if !os2.exists(config_filepath) {return "", .InvalidConfigFile}
	//----------------------------------------
	if !checkKeyName(key) {return "", .InvalidKeyName}
	//----------------------------------------
	key_filepath := filepath.join([]string{directory, key})
	//----------------------------------------
	if os2.exists(key_filepath) && !os2.is_file(key_filepath) {
		return "", .InvalidKeyFile
	}
	//----------------------------------------
	// if value is blank then check stdin
	if value == "" && !posix.isatty(posix.STDIN_FILENO) {
		//----------------------------------------
		data, err := os2.read_entire_file_from_file(os2.stdin, context.allocator)
		if err != nil {return "", err}
		//----------------------------------------
		if err := os2.write_entire_file(key_filepath, string(data), os2.perm_number(0o770));
		   err != nil {
			return "", err
		}
		//----------------------------------------
	} else {
		//----------------------------------------
		if err := os2.write_entire_file_from_string(key_filepath, value, os2.perm_number(0o770));
		   err != nil {return "", err}
		//----------------------------------------
	}
	//----------------------------------------
	return "", nil
	//----------------------------------------
}

//------------------------------------------------------------

getKey :: proc(directory, key: string) -> (string, Error) {
	//----------------------------------------
	if err := checkDirectoryPath(directory); err != nil {return "", err}
	//----------------------------------------
	if !os2.exists(directory) {return "", .DatabaseDoesNotExist}
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if !os2.exists(config_filepath) {return "", .InvalidConfigFile}
	//----------------------------------------
	if !checkKeyName(key) {return "", .InvalidKeyName}
	//----------------------------------------
	key_filepath := filepath.join([]string{directory, key})
	//----------------------------------------
	if os2.exists(key_filepath) && !os2.is_file(key_filepath) {
		return "", .InvalidKeyFile
	}
	//----------------------------------------
	// if !os2.exists(key_filepath) {return "", .KeyDoesNotExist}
	if !os2.exists(key_filepath) {return "", nil}
	//----------------------------------------
	data, err := os2.read_entire_file_from_path(key_filepath, context.allocator)
	if err != nil {return "", err}
	//----------------------------------------
	return string(data), nil
	//----------------------------------------
}

//------------------------------------------------------------

mtimeKey :: proc(directory, key: string) -> (string, Error) {
	//----------------------------------------
	if err := checkDirectoryPath(directory); err != nil {return "", err}
	//----------------------------------------
	if !os2.exists(directory) {return "", .DatabaseDoesNotExist}
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if !os2.exists(config_filepath) {return "", .InvalidConfigFile}
	//----------------------------------------
	if !checkKeyName(key) {return "", .InvalidKeyName}
	//----------------------------------------
	key_filepath := filepath.join([]string{directory, key})
	//----------------------------------------
	if !os2.exists(key_filepath) {return "", .KeyDoesNotExist}
	//----------------------------------------
	if os2.exists(key_filepath) && !os2.is_file(key_filepath) {
		return "", .InvalidKeyFile
	}
	//----------------------------------------
	file_info, err := os2.stat(key_filepath, context.allocator)
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
	if !os2.exists(directory) {return "", .DatabaseDoesNotExist}
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if !os2.exists(config_filepath) {return "", .InvalidConfigFile}
	//----------------------------------------
	if !checkKeyName(key) {return "", .InvalidKeyName}
	//----------------------------------------
	key_filepath := filepath.join([]string{directory, key})
	//----------------------------------------
	if os2.exists(key_filepath) && !os2.is_file(key_filepath) {
		return "", .InvalidKeyFile
	}
	//----------------------------------------
	// if !os2.exists(key_filepath) {return "", .KeyDoesNotExist}
	if !os2.exists(key_filepath) {return "", nil}
	//----------------------------------------
	err := os2.remove(key_filepath)
	if err != nil {return "", err}
	//----------------------------------------
	return "", nil
	//----------------------------------------
}

//------------------------------------------------------------

printHelp :: proc() -> (string, Error) {
	//------------------------------------------------------------
	buffer := strings.builder_make()
	//------------------------------------------------------------
	cmd_name := filepath.base(os2.args[0])
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
	home_directory := os2.get_env_alloc("HOME", context.allocator)
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

escapeBytes :: proc(data: []u8) {
	//------------------------------------------------------------
	for i in 0 ..< len(data) {
		if data[i] <= 0x20 || data[i] == 0x7F {data[i] = 0x20}
	}
	//------------------------------------------------------------
}

//------------------------------------------------------------
