package main

//------------------------------------------------------------

import "core:fmt"
import "core:mem/virtual"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"
import "core:testing"
import "core:time"

//------------------------------------------------------------

@(test)
test_main :: proc(t: ^testing.T) {
	//----------------------------------------
	arena: virtual.Arena
	context.allocator = virtual.arena_allocator(&arena)
	defer virtual.arena_destroy(&arena)
	//----------------------------------------
	test_defaults(t)
	test_createDatabase(t)
	test_repairDatabase(t)
	test_listKeys(t)
	test_setKey_getKey_listKeys(t)
	test_checkKey(t)
	test_lenKey(t)
	test_mtimeKey(t)
	test_deleteKey(t)
	test_getKey(t)
	test_dropDatabase(t)
	test_printHelp(t)
	test_checkDirectoryPath(t)
	test_checkDirectoryName(t)
	test_checkKeyName(t)
	//----------------------------------------
}

//------------------------------------------------------------

test_defaults :: proc(t: ^testing.T) {
	//----------------------------------------
	testing.expect_value(t, config_filename, ".keyvaldb.conf")
	//----------------------------------------
}

//------------------------------------------------------------

test_createDatabase :: proc(t: ^testing.T) {
	//----------------------------------------
	err: Error
	output: string
	//----------------------------------------
	directory := ""
	//----------------------------------------
	output, err = createDatabase(directory)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.InvalidDirectoryLocation)
	//----------------------------------------
	directory = "test"
	//----------------------------------------
	if os2.exists(directory) {_ = os2.remove_all(directory)}
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if os2.exists(directory) {_ = os2.remove_all(directory)}
	testing.expect_value(t, os2.exists(directory), false)
	//----------------------------------------
	output, err = createDatabase(directory)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, nil)
	testing.expect_value(t, os2.exists(directory), true)
	testing.expect_value(t, os2.exists(config_filepath), true)
	//----------------------------------------
	output, err = createDatabase(directory)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.DatabaseAlreadyExists)
	//----------------------------------------
}

//------------------------------------------------------------

test_repairDatabase :: proc(t: ^testing.T) {
	//----------------------------------------
	err: Error
	output: string
	//----------------------------------------
	directory := ""
	//----------------------------------------
	output, err = repairDatabase(directory)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.InvalidDirectoryLocation)
	//----------------------------------------
	directory = "test"
	//----------------------------------------
	output, err = repairDatabase(directory)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, nil)
	//----------------------------------------
	config_filepath := filepath.join([]string{directory, config_filename})
	//----------------------------------------
	if os2.exists(config_filepath) {_ = os2.remove(config_filepath)}
	testing.expect_value(t, os2.exists(config_filepath), false)
	//----------------------------------------
	output, err = repairDatabase(directory)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, nil)
	testing.expect_value(t, os2.exists(config_filepath), true)
	//----------------------------------------
	if os2.exists(directory) {_ = os2.remove_all(directory)}
	//----------------------------------------
	output, err = repairDatabase(directory)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.DatabaseDoesNotExist)
	//----------------------------------------
}

//------------------------------------------------------------

test_listKeys :: proc(t: ^testing.T) {
	//----------------------------------------
	err: Error
	output: string
	//----------------------------------------
	directory := ""
	//----------------------------------------
	output, err = listKeys(directory)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.InvalidDirectoryLocation)
	//----------------------------------------
	directory = "test"
	//----------------------------------------
	if os2.exists(directory) {_ = os2.remove_all(directory)}
	//----------------------------------------
	output, err = listKeys(directory)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.DatabaseDoesNotExist)
	//----------------------------------------
	output, err = createDatabase(directory)
	//----------------------------------------
	output, err = listKeys(directory)
	testing.expect(t, strings.contains(output, "no key-value pairs exist"))
	testing.expect_value(t, err, nil)
	//----------------------------------------
}

//------------------------------------------------------------

