//--------------------------------------------------------------------------------
// Copyright 2026, Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//--------------------------------------------------------------------------------
package sqlite
//--------------------------------------------------------------------------------
import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:path/filepath"
import "core:reflect"
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
Self :: SQLiteDB
//--------------------------------------------------------------------------------
MAX_ERRMSG :: 256
MAX_TABLE_NAME :: 256
//--------------------------------------------------------------------------------
SQLiteDB :: struct {
	//----------------------------------------
	db_handle: ^rawptr,
	rc:        i32,
	errmsg:    [MAX_ERRMSG]u8,
	//----------------------------------------
}
//--------------------------------------------------------------------------------
SQLiteColumnType :: enum i32 {
	//----------------------------------------
	SQLITE_UNKNOWN = 0,
	SQLITE_INTEGER = 1,
	SQLITE_FLOAT   = 2,
	SQLITE_TEXT    = 3,
	SQLITE_BLOB    = 4,
	SQLITE_NULL    = 5,
	//----------------------------------------
}
//--------------------------------------------------------------------------------
SQLiteColumn :: struct {
	//----------------------------------------
	index:       int,
	name:        cstring,
	column_type: SQLiteColumnType,
	ptr:         [^]u8,
	len:         int,
	integer:     i64,
	float:       f64,
	//----------------------------------------
}
//--------------------------------------------------------------------------------
SQLiteColumnsTable :: struct {
	//----------------------------------------
	allocator:      mem.Allocator,
	arena_ptr:      ^virtual.Arena,
	//----------------------------------------
	sqlite_columns: [dynamic]SQLiteColumn,
	//----------------------------------------
	row_count:      int,
	column_count:   int,
	//----------------------------------------
}
//--------------------------------------------------------------------------------
null :: struct {}
//----------------------------------------
ColumnValue :: union {
	//----------------------------------------
	null,
	i64,
	f64,
	string,
	[]u8,
	//----------------------------------------
}
//--------------------------------------------------------------------------------
Error :: union #shared_nil {
	SQLiteError,
	mem.Allocator_Error,
}
//--------------------------------------------------------------------------------
SQLiteError :: enum {
	None,
	AllocationError,
	SQLiteOpenError,
	InvalidDBHandle,
	InvalidStmtHandle,
	InvalidTableName,
	InvalidSQLiteQuery,
	SQLitePrepareError,
	SQLiteFinalizeError,
	SQLiteStepError,
	ZeroColumnCount,
	SQLiteMalloc64Error,
	CallbackAborted,
	UnknownColumnType,
	FieldNotFound,
	FieldTypeMismatch,
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
init :: proc() -> Self {return SQLiteDB{}}
//--------------------------------------------------------------------------------
connect :: proc(self: ^Self, filepath: cstring) -> Error {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	db_handle: ^rawptr = nil
	//------------------------------------------------------------
	rc := sqlite3_open(filepath, &db_handle)
	//------------------------------------------------------------
	if rc != SQLITE_OK {
		return returnError(self, rc, sqliteErrmsg(self), .SQLiteOpenError)
	}
	//------------------------------------------------------------
	self.db_handle = db_handle
	//------------------------------------------------------------
	return nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
close :: proc(self: ^Self) {
	//------------------------------------------------------------
	defer sqlite3_close(self.db_handle)
	self.db_handle = nil
	clearErrorMessage(self)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteErrmsg :: proc(self: ^Self) -> cstring {
	//------------------------------------------------------------
	return cast(cstring)sqlite3_errmsg(self.db_handle)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
sqliteGetTable :: proc(
	self: ^Self,
	sql: cstring,
	results: ^^cstring,
	row_count: ^i32,
	column_count: ^i32,
	errmsg: ^rawptr,
) -> i32 {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		errmsg^ = sqlite3_mprintf("invalid db_handle")
		return returnErrorCode(self, SQLITE_MISUSE, "invalid db_handle")
	}
	//------------------------------------------------------------
	if sql == nil || len(sql) == 0 {
		errmsg^ = rawptr(sqlite3_mprintf("invalid sqlite query"))
		return returnErrorCode(self, SQLITE_ERROR, "invalid sqlite query")
	}
	//------------------------------------------------------------
	rc := sqlite3_get_table(self.db_handle, sql, results, row_count, column_count, errmsg)
	//------------------------------------------------------------
	if rc != SQLITE_OK {
		return returnErrorCode(self, rc, cast(cstring)(errmsg^))
	}
	//------------------------------------------------------------
	return rc
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteFreeTable :: proc(self: ^Self, results: [^]cstring) {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	sqlite3_free_table(results)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteExec :: proc(
	self: ^Self,
	sql: cstring,
	callback: proc "c" (
		ctx_ptr: rawptr,
		argc: i32,
		argv: [^]cstring,
		azColName: [^]cstring,
	) -> i32,
	ctx_ptr: rawptr,
	errmsg: ^rawptr,
) -> i32 {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		errmsg^ = sqlite3_mprintf("invalid db_handle")
		return returnErrorCode(self, SQLITE_MISUSE, "invalid db_handle")
	}
	//------------------------------------------------------------
	if sql == nil || len(sql) == 0 {
		errmsg^ = rawptr(sqlite3_mprintf("invalid sqlite query"))
		return returnErrorCode(self, SQLITE_ERROR, "invalid sqlite query")
	}
	//------------------------------------------------------------
	rc := sqlite3_exec(self.db_handle, sql, callback, ctx_ptr, errmsg)
	//------------------------------------------------------------
	if rc != SQLITE_OK {
		return returnErrorCode(self, rc, cast(cstring)(errmsg^))
	}
	//------------------------------------------------------------
	return rc
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
sqlitePrepare :: proc(self: ^Self, sql: cstring, stmt_handle: ^^rawptr) -> i32 {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		stmt_handle^ = nil
		return returnErrorCode(self, SQLITE_MISUSE, "invalid db_handle")
	}
	//------------------------------------------------------------
	if sql == nil || len(sql) == 0 {
		return returnErrorCode(self, SQLITE_ERROR, "invalid sqlite query")
	}
	//------------------------------------------------------------
	rc := sqlite3_prepare_v2(self.db_handle, sql, -1, stmt_handle, nil)
	//------------------------------------------------------------
	if (rc != SQLITE_OK) {
		stmt_handle^ = nil
		return returnErrorCode(self, rc, sqliteErrmsg(self))
	}
	//------------------------------------------------------------
	return SQLITE_OK
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteClearBindings :: proc(self: ^Self, stmt_handle: ^rawptr) -> i32 {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid db_handle")
	}
	//------------------------------------------------------------
	if stmt_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid stmt_handle")
	}
	//------------------------------------------------------------
	rc := sqlite3_clear_bindings(stmt_handle)
	//------------------------------------------------------------
	if (rc != SQLITE_OK) {
		return returnErrorCode(self, rc, sqliteErrmsg(self))
	}
	//------------------------------------------------------------
	return SQLITE_OK
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteBindBlob :: proc(
	self: ^Self,
	stmt_handle: ^rawptr,
	iCol: i32,
	ptr: rawptr,
	len: i32,
	destructor_function: proc "c" (ptr: rawptr) = nil,
) -> i32 {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid db_handle")
	}
	//------------------------------------------------------------
	if stmt_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid stmt_handle")
	}
	//------------------------------------------------------------
	rc := sqlite3_bind_blob(stmt_handle, iCol, ptr, len, destructor_function)
	//------------------------------------------------------------
	if (rc != SQLITE_OK) {
		return returnErrorCode(self, rc, sqliteErrmsg(self))
	}
	//------------------------------------------------------------
	return SQLITE_OK
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteBindText :: proc(
	self: ^Self,
	stmt_handle: ^rawptr,
	iCol: i32,
	ptr: rawptr,
	len: i32,
	destructor_function: proc "c" (ptr: rawptr) = nil,
) -> i32 {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid db_handle")
	}
	//------------------------------------------------------------
	if stmt_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid stmt_handle")
	}
	//------------------------------------------------------------
	rc := sqlite3_bind_text(stmt_handle, iCol, ptr, len, destructor_function)
	//------------------------------------------------------------
	if (rc != SQLITE_OK) {
		return returnErrorCode(self, rc, sqliteErrmsg(self))
	}
	//------------------------------------------------------------
	return SQLITE_OK
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteBindInt64 :: proc(self: ^Self, stmt_handle: ^rawptr, iCol: i32, integer: i64) -> i32 {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid db_handle")
	}
	//------------------------------------------------------------
	if stmt_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid stmt_handle")
	}
	//------------------------------------------------------------
	rc := sqlite3_bind_int64(stmt_handle, iCol, integer)
	//------------------------------------------------------------
	if (rc != SQLITE_OK) {
		return returnErrorCode(self, rc, sqliteErrmsg(self))
	}
	//------------------------------------------------------------
	return SQLITE_OK
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteBindDouble :: proc(self: ^Self, stmt_handle: ^rawptr, iCol: i32, float: f64) -> i32 {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid db_handle")
	}
	//------------------------------------------------------------
	if stmt_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid stmt_handle")
	}
	//------------------------------------------------------------
	rc := sqlite3_bind_double(stmt_handle, iCol, float)
	//------------------------------------------------------------
	if (rc != SQLITE_OK) {
		return returnErrorCode(self, rc, sqliteErrmsg(self))
	}
	//------------------------------------------------------------
	return SQLITE_OK
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteBindNull :: proc(self: ^Self, stmt_handle: ^rawptr, iCol: i32) -> i32 {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid db_handle")
	}
	//------------------------------------------------------------
	if stmt_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid stmt_handle")
	}
	//------------------------------------------------------------
	rc := sqlite3_bind_null(stmt_handle, iCol)
	//------------------------------------------------------------
	if (rc != SQLITE_OK) {
		return returnErrorCode(self, rc, sqliteErrmsg(self))
	}
	//------------------------------------------------------------
	return SQLITE_OK
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteColumnName :: proc(_: ^Self, stmt_handle: ^rawptr, iCol: i32) -> rawptr {
	//------------------------------------------------------------
	return sqlite3_column_name(stmt_handle, iCol)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteColumnType :: proc(_: ^Self, stmt_handle: ^rawptr, iCol: i32) -> i32 {
	//------------------------------------------------------------
	return sqlite3_column_type(stmt_handle, iCol)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteColumnBlob :: proc(_: ^Self, stmt_handle: ^rawptr, iCol: i32) -> rawptr {
	//------------------------------------------------------------
	return sqlite3_column_blob(stmt_handle, iCol)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteBlobString :: proc(_: ^Self, stmt_handle: ^rawptr, iCol: i32) -> string {
	ptr := sqlite3_column_blob(stmt_handle, iCol)
	if ptr == nil do return ""
	len := sqlite3_column_bytes(stmt_handle, iCol)
	return string((cast([^]u8)ptr)[:len])
}
//--------------------------------------------------------------------------------
sqliteBlobCString :: proc(_: ^Self, stmt_handle: ^rawptr, iCol: i32) -> cstring {
	ptr := sqlite3_column_blob(stmt_handle, iCol)
	if ptr == nil do return ""
	return cstring(ptr)
}
//--------------------------------------------------------------------------------
sqliteColumnText :: proc(_: ^Self, stmt_handle: ^rawptr, iCol: i32) -> rawptr {
	//------------------------------------------------------------
	return sqlite3_column_text(stmt_handle, iCol)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteTextString :: proc(_: ^Self, stmt_handle: ^rawptr, iCol: i32) -> string {
	ptr := sqlite3_column_text(stmt_handle, iCol)
	if ptr == nil do return ""
	len := sqlite3_column_bytes(stmt_handle, iCol)
	return string((cast([^]u8)ptr)[:len])
}
//--------------------------------------------------------------------------------
sqliteTextCString :: proc(_: ^Self, stmt_handle: ^rawptr, iCol: i32) -> cstring {
	ptr := sqlite3_column_text(stmt_handle, iCol)
	return ptr == nil ? "" : cstring(ptr)
}
//--------------------------------------------------------------------------------
sqliteColumnInt64 :: proc(_: ^Self, stmt_handle: ^rawptr, iCol: i32) -> i64 {
	//------------------------------------------------------------
	return sqlite3_column_int64(stmt_handle, iCol)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteColumnDouble :: proc(_: ^Self, stmt_handle: ^rawptr, iCol: i32) -> f64 {
	//------------------------------------------------------------
	return sqlite3_column_double(stmt_handle, iCol)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteColumnBytes :: proc(_: ^Self, stmt_handle: ^rawptr, iCol: i32) -> i32 {
	//------------------------------------------------------------
	return sqlite3_column_bytes(stmt_handle, iCol)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteColumnCount :: proc(_: ^Self, stmt_handle: ^rawptr) -> i32 {
	//------------------------------------------------------------
	return sqlite3_column_count(stmt_handle)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteDataCount :: proc(_: ^Self, stmt_handle: ^rawptr) -> i32 {
	//------------------------------------------------------------
	return sqlite3_data_count(stmt_handle)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteStep :: proc(self: ^Self, stmt_handle: ^rawptr) -> i32 {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid db_handle")
	}
	//------------------------------------------------------------
	if stmt_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid stmt_handle")
	}
	//------------------------------------------------------------
	rc := sqlite3_step(stmt_handle)
	//------------------------------------------------------------
	setErrorMessage(self, rc, sqliteErrmsg(self))
	//------------------------------------------------------------
	return rc
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteReset :: proc(self: ^Self, stmt_handle: ^rawptr) -> i32 {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid db_handle")
	}
	//------------------------------------------------------------
	if stmt_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid stmt_handle")
	}
	//------------------------------------------------------------
	rc := sqlite3_reset(stmt_handle)
	//------------------------------------------------------------
	if (rc != SQLITE_OK) {
		return returnErrorCode(self, rc, sqliteErrmsg(self))
	}
	//------------------------------------------------------------
	return SQLITE_OK
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteFinalize :: proc(self: ^Self, stmt_handle: ^rawptr) -> i32 {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid db_handle")
	}
	//------------------------------------------------------------
	if stmt_handle == nil {
		return returnErrorCode(self, SQLITE_MISUSE, "invalid stmt_handle")
	}
	//------------------------------------------------------------
	rc := sqlite3_finalize(stmt_handle)
	//------------------------------------------------------------
	if (rc != SQLITE_OK) {
		return returnErrorCode(self, rc, sqliteErrmsg(self))
	}
	//------------------------------------------------------------
	return SQLITE_OK
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
sqliteMalloc64 :: proc(size: u64) -> rawptr {
	//------------------------------------------------------------
	return sqlite3_malloc64(size)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteRealloc64 :: proc(ptr: rawptr, size: u64) -> rawptr {
	//------------------------------------------------------------
	return sqlite3_realloc64(ptr, size)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
sqliteFree :: proc(ptr: rawptr) {
	//------------------------------------------------------------
	sqlite3_free(ptr)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
getSQLiteColumnsTable :: proc(
	self: ^Self,
	sql: cstring,
	allocator: mem.Allocator = context.allocator,
) -> (
	^SQLiteColumnsTable,
	Error,
) {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		return nil, returnError(self, SQLITE_MISUSE, "invalid db_handle", .InvalidDBHandle)
	}
	//------------------------------------------------------------
	stmt_handle: ^rawptr = nil
	//------------------------------------------------------------
	rc := sqlite3_prepare_v2(self.db_handle, sql, -1, &stmt_handle, nil)
	if rc != SQLITE_OK {
		return nil, returnError(self, rc, sqliteErrmsg(self), .SQLitePrepareError)
	}
	//------------------------------------------------------------
	defer _ = sqlite3_finalize(stmt_handle)
	//------------------------------------------------------------
	arena_ptr, arena_err := new(virtual.Arena, allocator)
	if arena_err != nil {
		return nil, returnError(self, SQLITE_NOMEM, "alloc error: arena_ptr", arena_err)
	}
	arena_allocator := virtual.arena_allocator(arena_ptr)
	//------------------------------------------------------------
	table, table_err := new(SQLiteColumnsTable, arena_allocator)
	if table_err != nil {
		return nil, returnError(self, SQLITE_NOMEM, "alloc error: table", table_err)
	}
	table.allocator = allocator
	table.arena_ptr = arena_ptr
	context.allocator = arena_allocator
	//------------------------------------------------------------
	table.column_count = int(sqlite3_column_count(stmt_handle))
	if table.column_count == 0 do return table, nil
	//------------------------------------------------------------
	column_name_ptrs, make_err := make(map[cstring]rawptr, table.column_count, arena_allocator)
	if make_err != nil {
		return returnSQLiteColumnsTableError(
			self,
			table,
			SQLITE_NOMEM,
			"alloc error: column_name_ptrs",
			make_err,
		)
	}
	//------------------------------------------------------------
	table.row_count = 0
	//------------------------------------------------------------
	for {
		//------------------------------------------------------------
		step_rc := sqlite3_step(stmt_handle)
		//------------------------------------------------------------
		if step_rc == SQLITE_ROW {
			//------------------------------------------------------------
			for column_index in 0 ..< table.column_count {
				//------------------------------------------------------------
				sqlite_column := SQLiteColumn{}
				//------------------------------------------------------------
				update_err := updateSQLiteColumn(self, stmt_handle, column_index, &sqlite_column)
				if update_err != nil {
					return returnSQLiteColumnsTableError(
						self,
						table,
						SQLITE_ERROR,
						"updateSQLiteColumn error",
						update_err,
					)
				}
				//------------------------------------------------------------
				name_ptr: rawptr
				if column_name_ptr, ok := column_name_ptrs[sqlite_column.name]; ok {
					name_ptr = column_name_ptr
				} else {
					//----------------------------------------
					name_len := len(sqlite_column.name)
					//----------------------------------------
					name_data, make_err := make([]u8, name_len + 1, arena_allocator)
					if make_err != nil {
						return returnSQLiteColumnsTableError(
							self,
							table,
							SQLITE_NOMEM,
							"alloc error: name_data",
							make_err,
						)
					}
					//----------------------------------------
					name_ptr = raw_data(name_data)
					//----------------------------------------
					mem.copy(name_ptr, cast(rawptr)sqlite_column.name, name_len)
					column_name_ptrs[sqlite_column.name] = name_ptr
					//----------------------------------------
				}
				sqlite_column.name = cast(cstring)name_ptr
				//------------------------------------------------------------
				if sqlite_column.column_type == .SQLITE_TEXT ||
				   sqlite_column.column_type == .SQLITE_BLOB {
					//----------------------------------------
					field_data, make_err := make([]u8, sqlite_column.len, arena_allocator)
					if make_err != nil {
						return returnSQLiteColumnsTableError(
							self,
							table,
							SQLITE_NOMEM,
							"alloc error: field_data",
							make_err,
						)
					}
					//----------------------------------------
					mem.copy(raw_data(field_data), sqlite_column.ptr, sqlite_column.len)
					sqlite_column.ptr = raw_data(field_data)
					//----------------------------------------
				}
				//------------------------------------------------------------
				append(&table.sqlite_columns, sqlite_column)
				//------------------------------------------------------------
			}
			//------------------------------------------------------------
			table.row_count += 1
			//------------------------------------------------------------
		} else if step_rc == SQLITE_DONE {
			//------------------------------------------------------------
			break
			//------------------------------------------------------------
		} else {
			//------------------------------------------------------------
			return returnSQLiteColumnsTableError(
				self,
				table,
				step_rc,
				"sqlite step error",
				.SQLiteStepError,
			)
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	return table, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
returnSQLiteColumnsTableError :: proc(
	self: ^Self,
	table: ^SQLiteColumnsTable,
	rc: i32,
	errmsg: cstring,
	err: Error,
) -> (
	^SQLiteColumnsTable,
	Error,
) {
	//------------------------------------------------------------
	freeSQLiteColumnsTable(self, table)
	//------------------------------------------------------------
	return nil, returnError(self, rc, errmsg, err)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
freeSQLiteColumnsTable :: proc(self: ^Self, table: ^SQLiteColumnsTable) {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if table == nil do return
	//------------------------------------------------------------
	allocator := table.allocator
	arena_ptr := table.arena_ptr
	//------------------------------------------------------------
	table^ = SQLiteColumnsTable{}
	virtual.arena_destroy(arena_ptr)
	mem.free(arena_ptr, allocator)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
querySQLiteColumns :: proc(
	self: ^Self,
	sql: cstring,
	callback: proc "c" (ctx: rawptr, columns_ptr: [^]SQLiteColumn, column_count: i32) -> i32,
	ctx: rawptr,
) -> Error {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		return returnError(self, SQLITE_MISUSE, "invalid db_handle", .InvalidDBHandle)
	}
	//------------------------------------------------------------
	if sql == nil || len(sql) == 0 {
		return returnError(self, SQLITE_ERROR, "invalid sqlite query", .InvalidSQLiteQuery)
	}
	//------------------------------------------------------------
	stmt_handle: ^rawptr = nil
	//------------------------------------------------------------
	rc := sqlite3_prepare_v2(self.db_handle, sql, -1, &stmt_handle, nil)
	if rc != SQLITE_OK {
		return returnError(self, rc, sqliteErrmsg(self), .SQLitePrepareError)
	}
	//------------------------------------------------------------
	defer _ = sqlite3_finalize(stmt_handle)
	//------------------------------------------------------------
	column_count := int(sqlite3_column_count(stmt_handle))
	if column_count == 0 {
		return returnError(self, SQLITE_ERROR, sqliteErrmsg(self), .ZeroColumnCount)
	}
	//------------------------------------------------------------
	sqlite_columns, make_err := make([]SQLiteColumn, column_count, context.temp_allocator)
	if make_err != nil {
		return returnError(self, SQLITE_NOMEM, "alloc error: sqlite_columns", make_err)
	}
	defer delete(sqlite_columns, context.temp_allocator)
	//------------------------------------------------------------
	for {
		//------------------------------------------------------------
		step_rc := sqlite3_step(stmt_handle)
		//------------------------------------------------------------
		if step_rc == SQLITE_ROW {
			//------------------------------------------------------------
			if callback != nil {
				//------------------------------------------------------------
				for column_index in 0 ..< column_count {
					//----------------------------------------
					sqlite_columns[column_index] = {}
					//----------------------------------------
					err := updateSQLiteColumn(
						self,
						stmt_handle,
						column_index,
						&sqlite_columns[column_index],
					)
					if err != nil {
						return returnError(self, SQLITE_ERROR, "updateSQLiteColumn error", err)
					}
					//----------------------------------------
				}
				//------------------------------------------------------------
				return_code := callback(ctx, raw_data(sqlite_columns), i32(column_count))
				if return_code != SQLITE_OK {
					return returnError(self, return_code, "callback aborted", .CallbackAborted)
				}
				//------------------------------------------------------------
			}
			//------------------------------------------------------------
		} else if step_rc == SQLITE_DONE {
			//------------------------------------------------------------
			break
			//------------------------------------------------------------
		} else {
			//------------------------------------------------------------
			return returnError(self, step_rc, "sqlite step error", .SQLiteStepError)
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	return nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
getTableRowCount :: proc(self: ^Self, table_name: cstring) -> (int, Error) {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		return 0, returnError(self, SQLITE_MISUSE, "invalid db_handle", .InvalidDBHandle)
	}
	//------------------------------------------------------------
	stmt_handle: ^rawptr = nil
	//------------------------------------------------------------
	buffer: [MAX_TABLE_NAME + 1]u8
	_ = fmt.bprintf(buffer[:], "SELECT COUNT(*) FROM %s;", table_name)
	//------------------------------------------------------------
	rc := sqlite3_prepare_v2(self.db_handle, cstring(&buffer[0]), -1, &stmt_handle, nil)
	if rc != SQLITE_OK {
		return 0, returnError(self, rc, sqliteErrmsg(self), .SQLitePrepareError)
	}
	//------------------------------------------------------------
	defer sqlite3_finalize(stmt_handle)
	//------------------------------------------------------------
	step_rc := sqlite3_step(stmt_handle)
	if step_rc != SQLITE_ROW {
		return 0, returnError(self, step_rc, sqliteErrmsg(self), .SQLiteStepError)
	}
	//------------------------------------------------------------
	return int(sqlite3_column_int64(stmt_handle, 0)), nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
getRowCount :: proc(self: ^Self, sql: cstring) -> (int, Error) {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		return 0, returnError(self, SQLITE_MISUSE, "invalid db_handle", .InvalidDBHandle)
	}
	//------------------------------------------------------------
	stmt_handle: ^rawptr = nil
	//------------------------------------------------------------
	rc := sqlite3_prepare_v2(self.db_handle, sql, -1, &stmt_handle, nil)
	if rc != SQLITE_OK {
		return 0, returnError(self, rc, sqliteErrmsg(self), .SQLitePrepareError)
	}
	//------------------------------------------------------------
	defer sqlite3_finalize(stmt_handle)
	//------------------------------------------------------------
	row_count := 0
	//------------------------------------------------------------
	for {
		step_rc := sqlite3_step(stmt_handle)
		if step_rc == SQLITE_ROW {row_count += 1; continue}
		if step_rc == SQLITE_DONE {break}
		return 0, returnError(self, step_rc, sqliteErrmsg(self), .SQLiteStepError)
	}
	//------------------------------------------------------------
	return row_count, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
getColumnCount :: proc(self: ^Self, sql: cstring) -> (int, Error) {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		return 0, returnError(self, SQLITE_MISUSE, "invalid db_handle", .InvalidDBHandle)
	}
	//------------------------------------------------------------
	stmt_handle: ^rawptr = nil
	//------------------------------------------------------------
	rc := sqlite3_prepare_v2(self.db_handle, sql, -1, &stmt_handle, nil)
	if rc != SQLITE_OK {
		return 0, returnError(self, rc, sqliteErrmsg(self), .SQLitePrepareError)
	}
	//------------------------------------------------------------
	defer sqlite3_finalize(stmt_handle)
	//------------------------------------------------------------
	step_rc := sqlite3_step(stmt_handle)
	if step_rc != SQLITE_ROW {
		return 0, returnError(self, step_rc, sqliteErrmsg(self), .SQLiteStepError)
	}
	//------------------------------------------------------------
	return int(sqlite3_column_count(stmt_handle)), nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
updateSQLiteColumn :: proc(
	self: ^Self,
	stmt_handle: ^rawptr,
	index: int,
	column: ^SQLiteColumn,
) -> Error {
	//------------------------------------------------------------
	clearErrorMessage(self)
	//------------------------------------------------------------
	if self.db_handle == nil {
		return returnError(self, SQLITE_MISUSE, "invalid db_handle", .InvalidDBHandle)
	}
	//------------------------------------------------------------
	if stmt_handle == nil {
		return returnError(self, SQLITE_MISUSE, "invalid stmt_handle", .InvalidStmtHandle)
	}
	//------------------------------------------------------------
	iCol := i32(index)
	//------------------------------------------------------------
	name := cstring(sqlite3_column_name(stmt_handle, iCol))
	//------------------------------------------------------------
	column_type: SQLiteColumnType = SQLiteColumnType(sqlite3_column_type(stmt_handle, iCol))
	//------------------------------------------------------------
	ptr := cast([^]u8)(sqlite3_column_blob(stmt_handle, iCol))
	len := int(sqlite3_column_bytes(stmt_handle, iCol))
	integer := sqlite3_column_int64(stmt_handle, iCol)
	float := sqlite3_column_double(stmt_handle, iCol)
	//------------------------------------------------------------
	column^ = SQLiteColumn {
		index       = index,
		name        = name,
		column_type = column_type,
		ptr         = ptr,
		len         = len,
		integer     = integer,
		float       = float,
	}
	//------------------------------------------------------------
	return nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
updateRow :: proc(
	struct_instance: ^$T,
	columns: []SQLiteColumn,
	allocator := context.allocator,
) -> (
	err: Error,
) {
	//------------------------------------------------------------
	for column in columns {
		//------------------------------------------------------------
		switch column.column_type {
		case .SQLITE_UNKNOWN:
			err = .UnknownColumnType

		case .SQLITE_INTEGER:
			err = setStructFieldValue(struct_instance, string(column.name), column.integer)

		case .SQLITE_FLOAT:
			err = setStructFieldValue(struct_instance, string(column.name), column.float)

		case .SQLITE_TEXT:
			text_bytes := make([]u8, int(column.len), allocator) or_return
			copy(text_bytes, (cast([^]u8)column.ptr)[:int(column.len)])
			err = setStructFieldValue(struct_instance, string(column.name), string(text_bytes))

		case .SQLITE_BLOB:
			blob := make([]u8, int(column.len), allocator) or_return
			copy(blob, (cast([^]u8)column.ptr)[:int(column.len)])
			err = setStructFieldValue(struct_instance, string(column.name), blob)

		case .SQLITE_NULL:
			err = setStructFieldValue(struct_instance, string(column.name), nil)
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	return err
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
updateRowMap :: proc(
	row: ^map[string]ColumnValue,
	columns: []SQLiteColumn,
	allocator: mem.Allocator = context.allocator,
) -> (
	err: Error,
) {
	//------------------------------------------------------------
	for column in columns {
		//------------------------------------------------------------
		key := string(column.name)
		//------------------------------------------------------------
		switch column.column_type {
		case .SQLITE_UNKNOWN:
			err = .UnknownColumnType

		case .SQLITE_INTEGER:
			row[key] = column.integer

		case .SQLITE_FLOAT:
			row[key] = column.float

		case .SQLITE_TEXT:
			text_bytes := make([]u8, int(column.len), allocator) or_return
			copy(text_bytes, (cast([^]u8)column.ptr)[:int(column.len)])
			row[key] = string(text_bytes)

		case .SQLITE_BLOB:
			blob := make([]u8, int(column.len), allocator) or_return
			copy(blob, (cast([^]u8)column.ptr)[:int(column.len)])
			row[key] = blob

		case .SQLITE_NULL:
			row[key] = nil
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	return err
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
setStructFieldValue :: proc(struct_instance: ^$T, field_name: string, value: any) -> Error {
	//----------------------------------------
	struct_field := reflect.struct_field_by_name(typeid_of(T), field_name)
	//----------------------------------------
	if struct_field.type == nil do return .FieldNotFound
	//----------------------------------------
	struct_field_ptr := rawptr(uintptr(struct_instance) + struct_field.offset)
	//----------------------------------------
	if value == nil || value.data == nil {
		//----------------------------------------
		mem.set(struct_field_ptr, 0, struct_field.type.size)
		//----------------------------------------
	} else {
		//----------------------------------------
		if struct_field.type.id != value.id do return .FieldTypeMismatch
		//----------------------------------------
		mem.copy(struct_field_ptr, value.data, struct_field.type.size)
		//----------------------------------------
	}
	//----------------------------------------
	return nil
	//----------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
checkTableName :: proc(table_name: cstring) -> bool {
	//------------------------------------------------------------
	table_name_ptr := cast([^]u8)table_name
	//------------------------------------------------------------
	if table_name_ptr == nil do return false
	if table_name_ptr[0] == 0 do return false
	//------------------------------------------------------------
	switch table_name_ptr[0] {
	case 'A' ..= 'Z', 'a' ..= 'z', '_':
	case:
		return false
	}
	//------------------------------------------------------------
	index: int = 1
	for table_name_ptr[index] != 0 {
		switch table_name_ptr[index] {
		case 'A' ..= 'Z', 'a' ..= 'z', '0' ..= '9', '_':
		case:
			return false
		}
		index += 1
	}
	//------------------------------------------------------------
	return true
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
i32Len :: proc(value: $T) -> i32 {return i32(len(value))}
u32Len :: proc(value: $T) -> u32 {return u32(len(value))}
i64Len :: proc(value: $T) -> i64 {return i64(len(value))}
u64Len :: proc(value: $T) -> u64 {return u64(len(value))}
//--------------------------------------------------------------------------------
ptrToBytes :: proc(ptr: [^]byte, #any_int len: int) -> []byte {return ptr[:len]}
rawptrToBytes :: proc(ptr: rawptr, #any_int len: int) -> []byte {return (cast([^]byte)ptr)[:len]}
//--------------------------------------------------------------------------------
bytesToString :: proc {
	bytesSliceToString,
	ptrToString,
	rawptrToString,
}
bytesSliceToString :: proc(b: []byte) -> string {
	return string(b)
}
ptrToString :: proc(ptr: ^[]byte, #any_int len: int) -> string {
	return ptr == nil ? "" : string(ptr[:len])
}
rawptrToString :: proc(ptr: rawptr, #any_int len: int) -> string {
	return ptr == nil ? "" : string((cast([^]byte)ptr)[:len])
}
//--------------------------------------------------------------------------------
bytesToCString :: proc {
	bytesSliceToCString,
	ptrToCString,
	rawptrToCString,
}
bytesSliceToCString :: proc(b: []byte) -> cstring {
	if len(b) == 0 do return nil
	b[len(b) - 1] = 0 // force last byte to be zero
	return cstring(&b[0])
}
ptrToCString :: proc(ptr: ^byte) -> cstring {
	return ptr == nil ? nil : cstring(ptr)
}
rawptrToCString :: proc(ptr: rawptr) -> cstring {
	return ptr == nil ? nil : cstring(ptr)
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
returnError :: proc(self: ^Self, rc: i32, errmsg: cstring, err: Error) -> Error {
	//------------------------------------------------------------
	setErrorMessage(self, rc, errmsg); return err
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
returnErrorCode :: proc(self: ^Self, rc: i32, errmsg: cstring) -> i32 {
	//------------------------------------------------------------
	setErrorMessage(self, rc, errmsg); return rc
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
clearErrorMessage :: proc(self: ^Self) {
	//------------------------------------------------------------
	self.rc = SQLITE_OK; for index in 0 ..< len(self.errmsg) {self.errmsg[index] = 0}
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
setErrorMessage :: proc(self: ^Self, rc: i32, errmsg: cstring) {
	//------------------------------------------------------------
	self.rc = rc
	//------------------------------------------------------------
	for index in 0 ..< len(self.errmsg) {self.errmsg[index] = 0}
	//------------------------------------------------------------
	if errmsg == nil do return
	//------------------------------------------------------------
	errmsg_ptr := cast([^]u8)errmsg
	for index in 0 ..< len(self.errmsg) - 1 {
		if errmsg_ptr[index] == 0 {break}
		self.errmsg[index] = errmsg_ptr[index]
	}
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
returnCode :: proc(self: ^Self) -> i32 {
	//------------------------------------------------------------
	return self.rc
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
errorMessage :: proc(self: ^Self) -> cstring {
	//------------------------------------------------------------
	return cstring(&self.errmsg[0])
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
foreign import sqlite "system:sqlite3"
foreign sqlite {
	//------------------------------------------------------------
	sqlite3_bind_blob :: proc "c" (stmt_handle: ^rawptr, iCol: i32, ptr: rawptr, len: i32, destructor_function: proc "c" (ptr: rawptr)) -> i32 ---
	sqlite3_bind_double :: proc "c" (stmt_handle: ^rawptr, iCol: i32, float: f64) -> i32 ---
	sqlite3_bind_int64 :: proc "c" (stmt_handle: ^rawptr, iCol: i32, integer: i64) -> i32 ---
	sqlite3_bind_null :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> i32 ---
	sqlite3_bind_text :: proc "c" (stmt_handle: ^rawptr, iCol: i32, ptr: rawptr, len: i32, destructor_function: proc "c" (ptr: rawptr)) -> i32 ---
	sqlite3_clear_bindings :: proc "c" (stmt_handle: ^rawptr) -> i32 ---
	sqlite3_close :: proc "c" (db_handle: ^rawptr) -> i32 ---
	sqlite3_column_blob :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> rawptr ---
	sqlite3_column_bytes :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> i32 ---
	sqlite3_column_count :: proc "c" (stmt_handle: ^rawptr) -> i32 ---
	sqlite3_column_double :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> f64 ---
	sqlite3_column_int64 :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> i64 ---
	sqlite3_column_name :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> rawptr ---
	sqlite3_column_text :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> rawptr ---
	sqlite3_column_type :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> i32 ---
	sqlite3_data_count :: proc "c" (stmt_handle: ^rawptr) -> i32 ---
	sqlite3_errmsg :: proc "c" (db_handle: ^rawptr) -> rawptr ---
	sqlite3_exec :: proc "c" (db_handle: ^rawptr, sql: cstring, callback: proc "c" (ctx_ptr: rawptr, argc: i32, argv: [^]cstring, azColName: [^]cstring) -> i32, arg: rawptr, errmsg: ^rawptr) -> i32 ---
	sqlite3_finalize :: proc "c" (stmt_handle: ^rawptr) -> i32 ---
	sqlite3_free :: proc "c" (ptr: rawptr) ---
	sqlite3_free_table :: proc "c" (results: [^]cstring) ---
	sqlite3_get_table :: proc "c" (db_handle: ^rawptr, sql: cstring, results: ^^cstring, row_count: ^i32, column_count: ^i32, errmsg: ^rawptr) -> i32 ---
	sqlite3_malloc64 :: proc "c" (size: u64) -> rawptr ---
	sqlite3_mprintf :: proc "c" (format: cstring, args: ..any) -> rawptr ---
	sqlite3_open :: proc "c" (filepath: cstring, db_handle: ^^rawptr) -> i32 ---
	sqlite3_prepare_v2 :: proc "c" (db_handle: ^rawptr, sql: cstring, nByte: i32, ppStmt: ^^rawptr, pzTail: ^^u8) -> i32 ---
	sqlite3_realloc64 :: proc "c" (ptr: rawptr, size: u64) -> rawptr ---
	sqlite3_reset :: proc "c" (stmt_handle: ^rawptr) -> i32 ---
	sqlite3_step :: proc "c" (stmt_handle: ^rawptr) -> i32 ---
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
SQLITE_INTEGER :: 1
SQLITE_FLOAT :: 2
SQLITE_TEXT :: 3
SQLITE_BLOB :: 4
SQLITE_NULL :: 5
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
