//--------------------------------------------------------------------------------
//
// sudo apt install -y libsqlite3-dev
//
//--------------------------------------------------------------------------------
package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:strings"
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
DATABASE_FILEPATH :: "test1.db"
//--------------------------------------------------------------------------------
StringRow :: struct {
	key:   string,
	value: string,
}
//--------------------------------------------------------------------------------
CallbackContext :: struct {
	//----------------------------------------
	allocator:   mem.Allocator,
	string_rows: [dynamic]StringRow,
	//----------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
main :: proc() {
	//--------------------------------------------------------------------------------
	ctx := CallbackContext {
		allocator = context.allocator,
	}
	//------------------------------------------------------------
	defer {
		//----------------------------------------
		for row in ctx.string_rows {
			delete(row.key)
			delete(row.value)
		}
		delete(ctx.string_rows)
		//----------------------------------------
	}
	//--------------------------------------------------------------------------------
	//################################################################################
	//--------------------------------------------------------------------------------
	db_handle: ^rawptr = nil
	//--------------------------------------------------------------------------------
	if sqlite3_open(DATABASE_FILEPATH, &db_handle) != SQLITE_OK {
		fmt.eprintfln("sqlite3_open: %s", sqlite3_errmsg(db_handle))
		return
	}
	defer sqlite3_close(db_handle)
	//------------------------------------------------------------
	{
		//------------------------------------------------------------
		sql: cstring = "PRAGMA journal_mode=WAL;"
		//------------------------------------------------------------
		errmsg: rawptr = nil
		rc := sqlite3_exec(db_handle, sql, callback, cast(rawptr)&ctx, &errmsg)
		if rc != SQLITE_OK {
			fmt.eprintf("sqlite3_exec: (%d) %s\n", rc, cstring(errmsg))
			sqlite3_free(errmsg)
			return
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	{
		//------------------------------------------------------------
		sql: cstring = "DROP TABLE IF EXISTS test;"
		//------------------------------------------------------------
		errmsg: rawptr = nil
		rc := sqlite3_exec(db_handle, sql, callback, cast(rawptr)&ctx, &errmsg)
		if rc != SQLITE_OK {
			fmt.eprintf("sqlite3_exec: %s\n", cstring(errmsg))
			sqlite3_free(errmsg)
			return
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	{
		//------------------------------------------------------------
		sql: cstring = "CREATE TABLE IF NOT EXISTS test (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(255));"
		//------------------------------------------------------------
		errmsg: rawptr = nil
		rc := sqlite3_exec(db_handle, sql, callback, cast(rawptr)&ctx, &errmsg)
		if rc != SQLITE_OK {
			fmt.eprintf("sqlite3_exec: %s\n", cstring(errmsg))
			sqlite3_free(errmsg)
			return
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	{
		//------------------------------------------------------------
		sql: cstring = `INSERT INTO test (name) VALUES('name1');
	 	INSERT INTO test (name) VALUES('name2');`
		//------------------------------------------------------------
		errmsg: rawptr = nil
		rc := sqlite3_exec(db_handle, sql, callback, cast(rawptr)&ctx, &errmsg)
		if rc != SQLITE_OK {
			fmt.eprintf("sqlite3_exec: %s\n", cstring(errmsg))
			sqlite3_free(errmsg)
			return
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	{
		//------------------------------------------------------------
		sql: cstring = "SELECT * FROM test;"
		//------------------------------------------------------------
		errmsg: rawptr = nil
		rc := sqlite3_exec(db_handle, sql, callback, cast(rawptr)&ctx, &errmsg)
		if rc != SQLITE_OK {
			fmt.eprintf("sqlite3_exec: %s\n", cstring(errmsg))
			sqlite3_free(errmsg)
			return
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	{
		//------------------------------------------------------------
		printLine()
		for row in ctx.string_rows {
			fmt.printf("%s = %s\n", row.key, row.value)
			printLine()
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
callback :: proc "c" (
	ctx_ptr: rawptr,
	argc: c.int,
	argv: [^]cstring,
	azColName: [^]cstring,
) -> c.int {
	//------------------------------------------------------------
	ctx := cast(^CallbackContext)ctx_ptr
	//------------------------------------------------------------
	context = runtime.Context {
		allocator = ctx.allocator,
	}
	//------------------------------------------------------------
	row := StringRow{}
	//------------------------------------------------------------
	for index in 0 ..< int(argc) {
		//----------------------------------------
		row.key = strings.clone(string(azColName[index]))
		//----------------------------------------
		if argv[index] == nil {
			row.value = strings.clone("NULL")
		} else {
			row.value = strings.clone(string(argv[index]))
		}
		//----------------------------------------
	}
	//------------------------------------------------------------
	append(&ctx.string_rows, row)
	//------------------------------------------------------------
	return SQLITE_OK
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
printLine :: proc() {fmt.println(
		"--------------------------------------------------------------------------------",
	)}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------

foreign import sqlite "system:sqlite3"
foreign sqlite {
	//------------------------------------------------------------
	sqlite3_close :: proc "c" (db_handle: ^rawptr) -> c.int ---
	sqlite3_errmsg :: proc "c" (db_handle: ^rawptr) -> cstring ---
	sqlite3_exec :: proc "c" (db_handle: ^rawptr, sql: cstring, callback: proc "c" (ctx_ptr: rawptr, argc: c.int, argv: [^]cstring, azColName: [^]cstring) -> c.int, arg: rawptr, errmsg: ^rawptr) -> c.int ---
	sqlite3_free :: proc "c" (ptr: rawptr) ---
	sqlite3_open :: proc "c" (filepath: cstring, db_handle: ^^rawptr) -> c.int ---
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
SQLITE_OK :: 0
SQLITE_ERROR :: 1
SQLITE_INTERNAL :: 2
SQLITE_PERM :: 3
SQLITE_ABORT :: 4
SQLITE_BUSY :: 5
SQLITE_LOCKED :: 6
SQLITE_NOMEM :: 7
SQLITE_READONLY :: 8
SQLITE_INTERRUPT :: 9
SQLITE_IOERR :: 10
SQLITE_CORRUPT :: 11
SQLITE_NOTFOUND :: 12
SQLITE_FULL :: 13
SQLITE_CANTOPEN :: 14
SQLITE_PROTOCOL :: 15
SQLITE_EMPTY :: 16
SQLITE_SCHEMA :: 17
SQLITE_TOOBIG :: 18
SQLITE_CONSTRAINT :: 19
SQLITE_MISMATCH :: 20
SQLITE_MISUSE :: 21
SQLITE_NOLFS :: 22
SQLITE_AUTH :: 23
SQLITE_FORMAT :: 24
SQLITE_RANGE :: 25
SQLITE_NOTADB :: 26
SQLITE_NOTICE :: 27
SQLITE_WARNING :: 28
SQLITE_ROW :: 100
SQLITE_DONE :: 101
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