test_setKey_getKey_listKeys :: proc(t: ^testing.T) {
	//----------------------------------------
	err: Error
	output: string
	//----------------------------------------
	directory := ""
	key := ""
	value := ""
	//----------------------------------------
	output, err = setKey(directory, key, value)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.InvalidDirectoryLocation)
	//----------------------------------------
	directory = "test"
	key = ""
	value = ""
	//----------------------------------------
	output, err = setKey(directory, key, value)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.InvalidKeyName)
	//----------------------------------------
	key = "k1"
	//----------------------------------------
	output, err = setKey(directory, key, value)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, nil)
	//----------------------------------------
	output, err = getKey(directory, key)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, nil)
	//----------------------------------------
	value = "v1"
	//----------------------------------------
	output, err = setKey(directory, key, value)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, nil)
	//----------------------------------------
	output, err = getKey(directory, key)
	testing.expect_value(t, output, "v1")
	testing.expect_value(t, err, nil)
	//----------------------------------------
	output, err = listKeys(directory)
	testing.expect(t, strings.contains(output, "KEY  VALUE"))
	testing.expect(t, strings.contains(output, "k1   v1"))
	testing.expect_value(t, err, nil)
	//----------------------------------------
}

//------------------------------------------------------------

test_checkKey :: proc(t: ^testing.T) {
	//----------------------------------------
	err: Error
	output: string
	//----------------------------------------
	directory := ""
	key := ""
	//----------------------------------------
	output, err = checkKey(directory, key)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.InvalidDirectoryLocation)
	//----------------------------------------
	directory = "test"
	key = ""
	//----------------------------------------
	output, err = checkKey(directory, key)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.InvalidKeyName)
	//----------------------------------------
	key = "k1"
	//----------------------------------------
	output, err = checkKey(directory, key)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, nil)
	//----------------------------------------
}

//------------------------------------------------------------

test_lenKey :: proc(t: ^testing.T) {
	//----------------------------------------
	err: Error
	output: string
	//----------------------------------------
	directory := ""
	key := ""
	//----------------------------------------
	output, err = lenKey(directory, key)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.InvalidDirectoryLocation)
	//----------------------------------------
	directory = "test"
	key = ""
	//----------------------------------------
	output, err = lenKey(directory, key)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.InvalidKeyName)
	//----------------------------------------
	key = "k1"
	//----------------------------------------
	output, err = lenKey(directory, key)
	testing.expect_value(t, output, "2")
	testing.expect_value(t, err, nil)
	//----------------------------------------
}

//------------------------------------------------------------

test_mtimeKey :: proc(t: ^testing.T) {
	//----------------------------------------
	err: Error
	output: string
	//----------------------------------------
	directory := ""
	key := ""
	//----------------------------------------
	output, err = mtimeKey(directory, key)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.InvalidDirectoryLocation)
	//----------------------------------------
	directory = "test"
	key = ""
	//----------------------------------------
	output, err = mtimeKey(directory, key)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.InvalidKeyName)
	//----------------------------------------
	key = "k1"
	//----------------------------------------
	output, err = mtimeKey(directory, key)
	//----------------------------------------
	now := time.now()
	fmtDate := fmt.aprintf("%04d-%02d-%02d", time.year(now), time.month(now), time.day(now))
	//----------------------------------------
	testing.expect(t, strings.has_prefix(output, fmtDate))
	testing.expect_value(t, err, nil)
	//----------------------------------------
}

//------------------------------------------------------------

test_deleteKey :: proc(t: ^testing.T) {
	//----------------------------------------
	err: Error
	output: string
	//----------------------------------------
	directory := ""
	key := ""
	value := ""
	//----------------------------------------
	output, err = deleteKey(directory, key)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.InvalidDirectoryLocation)
	//----------------------------------------
	directory = "test"
	key = ""
	value = ""
	//----------------------------------------
	output, err = deleteKey(directory, key)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.InvalidKeyName)
	//----------------------------------------
	key = "k1"
	//----------------------------------------
	output, err = deleteKey(directory, key)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, nil)
	//----------------------------------------
}

//------------------------------------------------------------

