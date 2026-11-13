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
import "core:strings"
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
MAX_TABLE_NAME :: 256
//--------------------------------------------------------------------------------
Error :: union #shared_nil {
	SQLiteError,
	mem.Allocator_Error,
}
//--------------------------------------------------------------------------------
SQLiteError :: enum {
	None,
	CallbackAborted,
	FieldNotFound,
	FieldTypeMismatch,
	InvalidDBHandle,
	InvalidFieldCount,
	InvalidFieldName,
	InvalidFieldType,
	InvalidRowCount,
	InvalidRowType,
	InvalidSQLiteQuery,
	InvalidStmtHandle,
	InvalidTableName,
	SQLiteFinalizeError,
	SQLiteMalloc64Error,
	SQLiteOpenError,
	SQLitePrepareError,
	SQLiteStepError,
	UnknownColumnType,
	ZeroColumnCount,
	ZeroFieldCount,
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
sqliteBlobString :: proc(stmt_handle: ^rawptr, iCol: i32) -> string {
	ptr := sqlite3_column_blob(stmt_handle, iCol)
	if ptr == nil do return ""
	len := sqlite3_column_bytes(stmt_handle, iCol)
	return string((cast([^]u8)ptr)[:len])
}
//--------------------------------------------------------------------------------
sqliteBlobCString :: proc(stmt_handle: ^rawptr, iCol: i32) -> cstring {
	ptr := sqlite3_column_blob(stmt_handle, iCol)
	if ptr == nil do return ""
	return cstring(ptr)
}
//--------------------------------------------------------------------------------
sqliteTextString :: proc(stmt_handle: ^rawptr, iCol: i32) -> string {
	ptr := sqlite3_column_text(stmt_handle, iCol)
	if ptr == nil do return ""
	len := sqlite3_column_bytes(stmt_handle, iCol)
	return string((cast([^]u8)ptr)[:len])
}
//--------------------------------------------------------------------------------
sqliteTextCString :: proc(stmt_handle: ^rawptr, iCol: i32) -> cstring {
	ptr := sqlite3_column_text(stmt_handle, iCol)
	return ptr == nil ? "" : cstring(ptr)
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
isUnsigned :: proc(stmt_handle: ^rawptr, iCol: i32) -> bool {
	//------------------------------------------------------------
	decl_type_ptr := sqlite3_column_decltype(stmt_handle, iCol)
	//------------------------------------------------------------
	if decl_type_ptr == nil do return false
	//------------------------------------------------------------
	decl_type := string(decl_type_ptr)
	toLower(&decl_type)
	//------------------------------------------------------------
	if strings.contains(decl_type, "unsigned") do return true
	//------------------------------------------------------------
	return false
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
toLower :: proc(data: ^string) {
	//------------------------------------------------------------
	bytes := transmute([]u8)data^
	for index in 0 ..< len(bytes) {
		switch bytes[index] {
		case 'A' ..= 'Z':
			bytes[index] += 32
		}
	}
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
	db_handle: ^rawptr,
	sql: cstring,
	allocator: mem.Allocator = context.allocator,
) -> (
	^SQLiteColumnsTable,
	Error,
) {
	//------------------------------------------------------------
	if db_handle == nil do return nil, .InvalidDBHandle
	//------------------------------------------------------------
	stmt_handle: ^rawptr = nil
	//------------------------------------------------------------
	rc := sqlite3_prepare_v2(db_handle, sql, -1, &stmt_handle, nil)
	if rc != SQLITE_OK do return nil, .SQLitePrepareError
	//------------------------------------------------------------
	defer _ = sqlite3_finalize(stmt_handle)
	//------------------------------------------------------------
	arena_ptr, arena_err := new(virtual.Arena, allocator)
	if arena_err != nil do return nil, arena_err
	arena_allocator := virtual.arena_allocator(arena_ptr)
	//------------------------------------------------------------
	table, table_err := new(SQLiteColumnsTable, arena_allocator)
	if table_err != nil do return nil, table_err
	table.allocator = allocator
	table.arena_ptr = arena_ptr
	context.allocator = arena_allocator
	//------------------------------------------------------------
	table.column_count = int(sqlite3_column_count(stmt_handle))
	if table.column_count == 0 do return table, nil
	//------------------------------------------------------------
	column_name_ptrs, make_err := make(map[cstring]rawptr, table.column_count, arena_allocator)
	if make_err != nil do return returnSQLiteColumnsTableError(table, make_err)
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
				update_err := updateSQLiteColumn(stmt_handle, column_index, &sqlite_column)
				if update_err != nil do return returnSQLiteColumnsTableError(table, update_err)
				//------------------------------------------------------------
				name_ptr: rawptr
				if column_name_ptr, ok := column_name_ptrs[sqlite_column.name]; ok {
					name_ptr = column_name_ptr
				} else {
					//----------------------------------------
					name_len := len(sqlite_column.name)
					//----------------------------------------
					name_data, make_err := make([]u8, name_len + 1, arena_allocator)
					if make_err != nil do return returnSQLiteColumnsTableError(table, make_err)
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
					if make_err != nil do return returnSQLiteColumnsTableError(table, make_err)
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
			return returnSQLiteColumnsTableError(table, .SQLiteStepError)
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
	table: ^SQLiteColumnsTable,
	err: Error,
) -> (
	^SQLiteColumnsTable,
	Error,
) {
	//------------------------------------------------------------
	freeSQLiteColumnsTable(table)
	//------------------------------------------------------------
	return nil, err
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
freeSQLiteColumnsTable :: proc(table: ^SQLiteColumnsTable) {
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
	db_handle: ^rawptr,
	sql: cstring,
	callback: proc "c" (ctx: rawptr, columns_ptr: [^]SQLiteColumn, column_count: i32) -> i32,
	ctx: rawptr,
) -> Error {
	//------------------------------------------------------------
	if db_handle == nil do return .InvalidDBHandle
	//------------------------------------------------------------
	if sql == nil || len(sql) == 0 do return .InvalidSQLiteQuery
	//------------------------------------------------------------
	stmt_handle: ^rawptr = nil
	//------------------------------------------------------------
	rc := sqlite3_prepare_v2(db_handle, sql, -1, &stmt_handle, nil)
	if rc != SQLITE_OK do return .SQLitePrepareError
	//------------------------------------------------------------
	defer _ = sqlite3_finalize(stmt_handle)
	//------------------------------------------------------------
	column_count := int(sqlite3_column_count(stmt_handle))
	if column_count == 0 do return .ZeroColumnCount
	//------------------------------------------------------------
	sqlite_columns, make_err := make([]SQLiteColumn, column_count, context.temp_allocator)
	if make_err != nil do return make_err
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
						stmt_handle,
						column_index,
						&sqlite_columns[column_index],
					)
					if err != nil do return err
					//----------------------------------------
				}
				//------------------------------------------------------------
				return_code := callback(ctx, raw_data(sqlite_columns), i32(column_count))
				if return_code != SQLITE_OK do return .CallbackAborted
				//------------------------------------------------------------
			}
			//------------------------------------------------------------
		} else if step_rc == SQLITE_DONE {
			//------------------------------------------------------------
			break
			//------------------------------------------------------------
		} else {
			//------------------------------------------------------------
			return .SQLiteStepError
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
updateSQLiteColumn :: proc(
	stmt_handle: ^rawptr,
	index: int,
	sqlite_column: ^SQLiteColumn,
) -> Error {
	//------------------------------------------------------------
	if stmt_handle == nil do return .InvalidStmtHandle
	//------------------------------------------------------------
	iCol := i32(index)
	//------------------------------------------------------------
	name := sqlite3_column_name(stmt_handle, iCol)
	//------------------------------------------------------------
	column_type: SQLiteColumnType = SQLiteColumnType(sqlite3_column_type(stmt_handle, iCol))
	//------------------------------------------------------------
	ptr := cast([^]u8)(sqlite3_column_blob(stmt_handle, iCol))
	len := int(sqlite3_column_bytes(stmt_handle, iCol))
	integer := sqlite3_column_int64(stmt_handle, iCol)
	float := sqlite3_column_double(stmt_handle, iCol)
	//------------------------------------------------------------
	is_unsigned := isUnsigned(stmt_handle, iCol)
	//------------------------------------------------------------
	sqlite_column^ = SQLiteColumn {
		index       = index,
		name        = name,
		column_type = column_type,
		is_unsigned = is_unsigned,
		integer     = integer,
		float       = float,
		ptr         = ptr,
		len         = len,
	}
	//------------------------------------------------------------
	return nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
getSQLiteRow :: proc(
	stmt_handle: ^rawptr,
	row: ^$T,
	allocator: mem.Allocator = context.allocator,
) -> Error {
	//------------------------------------------------------------
	if stmt_handle == nil do return .InvalidStmtHandle
	//------------------------------------------------------------
	type_id := typeid_of(T)
	//------------------------------------------------------------
	field_count := reflect.struct_field_count(type_id)
	if field_count == 0 do return .ZeroFieldCount
	//------------------------------------------------------------
	column_count := int(sqlite3_column_count(stmt_handle))
	if column_count == 0 do return .ZeroColumnCount
	//----------------------------------------------------
	// if field_count != column_count do return .InvalidFieldCount
	//------------------------------------------------------------
	for index := 0; index < column_count; index += 1 {
		//------------------------------------------------------------
		iCol := i32(index)
		//------------------------------------------------------------
		name_ptr := sqlite3_column_name(stmt_handle, iCol)
		name := name_ptr != nil ? string(name_ptr) : ""
		//------------------------------------------------------------
		field := reflect.struct_field_by_name(type_id, name)
		//------------------------------------------------------------
		if field.name == name {
			//------------------------------------------------------------
			integer := sqlite3_column_int64(stmt_handle, iCol)
			float := sqlite3_column_double(stmt_handle, iCol)
			ptr := cast([^]u8)(sqlite3_column_blob(stmt_handle, iCol))
			len := int(sqlite3_column_bytes(stmt_handle, iCol))
			//------------------------------------------------------------
			uint64 := transmute(u64)integer
			//------------------------------------------------------------
			dst := rawptr(uintptr(row) + field.offset)
			//------------------------------------------------------------
			switch field.type.id {
			case typeid_of(u64):
				(^u64)(dst)^ = uint64
			case typeid_of(i64):
				(^i64)(dst)^ = integer
			case typeid_of(f64):
				(^f64)(dst)^ = float
			case typeid_of(string):
				string_bytes := make([]u8, len, allocator) or_return
				copy(string_bytes, (cast([^]u8)ptr)[:len])
				(^[]u8)(dst)^ = string_bytes
			case typeid_of([]u8):
				blob_bytes := make([]u8, len, allocator) or_return
				copy(blob_bytes, (cast([^]u8)ptr)[:len])
				(^[]u8)(dst)^ = blob_bytes
			case:
				return .InvalidFieldType
			}
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
getTableRowCount :: proc(db_handle: ^rawptr, table_name: cstring) -> (int, Error) {
	//------------------------------------------------------------
	if db_handle == nil do return 0, .InvalidDBHandle
	//------------------------------------------------------------
	stmt_handle: ^rawptr = nil
	//------------------------------------------------------------
	buffer: [MAX_TABLE_NAME + 1]u8
	_ = fmt.bprintf(buffer[:], "SELECT COUNT(*) FROM %s;", table_name)
	//------------------------------------------------------------
	rc := sqlite3_prepare_v2(db_handle, cstring(&buffer[0]), -1, &stmt_handle, nil)
	if rc != SQLITE_OK do return 0, .SQLitePrepareError
	//------------------------------------------------------------
	defer sqlite3_finalize(stmt_handle)
	//------------------------------------------------------------
	step_rc := sqlite3_step(stmt_handle)
	if step_rc != SQLITE_ROW do return 0, .SQLiteStepError
	//------------------------------------------------------------
	return int(sqlite3_column_int64(stmt_handle, 0)), nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
getRowCount :: proc(db_handle: ^rawptr, sql: cstring) -> (int, Error) {
	//------------------------------------------------------------
	if db_handle == nil do return 0, .InvalidDBHandle
	//------------------------------------------------------------
	stmt_handle: ^rawptr = nil
	//------------------------------------------------------------
	rc := sqlite3_prepare_v2(db_handle, sql, -1, &stmt_handle, nil)
	if rc != SQLITE_OK do return 0, .SQLitePrepareError
	//------------------------------------------------------------
	defer sqlite3_finalize(stmt_handle)
	//------------------------------------------------------------
	row_count := 0
	//------------------------------------------------------------
	for {
		step_rc := sqlite3_step(stmt_handle)
		if step_rc == SQLITE_ROW {row_count += 1; continue}
		if step_rc == SQLITE_DONE {break}
		return 0, .SQLiteStepError
	}
	//------------------------------------------------------------
	return row_count, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
getColumnCount :: proc(db_handle: ^rawptr, sql: cstring) -> (int, Error) {
	//------------------------------------------------------------
	if db_handle == nil do return 0, .InvalidDBHandle
	//------------------------------------------------------------
	stmt_handle: ^rawptr = nil
	//------------------------------------------------------------
	rc := sqlite3_prepare_v2(db_handle, sql, -1, &stmt_handle, nil)
	if rc != SQLITE_OK do return 0, .SQLitePrepareError
	//------------------------------------------------------------
	defer sqlite3_finalize(stmt_handle)
	//------------------------------------------------------------
	step_rc := sqlite3_step(stmt_handle)
	if step_rc != SQLITE_ROW do return 0, .SQLiteStepError
	//------------------------------------------------------------
	return int(sqlite3_column_count(stmt_handle)), nil
	//------------------------------------------------------------
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
updateRow :: proc(
	row: ^$T,
	sqlite_columns: []SQLiteColumn,
	allocator := context.allocator,
) -> (
	err: Error,
) {
	//------------------------------------------------------------
	type_id := typeid_of(T)
	//------------------------------------------------------------
	// field_count := reflect.struct_field_count(type_id)
	// if field_count != len(sqlite_columns) do return .InvalidFieldCount
	//------------------------------------------------------------
	for index := 0; index < len(sqlite_columns); index += 1 {
		//------------------------------------------------------------
		sqlite_column := &sqlite_columns[index]
		//------------------------------------------------------------
		name := string(sqlite_column.name)
		//------------------------------------------------------------
		field := reflect.struct_field_by_name(type_id, name)
		//------------------------------------------------------------
		if field.name == name {
			//------------------------------------------------------------
			dst := rawptr(uintptr(row) + field.offset)
			//------------------------------------------------------------
			switch field.type.id {
			case typeid_of(u64):
				(^u64)(dst)^ = transmute(u64)sqlite_column.integer
			case typeid_of(i64):
				(^i64)(dst)^ = sqlite_column.integer
			case typeid_of(f64):
				(^f64)(dst)^ = sqlite_column.float
			case typeid_of(string):
				string_bytes := make([]u8, sqlite_column.len, allocator) or_return
				copy(string_bytes, (cast([^]u8)sqlite_column.ptr)[:sqlite_column.len])
				(^[]u8)(dst)^ = string_bytes
			case typeid_of([]u8):
				blob_bytes := make([]u8, sqlite_column.len, allocator) or_return
				copy(blob_bytes, (cast([^]u8)sqlite_column.ptr)[:sqlite_column.len])
				(^[]u8)(dst)^ = blob_bytes
			case:
				err = .InvalidFieldType
			}
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	return err
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
updateRowMap :: proc(
	row_map: ^map[string]SQLiteColumnValue,
	sqlite_columns: []SQLiteColumn,
	allocator: mem.Allocator = context.allocator,
) -> (
	err: Error,
) {
	//------------------------------------------------------------
	for sqlite_column in sqlite_columns {
		//------------------------------------------------------------
		key := string(sqlite_column.name)
		//------------------------------------------------------------
		switch sqlite_column.column_type {
		case .SQLITE_UNKNOWN:
			err = .UnknownColumnType

		case .SQLITE_INTEGER:
			row_map[key] =
				sqlite_column.is_unsigned ? transmute(u64)sqlite_column.integer : sqlite_column.integer

		case .SQLITE_FLOAT:
			row_map[key] = sqlite_column.float

		case .SQLITE_TEXT:
			string_bytes := make([]u8, sqlite_column.len, allocator) or_return
			copy(string_bytes, (cast([^]u8)sqlite_column.ptr)[:sqlite_column.len])
			row_map[key] = string(string_bytes)

		case .SQLITE_BLOB:
			blob_bytes := make([]u8, sqlite_column.len, allocator) or_return
			copy(blob_bytes, (cast([^]u8)sqlite_column.ptr)[:sqlite_column.len])
			row_map[key] = blob_bytes

		case .SQLITE_NULL:
			row_map[key] = nil

		case:
			err = .UnknownColumnType
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	return err
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
i32Len :: proc(value: $T) -> i32 {return i32(len(value))}
u32Len :: proc(value: $T) -> u32 {return u32(len(value))}
i64Len :: proc(value: $T) -> i64 {return i64(len(value))}
u64Len :: proc(value: $T) -> u64 {return u64(len(value))}
//--------------------------------------------------------------------------------
ptrToBytes :: proc(ptr: [^]u8, #any_int len: int) -> []u8 {return ptr[:len]}
rawptrToBytes :: proc(ptr: rawptr, #any_int len: int) -> []u8 {return (cast([^]u8)ptr)[:len]}
cstringToBytes :: proc(ptr: cstring, #any_int len: int = 0) -> []u8 {
	if ptr == nil do return []u8{}
	bytes_len := int(len)
	bytes := cast([^]u8)ptr
	if len == 0 do for bytes[bytes_len] != 0 do bytes_len += 1
	return bytes[:bytes_len]
}
//--------------------------------------------------------------------------------
stringToBytes :: proc(s: string) -> []u8 {return transmute([]u8)s}
//--------------------------------------------------------------------------------
bytesToString :: proc {
	bytesSliceToString,
	ptrToString,
	rawptrToString,
}
bytesSliceToString :: proc(b: []u8) -> string {
	return string(b)
}
ptrToString :: proc(ptr: ^[]u8, #any_int len: int) -> string {
	return ptr == nil ? "" : string(ptr[:len])
}
rawptrToString :: proc(ptr: rawptr, #any_int len: int) -> string {
	return ptr == nil ? "" : string((cast([^]u8)ptr)[:len])
}
//--------------------------------------------------------------------------------
bytesToCString :: proc {
	bytesSliceToCString,
	ptrToCString,
	rawptrToCString,
}
bytesSliceToCString :: proc(b: []u8) -> cstring {
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
foreign import sqlite "system:sqlite3"
foreign sqlite {
	//------------------------------------------------------------
	sqlite3_bind_blob :: proc "c" (stmt_handle: ^rawptr, iCol: i32, ptr: rawptr, len: i32, destructor_function: proc "c" (ptr: rawptr)) -> i32 ---
	sqlite3_bind_double :: proc "c" (stmt_handle: ^rawptr, iCol: i32, float: f64) -> i32 ---
	sqlite3_bind_int :: proc "c" (stmt_handle: ^rawptr, iCol: i32, int32: i32) -> i32 ---
	sqlite3_bind_int64 :: proc "c" (stmt_handle: ^rawptr, iCol: i32, int64: i64) -> i32 ---
	sqlite3_bind_null :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> i32 ---
	sqlite3_bind_text :: proc "c" (stmt_handle: ^rawptr, iCol: i32, ptr: rawptr, len: i32, destructor_function: proc "c" (ptr: rawptr)) -> i32 ---
	sqlite3_clear_bindings :: proc "c" (stmt_handle: ^rawptr) -> i32 ---
	sqlite3_close :: proc "c" (db_handle: ^rawptr) -> i32 ---
	sqlite3_column_blob :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> rawptr ---
	sqlite3_column_bytes :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> i32 ---
	sqlite3_column_count :: proc "c" (stmt_handle: ^rawptr) -> i32 ---
	sqlite3_column_decltype :: proc(stmt_handle: ^rawptr, iCol: i32) -> cstring ---
	sqlite3_column_double :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> f64 ---
	sqlite3_column_int :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> i32 ---
	sqlite3_column_int64 :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> i64 ---
	sqlite3_column_name :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> cstring ---
	sqlite3_column_text :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> cstring ---
	sqlite3_column_type :: proc "c" (stmt_handle: ^rawptr, iCol: i32) -> i32 ---
	sqlite3_data_count :: proc "c" (stmt_handle: ^rawptr) -> i32 ---
	sqlite3_errmsg :: proc "c" (db_handle: ^rawptr) -> cstring ---
	sqlite3_exec :: proc "c" (db_handle: ^rawptr, sql: cstring, callback: proc "c" (ctx_ptr: rawptr, argc: i32, argv: [^]cstring, azColName: [^]cstring) -> i32, arg: rawptr, errmsg: ^rawptr) -> i32 ---
	sqlite3_finalize :: proc "c" (stmt_handle: ^rawptr) -> i32 ---
	sqlite3_free :: proc "c" (ptr: rawptr) ---
	sqlite3_free_table :: proc "c" (results: [^]cstring) ---
	sqlite3_get_table :: proc "c" (db_handle: ^rawptr, sql: cstring, results: ^^cstring, row_count: ^i32, column_count: ^i32, errmsg: ^rawptr) -> i32 ---
	sqlite3_malloc64 :: proc "c" (size: u64) -> rawptr ---
	sqlite3_mprintf :: proc "c" (format: cstring, args: ..any) -> rawptr ---
	sqlite3_open :: proc "c" (filepath: cstring, db_handle: ^^rawptr) -> i32 ---
	sqlite3_prepare_v2 :: proc "c" (db_handle: ^rawptr, sql: cstring, nByte: i32, ppStmt: ^^rawptr, pzTail: ^cstring) -> i32 ---
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
	is_unsigned: bool,
	integer:     i64,
	float:       f64,
	ptr:         [^]u8,
	len:         int,
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
//--------------------------------------------------------------------------------
SQLiteColumnValue :: union {
	//----------------------------------------
	null,
	u64,
	i64,
	f64,
	string,
	[]u8,
	//----------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
