//--------------------------------------------------------------------------------
// Copyright 2026, Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//--------------------------------------------------------------------------------
package mysql
//--------------------------------------------------------------------------------

import "core:bytes"
import "core:mem"
import "core:mem/virtual"
import "core:reflect"
import "core:strings"
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
Error :: union #shared_nil {
	MySQLError,
	mem.Allocator_Error,
}
//--------------------------------------------------------------------------------
MySQLError :: enum {
	None,
	AllocError,
	PrepareError,
	ExecuteError,
	FetchError,
	FetchColumnError,
	FetchFieldError,
	MetadataResultError,
	FieldNotFound,
	FieldTypeMismatch,
	InvalidBuffer,
	InvalidDBHandle,
	InvalidStmtHandle,
	UnknownColumnType,
	ZeroColumnCount,
	ZeroFieldCount,
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
bindColumn :: proc(bind: ^MySQLBind = {}) -> MYSQL_BIND {
	//------------------------------------------------------------
	if bind == nil do return MYSQL_BIND{buffer_type = .MYSQL_TYPE_NULL}
	//------------------------------------------------------------
	mysql_bind := MYSQL_BIND {
		//----------------------------------------
		buffer        = bind.buffer,
		//----------------------------------------
		buffer_length = bind.length,
		//----------------------------------------
		length        = &bind.length,
		is_null       = &bind.is_null,
		error         = &bind.error,
		//----------------------------------------
	}
	//------------------------------------------------------------
	switch bind.type_id {
	case u8:
		mysql_bind.buffer_type = .MYSQL_TYPE_TINY
		mysql_bind.is_unsigned = true
	case i8:
		mysql_bind.buffer_type = .MYSQL_TYPE_TINY
	case u16:
		mysql_bind.buffer_type = .MYSQL_TYPE_SHORT
		mysql_bind.is_unsigned = true
	case i16:
		mysql_bind.buffer_type = .MYSQL_TYPE_SHORT
	case u32:
		mysql_bind.buffer_type = .MYSQL_TYPE_LONG
		mysql_bind.is_unsigned = true
	case i32:
		mysql_bind.buffer_type = .MYSQL_TYPE_LONG
	case u64:
		mysql_bind.buffer_type = .MYSQL_TYPE_LONGLONG
		mysql_bind.is_unsigned = true
	case i64:
		mysql_bind.buffer_type = .MYSQL_TYPE_LONGLONG
	case f32:
		mysql_bind.buffer_type = .MYSQL_TYPE_FLOAT
	case f64:
		mysql_bind.buffer_type = .MYSQL_TYPE_DOUBLE
	case string:
		mysql_bind.buffer_type = .MYSQL_TYPE_VAR_STRING
	case []u8:
		mysql_bind.buffer_type = .MYSQL_TYPE_BLOB
	case:
		mysql_bind.buffer_type = .MYSQL_TYPE_NULL
		mysql_bind.buffer = nil
		mysql_bind.buffer_length = 0
		bind.buffer = nil
		bind.length = 0
		bind.is_null = b8(true)
		bind.error = b8(false)
	}
	//------------------------------------------------------------
	return mysql_bind
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
fetchColumnUInt8 :: proc(stmt: ^MYSQL_STMT, column_number: u32) -> (u8, Error) {
	//------------------------------------------------------------
	if stmt == nil do return 0, .InvalidStmtHandle
	//------------------------------------------------------------
	uint8: u8
	bind := MYSQL_BIND {
		buffer      = &uint8,
		buffer_type = .MYSQL_TYPE_TINY,
		is_unsigned = true,
	}
	//------------------------------------------------------------
	rc := mysql_stmt_fetch_column(stmt, &bind, column_number, 0)
	if rc != 0 do return 0, .FetchColumnError
	//------------------------------------------------------------
	return uint8, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
fetchColumnInt8 :: proc(stmt: ^MYSQL_STMT, column_number: u32) -> (i8, Error) {
	//------------------------------------------------------------
	if stmt == nil do return 0, .InvalidStmtHandle
	//------------------------------------------------------------
	int8: i8
	bind := MYSQL_BIND {
		buffer      = &int8,
		buffer_type = .MYSQL_TYPE_TINY,
		is_unsigned = false,
	}
	//------------------------------------------------------------
	rc := mysql_stmt_fetch_column(stmt, &bind, column_number, 0)
	if rc != 0 do return 0, .FetchColumnError
	//------------------------------------------------------------
	return int8, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
fetchColumnUInt16 :: proc(stmt: ^MYSQL_STMT, column_number: u32) -> (u16, Error) {
	//------------------------------------------------------------
	if stmt == nil do return 0, .InvalidStmtHandle
	//------------------------------------------------------------
	uint16: u16
	bind := MYSQL_BIND {
		buffer      = &uint16,
		buffer_type = .MYSQL_TYPE_SHORT,
		is_unsigned = true,
	}
	//------------------------------------------------------------
	rc := mysql_stmt_fetch_column(stmt, &bind, column_number, 0)
	if rc != 0 do return 0, .FetchColumnError
	//------------------------------------------------------------
	return uint16, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
fetchColumnInt16 :: proc(stmt: ^MYSQL_STMT, column_number: u32) -> (i16, Error) {
	//------------------------------------------------------------
	if stmt == nil do return 0, .InvalidStmtHandle
	//------------------------------------------------------------
	int16: i16
	bind := MYSQL_BIND {
		buffer      = &int16,
		buffer_type = .MYSQL_TYPE_SHORT,
		is_unsigned = false,
	}
	//------------------------------------------------------------
	rc := mysql_stmt_fetch_column(stmt, &bind, column_number, 0)
	if rc != 0 do return 0, .FetchColumnError
	//------------------------------------------------------------
	return int16, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
// odin does not have u24 so u32 used
fetchColumnUInt24 :: proc(stmt: ^MYSQL_STMT, column_number: u32) -> (u32, Error) {
	//------------------------------------------------------------
	if stmt == nil do return 0, .InvalidStmtHandle
	//------------------------------------------------------------
	uint32: u32
	bind := MYSQL_BIND {
		buffer      = &uint32,
		buffer_type = .MYSQL_TYPE_INT24,
		is_unsigned = true,
	}
	//------------------------------------------------------------
	rc := mysql_stmt_fetch_column(stmt, &bind, column_number, 0)
	if rc != 0 do return 0, .FetchColumnError
	//------------------------------------------------------------
	return uint32, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
// odin does not have i24 so i32 used
fetchColumnInt24 :: proc(stmt: ^MYSQL_STMT, column_number: u32) -> (i32, Error) {
	//------------------------------------------------------------
	if stmt == nil do return 0, .InvalidStmtHandle
	//------------------------------------------------------------
	int32: i32
	bind := MYSQL_BIND {
		buffer      = &int32,
		buffer_type = .MYSQL_TYPE_INT24,
		is_unsigned = false,
	}
	//------------------------------------------------------------
	rc := mysql_stmt_fetch_column(stmt, &bind, column_number, 0)
	if rc != 0 do return 0, .FetchColumnError
	//------------------------------------------------------------
	return int32, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
fetchColumnUInt32 :: proc(stmt: ^MYSQL_STMT, column_number: u32) -> (u32, Error) {
	//------------------------------------------------------------
	if stmt == nil do return 0, .InvalidStmtHandle
	//------------------------------------------------------------
	uint32: u32
	bind := MYSQL_BIND {
		buffer      = &uint32,
		buffer_type = .MYSQL_TYPE_LONG,
		is_unsigned = true,
	}
	//------------------------------------------------------------
	rc := mysql_stmt_fetch_column(stmt, &bind, column_number, 0)
	if rc != 0 do return 0, .FetchColumnError
	//------------------------------------------------------------
	return uint32, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
fetchColumnInt32 :: proc(stmt: ^MYSQL_STMT, column_number: u32) -> (i32, Error) {
	//------------------------------------------------------------
	if stmt == nil do return 0, .InvalidStmtHandle
	//------------------------------------------------------------
	int32: i32
	bind := MYSQL_BIND {
		buffer      = &int32,
		buffer_type = .MYSQL_TYPE_LONG,
		is_unsigned = false,
	}
	//------------------------------------------------------------
	rc := mysql_stmt_fetch_column(stmt, &bind, column_number, 0)
	if rc != 0 do return 0, .FetchColumnError
	//------------------------------------------------------------
	return int32, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
fetchColumnUInt64 :: proc(stmt: ^MYSQL_STMT, column_number: u32) -> (u64, Error) {
	//------------------------------------------------------------
	if stmt == nil do return 0, .InvalidStmtHandle
	//------------------------------------------------------------
	uint64: u64
	bind := MYSQL_BIND {
		buffer      = &uint64,
		buffer_type = .MYSQL_TYPE_LONGLONG,
		is_unsigned = true,
	}
	//------------------------------------------------------------
	rc := mysql_stmt_fetch_column(stmt, &bind, column_number, 0)
	if rc != 0 do return 0, .FetchColumnError
	//------------------------------------------------------------
	return uint64, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
fetchColumnInt64 :: proc(stmt: ^MYSQL_STMT, column_number: u32) -> (i64, Error) {
	//------------------------------------------------------------
	if stmt == nil do return 0, .InvalidStmtHandle
	//------------------------------------------------------------
	int64: i64
	bind := MYSQL_BIND {
		buffer      = &int64,
		buffer_type = .MYSQL_TYPE_LONGLONG,
		is_unsigned = false,
	}
	//------------------------------------------------------------
	rc := mysql_stmt_fetch_column(stmt, &bind, column_number, 0)
	if rc != 0 do return 0, .FetchColumnError
	//------------------------------------------------------------
	return int64, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
fetchColumnFloat32 :: proc(stmt: ^MYSQL_STMT, column_number: u32) -> (f32, Error) {
	//------------------------------------------------------------
	if stmt == nil do return 0, .InvalidStmtHandle
	//------------------------------------------------------------
	float32: f32
	bind := MYSQL_BIND {
		buffer      = &float32,
		buffer_type = .MYSQL_TYPE_FLOAT,
	}
	//------------------------------------------------------------
	rc := mysql_stmt_fetch_column(stmt, &bind, column_number, 0)
	if rc != 0 do return 0, .FetchColumnError
	//------------------------------------------------------------
	return float32, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
fetchColumnFloat64 :: proc(stmt: ^MYSQL_STMT, column_number: u32) -> (f64, Error) {
	//------------------------------------------------------------
	if stmt == nil do return 0, .InvalidStmtHandle
	//------------------------------------------------------------
	float64: f64
	bind := MYSQL_BIND {
		buffer      = &float64,
		buffer_type = .MYSQL_TYPE_DOUBLE,
	}
	//------------------------------------------------------------
	rc := mysql_stmt_fetch_column(stmt, &bind, column_number, 0)
	if rc != 0 do return 0, .FetchColumnError
	//------------------------------------------------------------
	return float64, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
fetchColumnBuffer :: proc(stmt: ^MYSQL_STMT, column_number: u32, buffer: []u8) -> (u64, Error) {
	//------------------------------------------------------------
	if stmt == nil do return 0, .InvalidStmtHandle
	if buffer == nil do return 0, .InvalidBuffer
	//------------------------------------------------------------
	length: u64
	bind := MYSQL_BIND {
		buffer_type   = .MYSQL_TYPE_BLOB,
		buffer        = raw_data(buffer),
		buffer_length = u64Len(buffer),
		length        = &length,
	}
	//------------------------------------------------------------
	rc := mysql_stmt_fetch_column(stmt, &bind, column_number, 0)
	if rc != 0 do return 0, .FetchColumnError
	//------------------------------------------------------------
	return length, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
fetchColumnBlob :: proc(
	stmt: ^MYSQL_STMT,
	column_number: u32,
	length: u64 = 0,
	allocator := context.allocator,
) -> (
	[]u8,
	Error,
) {
	//------------------------------------------------------------
	if stmt == nil do return []u8{}, .InvalidStmtHandle
	//------------------------------------------------------------
	column_length: u64 = length
	//------------------------------------------------------------
	if length == 0 {
		err: Error
		column_length, err = fetchColumnLength(stmt, column_number)
		if err != nil do return []u8{}, err
	}
	//------------------------------------------------------------
	buffer := make([]u8, int(column_length), allocator)
	if buffer == nil do return []u8{}, .AllocError
	//------------------------------------------------------------
	n, err := fetchColumnBuffer(stmt, column_number, buffer)
	if err != nil {
		delete(buffer)
		return []u8{}, err
	}
	//------------------------------------------------------------
	return n < u64Len(buffer) ? buffer[:n] : buffer[:], nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
fetchColumnString :: proc(
	stmt: ^MYSQL_STMT,
	column_number: u32,
	length: u64 = 0,
	allocator := context.allocator,
) -> (
	string,
	Error,
) {
	//------------------------------------------------------------
	blob, err := fetchColumnBlob(stmt, column_number, length, allocator)
	if err != nil do return "", err
	//------------------------------------------------------------
	return string(blob), nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
fetchColumnCString :: proc(
	stmt: ^MYSQL_STMT,
	column_number: u32,
	length: u64 = 0,
	allocator := context.allocator,
) -> (
	cstring,
	Error,
) {
	//------------------------------------------------------------
	if stmt == nil do return nil, .InvalidStmtHandle
	//------------------------------------------------------------
	column_length: u64 = length
	//------------------------------------------------------------
	if length == 0 {
		err: Error
		column_length, err = fetchColumnLength(stmt, column_number)
		if err != nil do return nil, err
	}
	//------------------------------------------------------------
	buffer := make([]u8, int(column_length + 1), allocator) // ensure space for null termination
	if buffer == nil do return nil, .AllocError
	//------------------------------------------------------------
	n, err := fetchColumnBuffer(stmt, column_number, buffer)
	if err != nil {
		delete(buffer)
		return nil, err
	}
	//------------------------------------------------------------
	if n >= u64Len(buffer) do n = u64Len(buffer) - 1
	buffer[n] = 0 // force last byte to be zero
	//------------------------------------------------------------
	return cstring(&buffer[0]), nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
fetchColumnLength :: proc(stmt: ^MYSQL_STMT, column_number: u32) -> (u64, Error) {
	//------------------------------------------------------------
	if stmt == nil do return 0, .InvalidStmtHandle
	//------------------------------------------------------------
	meta_result := mysql_stmt_result_metadata(stmt)
	if meta_result == nil do return 0, .MetadataResultError
	defer mysql_free_result(meta_result)
	//------------------------------------------------------------
	mysql_field := mysql_fetch_field_direct(meta_result, column_number)
	if mysql_field == nil do return 0, .FetchFieldError
	//------------------------------------------------------------
	return mysql_field.length, nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
getMySQLColumnsTable :: proc(
	db_handle: ^MYSQL,
	sql: cstring,
	allocator: mem.Allocator = context.allocator,
) -> (
	table: ^MySQLColumnsTable,
	err: Error,
) {
	//------------------------------------------------------------
	if db_handle == nil do return nil, .InvalidDBHandle
	//------------------------------------------------------------
	stmt := mysql_stmt_init(db_handle)
	defer mysql_stmt_close(stmt)
	//------------------------------------------------------------
	rc := mysql_stmt_prepare(stmt, sql, u64Len(sql))
	if rc != 0 do return nil, .PrepareError
	//------------------------------------------------------------
	rc = mysql_stmt_execute(stmt)
	if rc != 0 do return nil, .ExecuteError
	//------------------------------------------------------------
	arena_ptr, arena_err := new(virtual.Arena, allocator)
	if arena_err != nil do return nil, .AllocError
	arena_allocator := virtual.arena_allocator(arena_ptr)
	//------------------------------------------------------------
	table, err = new(MySQLColumnsTable, arena_allocator)
	if err != nil do return nil, .AllocError
	table.allocator = allocator
	table.arena_ptr = arena_ptr
	context.allocator = arena_allocator
	//------------------------------------------------------------
	table.row_count = 0
	table.column_count = int(mysql_stmt_field_count(stmt))
	//------------------------------------------------------------
	for {
		//------------------------------------------------------------
		rc = mysql_stmt_fetch(stmt)
		if rc != 0 do break
		//------------------------------------------------------------
		for index in 0 ..< table.column_count {
			//------------------------------------------------------------
			mysql_column := MySQLColumn{}
			//------------------------------------------------------------
			err = updateMySQLColumn(stmt, index, &mysql_column)
			//------------------------------------------------------------
			append(&table.mysql_columns, mysql_column)
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
		table.row_count += 1
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	if rc == 1 do err = .FetchError
	//------------------------------------------------------------
	return table, err
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
freeMySQLColumnsTable :: proc(table: ^MySQLColumnsTable) {
	//------------------------------------------------------------
	if table == nil do return
	//------------------------------------------------------------
	allocator := table.allocator
	arena_ptr := table.arena_ptr
	//------------------------------------------------------------
	table^ = MySQLColumnsTable{}
	virtual.arena_destroy(arena_ptr)
	mem.free(arena_ptr, allocator)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
updateMySQLColumn :: proc(
	stmt: ^MYSQL_STMT,
	index: int,
	mysql_column: ^MySQLColumn,
	allocator := context.allocator,
) -> Error {
	//------------------------------------------------------------
	if stmt == nil do return .InvalidStmtHandle
	//------------------------------------------------------------
	mysql_column^ = MySQLColumn{}
	mysql_column.index = index
	//------------------------------------------------------------
	column_number := u32(index)
	//------------------------------------------------------------
	bind := MYSQL_BIND{}
	//------------------------------------------------------------
	meta_result := mysql_stmt_result_metadata(stmt)
	if meta_result != nil {
		//------------------------------------------------------------
		defer mysql_free_result(meta_result)
		//------------------------------------------------------------
		mysql_field := mysql_fetch_field_direct(meta_result, column_number)
		if mysql_field != nil {
			//------------------------------------------------------------
			mysql_column.name = strings.clone(string(mysql_field.name), allocator) or_return
			//------------------------------------------------------------
			switch mysql_field.type {
			//------------------------------------------------------------
			case .MYSQL_TYPE_TINY:
				if (mysql_field.flags & UNSIGNED_FLAG) != 0 {
					mysql_column.type = .uint8
					mysql_column.value = fetchColumnUInt8(stmt, column_number) or_return
				} else {
					mysql_column.type = .int8
					mysql_column.value = fetchColumnInt8(stmt, column_number) or_return
				}
			//------------------------------------------------------------
			case .MYSQL_TYPE_SHORT:
				if (mysql_field.flags & UNSIGNED_FLAG) != 0 {
					mysql_column.type = .uint16
					mysql_column.value = fetchColumnUInt16(stmt, column_number) or_return
				} else {
					mysql_column.type = .int16
					mysql_column.value = fetchColumnInt16(stmt, column_number) or_return
				}
			//------------------------------------------------------------
			case .MYSQL_TYPE_INT24:
				if (mysql_field.flags & UNSIGNED_FLAG) != 0 {
					mysql_column.type = .uint24
					mysql_column.value = fetchColumnUInt24(stmt, column_number) or_return
				} else {
					mysql_column.type = .int24
					mysql_column.value = fetchColumnInt24(stmt, column_number) or_return
				}
			//------------------------------------------------------------
			case .MYSQL_TYPE_LONG:
				if (mysql_field.flags & UNSIGNED_FLAG) != 0 {
					mysql_column.type = .uint32
					mysql_column.value = fetchColumnUInt32(stmt, column_number) or_return
				} else {
					mysql_column.type = .int32
					mysql_column.value = fetchColumnInt32(stmt, column_number) or_return
				}
			//------------------------------------------------------------
			case .MYSQL_TYPE_LONGLONG:
				if (mysql_field.flags & UNSIGNED_FLAG) != 0 {
					mysql_column.type = .uint64
					mysql_column.value = fetchColumnUInt64(stmt, column_number) or_return
				} else {
					mysql_column.type = .int64
					mysql_column.value = fetchColumnInt64(stmt, column_number) or_return
				}
			//------------------------------------------------------------
			case .MYSQL_TYPE_FLOAT:
				//------------------------------------------------------------
				mysql_column.type = .float32
				mysql_column.value = fetchColumnFloat32(stmt, column_number) or_return
			//------------------------------------------------------------
			case .MYSQL_TYPE_DOUBLE:
				//------------------------------------------------------------
				mysql_column.type = .float64
				mysql_column.value = fetchColumnFloat64(stmt, column_number) or_return
			//------------------------------------------------------------
			case .MYSQL_TYPE_VARCHAR,
			     .MYSQL_TYPE_VAR_STRING,
			     .MYSQL_TYPE_STRING,
			     .MYSQL_TYPE_DECIMAL,
			     .MYSQL_TYPE_NEWDECIMAL,
			     .MYSQL_TYPE_TIMESTAMP,
			     .MYSQL_TYPE_TIMESTAMP2,
			     .MYSQL_TYPE_DATE,
			     .MYSQL_TYPE_NEWDATE,
			     .MYSQL_TYPE_TIME,
			     .MYSQL_TYPE_TIME2,
			     .MYSQL_TYPE_DATETIME,
			     .MYSQL_TYPE_DATETIME2,
			     .MYSQL_TYPE_YEAR,
			     .MYSQL_TYPE_ENUM,
			     .MYSQL_TYPE_SET,
			     .MYSQL_TYPE_JSON:
				//------------------------------------------------------------
				mysql_column.type = .string
				mysql_column.value = fetchColumnString(stmt, column_number) or_return
			//------------------------------------------------------------
			case .MYSQL_TYPE_TINY_BLOB,
			     .MYSQL_TYPE_MEDIUM_BLOB,
			     .MYSQL_TYPE_LONG_BLOB,
			     .MYSQL_TYPE_BLOB,
			     .MYSQL_TYPE_BIT,
			     .MYSQL_TYPE_GEOMETRY:
				//------------------------------------------------------------
				mysql_column.type = .blob
				mysql_column.value = fetchColumnBlob(stmt, column_number) or_return
			//------------------------------------------------------------
			case .MYSQL_TYPE_NULL:
				//------------------------------------------------------------
				mysql_column.type = .null
				mysql_column.value = nil
			//------------------------------------------------------------
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
freeMySQLColumn :: proc(mysql_column: ^MySQLColumn, allocator := context.allocator) {
	//------------------------------------------------------------
	if mysql_column == nil do return
	//------------------------------------------------------------
	delete(mysql_column.name, allocator)
	//------------------------------------------------------------
	#partial switch value in mysql_column.value {
	case string:
		delete(value, allocator)
	case []u8:
		delete(value, allocator)
	}
	//------------------------------------------------------------
	mysql_column^ = MySQLColumn{}
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
getMySQLRow :: proc(
	stmt: ^MYSQL_STMT,
	row: ^$T,
	allocator: mem.Allocator = context.allocator,
) -> Error {
	//------------------------------------------------------------
	if stmt == nil do return .InvalidStmtHandle
	//------------------------------------------------------------
	type_id := typeid_of(T)
	//------------------------------------------------------------
	field_count := reflect.struct_field_count(type_id)
	if field_count == 0 do return .ZeroFieldCount
	//------------------------------------------------------------
	column_count := int(mysql_stmt_field_count(stmt))
	if column_count == 0 do return .ZeroColumnCount
	//----------------------------------------------------
	// if field_count != column_count do return .InvalidFieldCount
	//------------------------------------------------------------
	for index in 0 ..< column_count {
		//------------------------------------------------------------
		column_number := u32(index)
		//------------------------------------------------------------
		meta_result := mysql_stmt_result_metadata(stmt)
		if meta_result != nil {
			//------------------------------------------------------------
			defer mysql_free_result(meta_result)
			//------------------------------------------------------------
			mysql_field := mysql_fetch_field_direct(meta_result, column_number)
			if mysql_field != nil {
				//------------------------------------------------------------
				mysql_field_name := mysql_field.name != nil ? string(mysql_field.name) : ""
				//------------------------------------------------------------
				field := reflect.struct_field_by_name(type_id, mysql_field_name)
				//------------------------------------------------------------
				if field.name == mysql_field_name {
					//------------------------------------------------------------
					dst := rawptr(uintptr(row) + field.offset)
					//------------------------------------------------------------
					switch mysql_field.type {
					//------------------------------------------------------------
					case .MYSQL_TYPE_TINY:
						if (mysql_field.flags & UNSIGNED_FLAG) != 0 {
							if field.type != type_info_of(u8) do return .FieldTypeMismatch
							uint8 := fetchColumnUInt8(stmt, column_number) or_return
							(^u8)(dst)^ = uint8
						} else {
							if field.type != type_info_of(i8) do return .FieldTypeMismatch
							int8 := fetchColumnInt8(stmt, column_number) or_return
							(^i8)(dst)^ = int8
						}
					//------------------------------------------------------------
					case .MYSQL_TYPE_SHORT:
						if (mysql_field.flags & UNSIGNED_FLAG) != 0 {
							if field.type != type_info_of(u16) do return .FieldTypeMismatch
							uint16 := fetchColumnUInt16(stmt, column_number) or_return
							(^u16)(dst)^ = uint16
						} else {
							if field.type != type_info_of(i16) do return .FieldTypeMismatch
							int16 := fetchColumnInt16(stmt, column_number) or_return
							(^i16)(dst)^ = int16
						}
					//------------------------------------------------------------
					case .MYSQL_TYPE_INT24:
						if (mysql_field.flags & UNSIGNED_FLAG) != 0 {
							if field.type != type_info_of(u32) do return .FieldTypeMismatch
							uint32 := fetchColumnUInt24(stmt, column_number) or_return
							(^u32)(dst)^ = uint32
						} else {
							if field.type != type_info_of(i32) do return .FieldTypeMismatch
							int32 := fetchColumnInt24(stmt, column_number) or_return
							(^i32)(dst)^ = int32
						}
					//------------------------------------------------------------
					case .MYSQL_TYPE_LONG:
						if (mysql_field.flags & UNSIGNED_FLAG) != 0 {
							if field.type != type_info_of(u32) do return .FieldTypeMismatch
							uint32 := fetchColumnUInt32(stmt, column_number) or_return
							(^u32)(dst)^ = uint32
						} else {
							if field.type != type_info_of(i32) do return .FieldTypeMismatch
							int32 := fetchColumnInt32(stmt, column_number) or_return
							(^i32)(dst)^ = int32
						}
					//------------------------------------------------------------
					case .MYSQL_TYPE_LONGLONG:
						if (mysql_field.flags & UNSIGNED_FLAG) != 0 {
							if field.type != type_info_of(u64) do return .FieldTypeMismatch
							uint64 := fetchColumnUInt64(stmt, column_number) or_return
							(^u64)(dst)^ = uint64
						} else {
							if field.type != type_info_of(i64) do return .FieldTypeMismatch
							int64 := fetchColumnInt64(stmt, column_number) or_return
							(^i64)(dst)^ = int64
						}
					//------------------------------------------------------------
					case .MYSQL_TYPE_FLOAT:
						//------------------------------------------------------------
						if field.type != type_info_of(f32) do return .FieldTypeMismatch
						float32 := fetchColumnFloat32(stmt, column_number) or_return
						(^f32)(dst)^ = float32
					//------------------------------------------------------------
					case .MYSQL_TYPE_DOUBLE:
						//------------------------------------------------------------
						if field.type != type_info_of(f64) do return .FieldTypeMismatch
						float64 := fetchColumnFloat64(stmt, column_number) or_return
						(^f64)(dst)^ = float64
					//------------------------------------------------------------
					case .MYSQL_TYPE_VARCHAR,
					     .MYSQL_TYPE_VAR_STRING,
					     .MYSQL_TYPE_STRING,
					     .MYSQL_TYPE_DECIMAL,
					     .MYSQL_TYPE_NEWDECIMAL,
					     .MYSQL_TYPE_TIMESTAMP,
					     .MYSQL_TYPE_TIMESTAMP2,
					     .MYSQL_TYPE_DATE,
					     .MYSQL_TYPE_NEWDATE,
					     .MYSQL_TYPE_TIME,
					     .MYSQL_TYPE_TIME2,
					     .MYSQL_TYPE_DATETIME,
					     .MYSQL_TYPE_DATETIME2,
					     .MYSQL_TYPE_YEAR,
					     .MYSQL_TYPE_ENUM,
					     .MYSQL_TYPE_SET,
					     .MYSQL_TYPE_JSON:
						//------------------------------------------------------------
						if field.type != type_info_of(string) do return .FieldTypeMismatch
						string_value := fetchColumnString(stmt, column_number) or_return
						(^string)(dst)^ = string_value
					//------------------------------------------------------------
					case .MYSQL_TYPE_TINY_BLOB,
					     .MYSQL_TYPE_MEDIUM_BLOB,
					     .MYSQL_TYPE_LONG_BLOB,
					     .MYSQL_TYPE_BLOB,
					     .MYSQL_TYPE_BIT,
					     .MYSQL_TYPE_GEOMETRY:
						//------------------------------------------------------------
						if field.type != type_info_of([]u8) do return .FieldTypeMismatch
						blob_value := fetchColumnBlob(stmt, column_number) or_return
						(^[]u8)(dst)^ = blob_value
					//------------------------------------------------------------
					case .MYSQL_TYPE_NULL:
						mem.set(dst, 0, field.type.size)
					//------------------------------------------------------------
					}
					//------------------------------------------------------------
				}
				//------------------------------------------------------------
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
updateRow :: proc(
	row: ^$T,
	mysql_columns: []MySQLColumn,
	allocator := context.allocator,
) -> Error {
	//------------------------------------------------------------
	for mysql_column in mysql_columns {
		//------------------------------------------------------------
		switch mysql_column.type {
		//------------------------------------------------------------
		case .uint8:
			value, ok := mysql_column.value.(u8)
			if !ok do return .FieldTypeMismatch
			setStructFieldValue(row, mysql_column.name, value) or_return
		//------------------------------------------------------------
		case .int8:
			value, ok := mysql_column.value.(i8)
			if !ok do return .FieldTypeMismatch
			setStructFieldValue(row, mysql_column.name, value) or_return
		//------------------------------------------------------------
		case .uint16:
			value, ok := mysql_column.value.(u16)
			if !ok do return .FieldTypeMismatch
			setStructFieldValue(row, mysql_column.name, value) or_return
		//------------------------------------------------------------
		case .int16:
			value, ok := mysql_column.value.(i16)
			if !ok do return .FieldTypeMismatch
			setStructFieldValue(row, mysql_column.name, value) or_return
		//------------------------------------------------------------
		case .uint24:
			value, ok := mysql_column.value.(u32)
			if !ok do return .FieldTypeMismatch
			setStructFieldValue(row, mysql_column.name, value) or_return
		//------------------------------------------------------------
		case .int24:
			value, ok := mysql_column.value.(i32)
			if !ok do return .FieldTypeMismatch
			setStructFieldValue(row, mysql_column.name, value) or_return
		//------------------------------------------------------------
		case .uint32:
			value, ok := mysql_column.value.(u32)
			if !ok do return .FieldTypeMismatch
			setStructFieldValue(row, mysql_column.name, value) or_return
		//------------------------------------------------------------
		case .int32:
			value, ok := mysql_column.value.(i32)
			if !ok do return .FieldTypeMismatch
			setStructFieldValue(row, mysql_column.name, value) or_return
		//------------------------------------------------------------
		case .uint64:
			value, ok := mysql_column.value.(u64)
			if !ok do return .FieldTypeMismatch
			setStructFieldValue(row, mysql_column.name, value) or_return
		//------------------------------------------------------------
		case .int64:
			value, ok := mysql_column.value.(i64)
			if !ok do return .FieldTypeMismatch
			setStructFieldValue(row, mysql_column.name, value) or_return
		//------------------------------------------------------------
		case .float32:
			value, ok := mysql_column.value.(f32)
			if !ok do return .FieldTypeMismatch
			setStructFieldValue(row, mysql_column.name, value) or_return
		//------------------------------------------------------------
		case .float64:
			value, ok := mysql_column.value.(f64)
			if !ok do return .FieldTypeMismatch
			setStructFieldValue(row, mysql_column.name, value) or_return
		//------------------------------------------------------------
		case .string:
			value, ok := mysql_column.value.(string)
			if !ok do return .FieldTypeMismatch
			string_value := strings.clone(value, allocator) or_return
			setStructFieldValue(row, mysql_column.name, string_value) or_return
		//------------------------------------------------------------
		case .blob:
			value, ok := mysql_column.value.([]u8)
			if !ok do return .FieldTypeMismatch
			blob_value := bytes.clone_safe(value, allocator) or_return
			setStructFieldValue(row, mysql_column.name, blob_value) or_return
		//------------------------------------------------------------
		case .null:
			setStructFieldValue(row, mysql_column.name, nil) or_return
		//------------------------------------------------------------
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	return nil
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
updateRowMap :: proc(
	row_map: ^map[string]ColumnValue,
	mysql_columns: []MySQLColumn,
	allocator: mem.Allocator = context.allocator,
) -> Error {
	//------------------------------------------------------------
	for mysql_column in mysql_columns {
		//------------------------------------------------------------
		ok: bool
		//------------------------------------------------------------
		key := mysql_column.name
		//------------------------------------------------------------
		switch mysql_column.type {
		//------------------------------------------------------------
		case .uint8:
			row_map[key], ok = mysql_column.value.(u8)
			if !ok do return .FieldTypeMismatch
		//------------------------------------------------------------
		case .int8:
			row_map[key], ok = mysql_column.value.(i8)
			if !ok do return .FieldTypeMismatch
		//------------------------------------------------------------
		case .uint16:
			row_map[key], ok = mysql_column.value.(u16)
			if !ok do return .FieldTypeMismatch
		//------------------------------------------------------------
		case .int16:
			row_map[key], ok = mysql_column.value.(i16)
			if !ok do return .FieldTypeMismatch
		//------------------------------------------------------------
		case .uint24:
			row_map[key], ok = mysql_column.value.(u32)
			if !ok do return .FieldTypeMismatch
		//------------------------------------------------------------
		case .int24:
			row_map[key], ok = mysql_column.value.(i32)
			if !ok do return .FieldTypeMismatch
		//------------------------------------------------------------
		case .uint32:
			row_map[key], ok = mysql_column.value.(u32)
			if !ok do return .FieldTypeMismatch
		//------------------------------------------------------------
		case .int32:
			row_map[key], ok = mysql_column.value.(i32)
			if !ok do return .FieldTypeMismatch
		//------------------------------------------------------------
		case .uint64:
			row_map[key], ok = mysql_column.value.(u64)
			if !ok do return .FieldTypeMismatch
		//------------------------------------------------------------
		case .int64:
			row_map[key], ok = mysql_column.value.(i64)
			if !ok do return .FieldTypeMismatch
		//------------------------------------------------------------
		case .float32:
			row_map[key], ok = mysql_column.value.(f32)
			if !ok do return .FieldTypeMismatch
		//------------------------------------------------------------
		case .float64:
			row_map[key], ok = mysql_column.value.(f64)
			if !ok do return .FieldTypeMismatch
		//------------------------------------------------------------
		case .string:
			value, ok := mysql_column.value.(string)
			if !ok do return .FieldTypeMismatch
			row_map[key] = strings.clone(value, allocator) or_return
		//------------------------------------------------------------
		case .blob:
			value, ok := mysql_column.value.([]u8)
			if !ok do return .FieldTypeMismatch
			row_map[key] = bytes.clone_safe(value, allocator) or_return
		//------------------------------------------------------------
		case .null:
			row_map[key] = nil
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
setStructFieldValue :: proc(struct_ptr: ^$T, field_name: string, value: any) -> Error {
	//----------------------------------------
	struct_field := reflect.struct_field_by_name(typeid_of(T), field_name)
	//----------------------------------------
	if struct_field.type == nil do return .FieldNotFound
	//----------------------------------------
	struct_field_ptr := rawptr(uintptr(struct_ptr) + struct_field.offset)
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
ptrToBytes :: proc(ptr: [^]u8, #any_int len: int) -> []u8 {return ptr[:len]}
rawptrToBytes :: proc(ptr: rawptr, #any_int len: int) -> []u8 {return (cast([^]u8)ptr)[:len]}
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
foreign import libmysql "system:mysqlclient"
foreign libmysql {
	//------------------------------------------------------------
	mysql_affected_rows :: proc(mysql: ^MYSQL) -> u64 ---
	mysql_autocommit :: proc(mysql: ^MYSQL, mode: bool) -> u8 ---
	mysql_close :: proc(mysql: ^MYSQL) ---
	mysql_commit :: proc(mysql: ^MYSQL) -> u8 ---
	mysql_errno :: proc "c" (mysql: ^MYSQL) -> u32 ---
	mysql_error :: proc "c" (mysql: ^MYSQL) -> cstring ---
	mysql_escape_string :: proc(to: cstring, from: cstring, from_length: u64) -> u64 ---
	mysql_fetch_field :: proc(result: ^MYSQL_RES) -> ^MYSQL_FIELD ---
	mysql_fetch_field_direct :: proc(result: ^MYSQL_RES, fieldnr: u32) -> ^MYSQL_FIELD ---
	mysql_fetch_fields :: proc(result: ^MYSQL_RES) -> [^]MYSQL_FIELD ---
	mysql_fetch_lengths :: proc(result: ^MYSQL_RES) -> ^u64 ---
	mysql_fetch_row :: proc "c" (result: ^MYSQL_RES) -> MYSQL_ROW ---
	mysql_field_count :: proc "c" (mysql: ^MYSQL) -> u32 ---
	mysql_free_result :: proc "c" (result: ^MYSQL_RES) ---
	mysql_info :: proc(mysql: ^MYSQL) -> cstring ---
	mysql_init :: proc "c" (mysql: ^MYSQL) -> ^MYSQL ---
	mysql_insert_id :: proc(mysql: ^MYSQL) -> u64 ---
	mysql_list_dbs :: proc(mysql: ^MYSQL, wild: cstring) -> ^MYSQL_RES ---
	mysql_list_fields :: proc(mysql: ^MYSQL, table: cstring, wild: cstring) -> ^MYSQL_RES ---
	mysql_list_tables :: proc(mysql: ^MYSQL, wild: cstring) -> ^MYSQL_RES ---
	mysql_more_results :: proc(mysql: ^MYSQL) -> u8 ---
	mysql_next_result :: proc "c" (mysql: ^MYSQL) -> i32 ---
	mysql_num_fields :: proc(result: ^MYSQL_RES) -> u32 ---
	mysql_num_rows :: proc(result: ^MYSQL_RES) -> u64 ---
	mysql_ping :: proc(mysql: ^MYSQL) -> i32 ---
	mysql_query :: proc "c" (mysql: ^MYSQL, query: cstring) -> i32 ---
	mysql_real_connect :: proc "c" (mysql: ^MYSQL, host: cstring, user: cstring, passwd: cstring, db: cstring, port: u32, unix_socket: cstring, client_flag: u64) -> ^MYSQL ---
	mysql_real_escape_string :: proc(mysql: ^MYSQL, to: cstring, from: cstring, length: u64) -> u64 ---
	mysql_real_query :: proc(mysql: ^MYSQL, stmt_str: cstring, length: u64) -> i32 ---
	mysql_refresh :: proc(mysql: ^MYSQL, refresh_options: u32) -> i32 ---
	mysql_reset_connection :: proc "c" (mysql: ^MYSQL) -> i32 ---
	mysql_rollback :: proc(mysql: ^MYSQL) -> u8 ---
	mysql_select_db :: proc(mysql: ^MYSQL, db: cstring) -> i32 ---
	mysql_stmt_affected_rows :: proc "c" (stmt: ^MYSQL_STMT) -> u64 ---
	mysql_stmt_bind_param :: proc "c" (stmt: ^MYSQL_STMT, bind: ^MYSQL_BIND) -> u8 ---
	mysql_stmt_bind_result :: proc "c" (stmt: ^MYSQL_STMT, bind: ^MYSQL_BIND) -> u8 ---
	mysql_stmt_close :: proc "c" (stmt: ^MYSQL_STMT) -> u8 ---
	mysql_stmt_errno :: proc "c" (stmt: ^MYSQL_STMT) -> u32 ---
	mysql_stmt_error :: proc "c" (stmt: ^MYSQL_STMT) -> cstring ---
	mysql_stmt_execute :: proc "c" (stmt: ^MYSQL_STMT) -> i32 ---
	mysql_stmt_fetch :: proc "c" (stmt: ^MYSQL_STMT) -> i32 ---
	mysql_stmt_fetch_column :: proc "c" (stmt: ^MYSQL_STMT, bind: ^MYSQL_BIND, column_number: u32, offset: u32) -> i32 ---
	mysql_stmt_field_count :: proc "c" (stmt: ^MYSQL_STMT) -> u32 ---
	mysql_stmt_free_result :: proc "c" (stmt: ^MYSQL_STMT) -> u8 ---
	mysql_stmt_init :: proc "c" (mysql: ^MYSQL) -> ^MYSQL_STMT ---
	mysql_stmt_insert_id :: proc "c" (stmt: ^MYSQL_STMT) -> u64 ---
	mysql_stmt_more_results :: proc "c" (stmt: ^MYSQL_STMT) -> u8 ---
	mysql_stmt_next_result :: proc "c" (stmt: ^MYSQL_STMT) -> i32 ---
	mysql_stmt_num_rows :: proc "c" (stmt: ^MYSQL_STMT) -> u64 ---
	mysql_stmt_param_count :: proc "c" (stmt: ^MYSQL_STMT) -> u32 ---
	mysql_stmt_param_metadata :: proc "c" (stmt: ^MYSQL_STMT) -> ^MYSQL_RES ---
	mysql_stmt_result_metadata :: proc "c" (stmt: ^MYSQL_STMT) -> ^MYSQL_RES ---
	mysql_stmt_prepare :: proc "c" (stmt: ^MYSQL_STMT, stmt_str: cstring, length: u64) -> i32 ---
	mysql_stmt_reset :: proc "c" (stmt: ^MYSQL_STMT) -> u8 ---
	mysql_stmt_sqlstate :: proc "c" (stmt: ^MYSQL_STMT) -> cstring ---
	mysql_stmt_store_result :: proc "c" (stmt: ^MYSQL_STMT) -> i32 ---
	mysql_store_result :: proc(mysql: ^MYSQL) -> ^MYSQL_RES ---
	mysql_use_result :: proc(mysql: ^MYSQL) -> ^MYSQL_RES ---
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
CLIENT_MULTI_STATEMENTS: u64 = 1 << 16
UNSIGNED_FLAG: u32 : 32
//--------------------------------------------------------------------------------
MYSQL_NO_DATA :: 100
MYSQL_DATA_TRUNCATED :: 101
//--------------------------------------------------------------------------------
MYSQL :: rawptr
MYSQL_STMT :: rawptr
MYSQL_RES :: rawptr
//--------------------------------------------------------------------------------
MYSQL_ROWS :: struct {
	next:   ^MYSQL_ROWS,
	data:   MYSQL_ROW,
	length: u64,
}
MYSQL_ROW :: [^]cstring
MYSQL_FIELD :: struct {
	name:             cstring,
	org_name:         cstring,
	table:            cstring,
	org_table:        cstring,
	db:               cstring,
	catalog:          cstring,
	def:              cstring,
	length:           u64,
	max_length:       u64,
	name_length:      u32,
	org_name_length:  u32,
	table_length:     u32,
	org_table_length: u32,
	db_length:        u32,
	catalog_length:   u32,
	def_length:       u32,
	flags:            u32,
	decimals:         u32,
	charsetnr:        u32,
	type:             MYSQL_FIELD_TYPE,
	extension:        rawptr,
}
MYSQL_FIELD_TYPE :: enum i32 {
	MYSQL_TYPE_DECIMAL     = 0,
	MYSQL_TYPE_TINY        = 1, // TINYINT
	MYSQL_TYPE_SHORT       = 2, // SMALLINT
	MYSQL_TYPE_LONG        = 3, // INT
	MYSQL_TYPE_FLOAT       = 4, // FLOAT
	MYSQL_TYPE_DOUBLE      = 5, // DOUBLE
	MYSQL_TYPE_NULL        = 6,
	MYSQL_TYPE_TIMESTAMP   = 7, // TIMESTAMP
	MYSQL_TYPE_LONGLONG    = 8, // BIGINT
	MYSQL_TYPE_INT24       = 9, // MEDIUMINT
	MYSQL_TYPE_DATE        = 10, // DATE
	MYSQL_TYPE_TIME        = 11, // TIME
	MYSQL_TYPE_DATETIME    = 12, // DATETIME
	MYSQL_TYPE_YEAR        = 13, // YEAR
	MYSQL_TYPE_NEWDATE     = 14, // DATE
	MYSQL_TYPE_VARCHAR     = 15, // VARCHAR
	MYSQL_TYPE_BIT         = 16, // BIT
	MYSQL_TYPE_TIMESTAMP2  = 17, // TIMESTAMP
	MYSQL_TYPE_DATETIME2   = 18, // DATETIME
	MYSQL_TYPE_TIME2       = 19, // TIME
	MYSQL_TYPE_JSON        = 245, // JSON
	MYSQL_TYPE_NEWDECIMAL  = 246, // DECIMAL
	MYSQL_TYPE_ENUM        = 247, // ENUM
	MYSQL_TYPE_SET         = 248, // SET
	MYSQL_TYPE_TINY_BLOB   = 249, // TINYBLOB / TINYTEXT, max 255 bytes
	MYSQL_TYPE_MEDIUM_BLOB = 250, // MEDIUMBLOB / MEDIUMTEXT, max 16777215 bytes
	MYSQL_TYPE_LONG_BLOB   = 251, // LONGBLOB / LONGTEXT, max 4294967295 bytes
	MYSQL_TYPE_BLOB        = 252, // BLOB / TEXT, max 65535 bytes
	MYSQL_TYPE_VAR_STRING  = 253, // VARCHAR, max 65535 bytes
	MYSQL_TYPE_STRING      = 254, // CHAR / BINARY
	MYSQL_TYPE_GEOMETRY    = 255, // GEOMETRY
}
MYSQL_BIND :: struct {
	length:           ^u64,
	is_null:          ^b8,
	buffer:           rawptr,
	error:            ^b8,
	row_ptr:          [^]u8,
	store_param_func: rawptr,
	fetch_result:     rawptr,
	skip_result:      rawptr,
	buffer_length:    u64,
	offset:           u64,
	length_value:     u64,
	param_number:     u32,
	pack_length:      u32,
	buffer_type:      MYSQL_FIELD_TYPE,
	error_value:      b8,
	is_unsigned:      b8,
	long_data_used:   b8,
	is_null_value:    b8,
	extension:        rawptr,
}
//--------------------------------------------------------------------------------
MySQLBind :: struct {
	//----------------------------------------
	buffer:  rawptr,
	//----------------------------------------
	length:  u64,
	//----------------------------------------
	is_null: b8,
	error:   b8,
	//----------------------------------------
	type_id: typeid,
	//----------------------------------------
}
//--------------------------------------------------------------------------------
ColumnType :: enum i32 {
	//------------------------------------------------------------
	null = 0,
	uint8,
	int8,
	uint16,
	int16,
	uint24,
	int24,
	uint32,
	int32,
	uint64,
	int64,
	float32,
	float64,
	string,
	blob,
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
null :: struct {}
u24 :: distinct u32
i24 :: distinct i32
//--------------------------------------------------------------------------------
ColumnValue :: union {
	//------------------------------------------------------------
	null,
	u8,
	i8,
	u16,
	i16,
	u24,
	i24,
	u32,
	i32,
	u64,
	i64,
	f32,
	f64,
	string,
	[]u8,
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
MySQLColumn :: struct {
	//------------------------------------------------------------
	index: int,
	name:  string,
	type:  ColumnType,
	value: ColumnValue,
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
MySQLColumnsTable :: struct {
	//------------------------------------------------------------
	allocator:     mem.Allocator,
	arena_ptr:     ^virtual.Arena,
	//------------------------------------------------------------
	mysql_columns: [dynamic]MySQLColumn,
	//------------------------------------------------------------
	row_count:     int,
	column_count:  int,
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