test_getKey :: proc(t: ^testing.T) {
	//----------------------------------------
	err: Error
	output: string
	//----------------------------------------
	directory := ""
	key := ""
	value := ""
	//----------------------------------------
	output, err = getKey(directory, key)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.InvalidDirectoryLocation)
	//----------------------------------------
	directory = "test"
	key = ""
	//----------------------------------------
	output, err = getKey(directory, key)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.InvalidKeyName)
	//----------------------------------------
	directory = "test"
	key = "k1"
	//----------------------------------------
	output, err = getKey(directory, key)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, nil)
	//----------------------------------------
}

//------------------------------------------------------------

test_dropDatabase :: proc(t: ^testing.T) {
	//----------------------------------------
	err: Error
	output: string
	//----------------------------------------
	directory := ""
	//----------------------------------------
	output, err = dropDatabase(directory)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.InvalidDirectoryLocation)
	//----------------------------------------
	directory = "test"
	//----------------------------------------
	output, err = dropDatabase(directory)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, nil)
	testing.expect_value(t, os2.exists(directory), false)
	//----------------------------------------
	output, err = dropDatabase(directory)
	testing.expect_value(t, output, "")
	testing.expect_value(t, err, KeyValError.DatabaseDoesNotExist)
	//----------------------------------------
}

//------------------------------------------------------------

test_printHelp :: proc(t: ^testing.T) {
	//----------------------------------------
	output, err := printHelp()
	//----------------------------------------
	if err != nil {
		testing.expect_value(t, err, nil)
	} else {
		testing.expect(t, strings.contains(output, "<DATABASE_DIRECTORY> create"))
		testing.expect(t, strings.contains(output, "<DATABASE_DIRECTORY> repair"))
		testing.expect(t, strings.contains(output, "<DATABASE_DIRECTORY> drop"))
		testing.expect(t, strings.contains(output, "<DATABASE_DIRECTORY> list"))
		testing.expect(t, strings.contains(output, "<DATABASE_DIRECTORY> set <KEY> <VALUE>"))
		testing.expect(
			t,
			strings.contains(output, "<DATABASE_DIRECTORY> set <KEY> <<< \"STDIN_DATA\""),
		)
		testing.expect(t, strings.contains(output, "<DATABASE_DIRECTORY> get <KEY>"))
		testing.expect(t, strings.contains(output, "<DATABASE_DIRECTORY> mtime <KEY>"))
		testing.expect(t, strings.contains(output, "<DATABASE_DIRECTORY> delete <KEY>"))
	}
	//----------------------------------------
}

//------------------------------------------------------------

test_checkDirectoryPath :: proc(t: ^testing.T) {
	//----------------------------------------
	directorys := []string {
		"",
		"/",
		"/root",
		"/tmp",
		"~",
		os2.get_env_alloc("HOME", context.allocator),
	}
	//----------------------------------------
	for directory in directorys {
		err := checkDirectoryPath(directory)
		testing.expect_value(t, err, KeyValError.InvalidDirectoryLocation)
	}
	//----------------------------------------
	directory := "test"
	//----------------------------------------
	err := checkDirectoryPath(directory)
	testing.expect_value(t, err, nil)
	//----------------------------------------
}

//------------------------------------------------------------

test_checkDirectoryName :: proc(t: ^testing.T) {
	//----------------------------------------
	testing.expect(t, !checkDirectoryName("$"))
	//----------------------------------------
	testing.expect(t, checkDirectoryName("."))
	testing.expect(t, checkDirectoryName("_"))
	testing.expect(t, checkDirectoryName("0"))
	testing.expect(t, checkDirectoryName("A"))
	testing.expect(t, checkDirectoryName("a"))
	//----------------------------------------
}

//------------------------------------------------------------

test_checkKeyName :: proc(t: ^testing.T) {
	//----------------------------------------
	testing.expect(t, !checkKeyName("$"))
	testing.expect(t, !checkKeyName("."))
	//----------------------------------------
	testing.expect(t, checkKeyName("_"))
	testing.expect(t, checkKeyName("0"))
	testing.expect(t, checkKeyName("A"))
	testing.expect(t, checkKeyName("a"))
	//----------------------------------------
}

//------------------------------------------------------------
