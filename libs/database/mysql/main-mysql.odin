//--------------------------------------------------------------------------------
package mysql
//--------------------------------------------------------------------------------
import "core:fmt"
import "core:mem"
import ut "libs/unittest"
//--------------------------------------------------------------------------------
FixedRow :: struct {
	id:             u32,
	_u8:            u8,
	_i8:            i8,
	_u16:           u16,
	_i16:           i16,
	_u24:           u32,
	_i24:           i32,
	_u32:           u32,
	_i32:           i32,
	_u64:           u64,
	_i64:           i64,
	_f32:           f32,
	_f64:           f64,
	_varchar:       string,
	_text:          []u8,
	_blob:          []u8,
	_blob_nullable: []u8,
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
main :: proc() {
	//--------------------------------------------------------------------------------
	ut.init({show_passes = false, skip_after_fail = false})
	//------------------------------------------------------------
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	//------------------------------------------------------------
	defer {
		if len(track.allocation_map) > 0 {
			fmt.eprintfln("=== %v allocations not freed: ===", len(track.allocation_map))
			for _, entry in track.allocation_map {fmt.eprintfln("- %v bytes @ %v", entry.size, entry.location)}
		}
		if len(track.bad_free_array) > 0 {
			fmt.eprintfln("=== %v incorrect frees: ===", len(track.bad_free_array))
			for entry in track.bad_free_array {fmt.eprintfln("- %p @ %v", entry.memory, entry.location)}
		}
		mem.tracking_allocator_destroy(&track)
	}
	//------------------------------------------------------------
	context.allocator = mem.tracking_allocator(&track)
	//--------------------------------------------------------------------------------
	//################################################################################
	//--------------------------------------------------------------------------------
	HOST :: "127.0.0.1"
	PORT: u32 = 3306
	USER :: "root"
	PASSWD :: ""
	DB: cstring = nil
	CLIENT_FLAG: u64 = CLIENT_MULTI_STATEMENTS
	//--------------------------------------------------------------------------------
	//################################################################################
	//--------------------------------------------------------------------------------
	// mysql_init
	//--------------------------------------------------------------------------------
	db_handle := mysql_init(nil)
	ut.compareTypeID("mysql_init: db_handle", type_of(db_handle), ^MYSQL)
	//--------------------------------------------------------------------------------
	if db_handle == nil do return
	//--------------------------------------------------------------------------------
	// mysql_real_connect / mysql_close
	//--------------------------------------------------------------------------------
	conn := mysql_real_connect(db_handle, HOST, USER, PASSWD, DB, PORT, nil, CLIENT_FLAG)
	ut.compareTypeID("mysql_real_connect: conn", type_of(conn), ^MYSQL)
	ut.compareInteger("mysql_real_connect: mysql_errno", mysql_errno(db_handle), 0)
	ut.compareCString("mysql_real_connect: mysql_error", mysql_error(db_handle), "")
	//--------------------------------------------------------------------------------
	if conn == nil do return
	//--------------------------------------------------------------------------------
	defer mysql_close(db_handle)
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		// mysql_query
		//-------------------------------------q-----------------------
		rc := mysql_query(db_handle, "SELECT VERSION();")
		ut.compareInteger("mysql_query: rc", rc, 0)
		ut.compareInteger("mysql_query: mysql_errno", mysql_errno(db_handle), 0)
		ut.compareCString("mysql_query: mysql_error", mysql_error(db_handle), "")
		//------------------------------------------------------------
		// mysql_store_result / mysql_free_result
		//------------------------------------------------------------
		result := mysql_store_result(db_handle)
		ut.compareTypeID("mysql_store_result: result", type_of(result), ^MYSQL_RES)
		ut.compareInteger("mysql_store_result: mysql_errno", mysql_errno(db_handle), 0)
		ut.compareCString("mysql_store_result: mysql_error", mysql_error(db_handle), "")
		//------------------------------------------------------------
		defer mysql_free_result(result)
		//------------------------------------------------------------
		// mysql_fetch_row
		//------------------------------------------------------------
		row := mysql_fetch_row(result)
		//------------------------------------------------------------
		ut.compareTypeID("mysql_fetch_row: row", type_of(row), MYSQL_ROW)
		ut.compareInteger("mysql_fetch_row: mysql_errno", mysql_errno(db_handle), 0)
		ut.compareCString("mysql_fetch_row: mysql_error", mysql_error(db_handle), "")
		//------------------------------------------------------------
		fmt.printfln("version: %s", row[0])
		ut.compareBool("mysql_fetch_row: version", row[0] != "", true)
		//------------------------------------------------------------
		ut.printLine()
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	//################################################################################
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		rc := mysql_query(db_handle, "CREATE DATABASE IF NOT EXISTS test")
		ut.compareInteger("mysql_query: rc", rc, 0)
		ut.compareInteger("mysql_query: mysql_errno", mysql_errno(db_handle), 0)
		ut.compareCString("mysql_query: mysql_error", mysql_error(db_handle), "")
		//------------------------------------------------------------
		// mysql_select_db
		//------------------------------------------------------------
		rc = mysql_select_db(db_handle, "test")
		ut.compareInteger("mysql_select_db: rc", rc, 0)
		ut.compareInteger("mysql_select_db: mysql_errno", mysql_errno(db_handle), 0)
		ut.compareCString("mysql_select_db: mysql_error", mysql_error(db_handle), "")
		//------------------------------------------------------------
		sql: cstring = `DROP TABLE IF EXISTS test;
			CREATE TABLE IF NOT EXISTS test (
			id INT UNSIGNED NOT NULL AUTO_INCREMENT,
			_u8 TINYINT UNSIGNED DEFAULT 0 NOT NULL,
			_i8 TINYINT DEFAULT 0 NOT NULL,
			_u16 SMALLINT UNSIGNED DEFAULT 0 NOT NULL,
			_i16 SMALLINT DEFAULT 0 NOT NULL,
			_u24 MEDIUMINT UNSIGNED DEFAULT 0 NOT NULL,
			_i24 MEDIUMINT DEFAULT 0 NOT NULL,
			_u32 INT UNSIGNED DEFAULT 0 NOT NULL,
			_i32 INT DEFAULT 0 NOT NULL,
			_u64 BIGINT UNSIGNED DEFAULT 0 NOT NULL,
			_i64 BIGINT DEFAULT 0 NOT NULL,
			_f32 FLOAT DEFAULT 0 NOT NULL,
			_f64 DOUBLE DEFAULT 0 NOT NULL,
			_varchar VARCHAR(255) DEFAULT '' NOT NULL,
			_text TEXT DEFAULT '' NOT NULL,
			_blob BLOB DEFAULT '' NOT NULL,
			_blob_nullable BLOB,
			PRIMARY KEY (id)
			);
		`
		rc = mysql_query(db_handle, sql)
		ut.compareInteger("mysql_query: rc", rc, 0)
		ut.compareInteger("mysql_query: mysql_errno", mysql_errno(db_handle), 0)
		ut.compareCString("mysql_query: mysql_error", mysql_error(db_handle), "")
		//------------------------------------------------------------
		for mysql_more_results(db_handle) != 0 {
			//------------------------------------------------------------
			next_rc := mysql_next_result(db_handle)
			ut.compareInteger("mysql_next_result: rc", next_rc, 0)
			ut.compareInteger("mysql_next_result: mysql_errno", mysql_errno(db_handle), 0)
			ut.compareCString("mysql_next_result: mysql_error", mysql_error(db_handle), "")
			//------------------------------------------------------------
			if next_rc > 0 do return
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		// mysql_stmt_init
		//------------------------------------------------------------
		sql :: "INSERT INTO test(_u8, _i8, _u16, _i16, _u24, _i24, _u32, _i32, _u64, _i64, _f32, _f64, _varchar, _text, _blob, _blob_nullable) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
		stmt := mysql_stmt_init(db_handle)
		ut.compareTypeID("mysql_stmt_init: stmt", type_of(stmt), ^MYSQL_STMT)
		ut.compareInteger("mysql_stmt_init: mysql_errno", mysql_errno(db_handle), 0)
		ut.compareCString("mysql_stmt_init: mysql_error", mysql_error(db_handle), "")
		//------------------------------------------------------------
		// mysql_stmt_prepare
		//------------------------------------------------------------
		rc := mysql_stmt_prepare(stmt, sql, u64Len(sql))
		ut.compareInteger("mysql_stmt_prepare: rc", rc, 0)
		ut.compareInteger("mysql_stmt_prepare: mysql_stmt_errno", mysql_stmt_errno(stmt), 0)
		ut.compareCString("mysql_stmt_prepare: mysql_stmt_error", mysql_stmt_error(stmt), "")
		//------------------------------------------------------------
		if rc != 0 do return
		//------------------------------------------------------------
		defer mysql_stmt_close(stmt)
		//------------------------------------------------------------
		_u8: u8 = 8
		_i8: i8 = -8
		_u16: u16 = 16
		_i16: i16 = -16
		_u24: u32 = 24 // odin does not have u24
		_i24: i32 = -24 // odin does not have i24
		_u32: u32 = 32
		_i32: i32 = -32
		_u64: u64 = 64
		_i64: i64 = -64
		_f32: f32 = 32.32
		_f64: f64 = 64.64
		//------------------------------------------------------------
		_varchar: string = "_varchar"
		_text: string = "_text"
		_blob: []u8 = stringToBytes("_blob")
		//------------------------------------------------------------
		binds: [16]MYSQL_BIND
		mem.zero(&binds, size_of(binds))

		binds[0].buffer_type = .MYSQL_TYPE_TINY
		binds[0].buffer = &_u8
		binds[0].is_unsigned = true

		binds[1].buffer_type = .MYSQL_TYPE_TINY
		binds[1].buffer = &_i8

		binds[2].buffer_type = .MYSQL_TYPE_SHORT
		binds[2].buffer = &_u16
		binds[2].is_unsigned = true

		binds[3].buffer_type = .MYSQL_TYPE_SHORT
		binds[3].buffer = &_i16

		// MYSQL_TYPE_INT24 not supported
		// binds[4].buffer_type = .MYSQL_TYPE_INT24
		binds[4].buffer_type = .MYSQL_TYPE_LONG
		binds[4].buffer = &_u24
		binds[4].is_unsigned = true

		// MYSQL_TYPE_INT24 not supported
		// binds[5].buffer_type = .MYSQL_TYPE_INT24
		binds[5].buffer_type = .MYSQL_TYPE_LONG
		binds[5].buffer = &_i24

		binds[6].buffer_type = .MYSQL_TYPE_LONG
		binds[6].buffer = &_u32
		binds[6].is_unsigned = true

		binds[7].buffer_type = .MYSQL_TYPE_LONG
		binds[7].buffer = &_i32

		binds[8].buffer_type = .MYSQL_TYPE_LONGLONG
		binds[8].buffer = &_u64
		binds[8].is_unsigned = true

		binds[9].buffer_type = .MYSQL_TYPE_LONGLONG
		binds[9].buffer = &_i64

		binds[10].buffer_type = .MYSQL_TYPE_FLOAT
		binds[10].buffer = &_f32

		binds[11].buffer_type = .MYSQL_TYPE_DOUBLE
		binds[11].buffer = &_f64

		_varchar_len := u64Len(_varchar)
		binds[12].buffer_type = .MYSQL_TYPE_VAR_STRING
		binds[12].buffer = raw_data(_varchar)
		binds[12].buffer_length = _varchar_len
		binds[12].length = &_varchar_len

		_text_len := u64Len(_text)
		binds[13].buffer_type = .MYSQL_TYPE_BLOB
		binds[13].buffer = raw_data(_text)
		binds[13].buffer_length = _text_len
		binds[13].length = &_text_len

		_blob_len := u64Len(_blob)
		binds[14].buffer_type = .MYSQL_TYPE_BLOB
		binds[14].buffer = raw_data(_blob)
		binds[14].buffer_length = _blob_len
		binds[14].length = &_blob_len

		binds[15].buffer_type = .MYSQL_TYPE_NULL
		binds[15].buffer = nil
		//------------------------------------------------------------
		// mysql_stmt_bind_param
		//------------------------------------------------------------
		status := mysql_stmt_bind_param(stmt, &binds[0])
		ut.compareInteger("mysql_stmt_bind_param: status", status, 0)
		ut.compareInteger("mysql_stmt_bind_param: mysql_stmt_errno", mysql_stmt_errno(stmt), 0)
		ut.compareCString("mysql_stmt_bind_param: mysql_stmt_error", mysql_stmt_error(stmt), "")
		//------------------------------------------------------------
		if status != 0 do return
		//------------------------------------------------------------
		// mysql_stmt_execute
		//------------------------------------------------------------
		rc = mysql_stmt_execute(stmt)
		ut.compareInteger("mysql_stmt_execute: rc", rc, 0)
		ut.compareInteger("mysql_stmt_execute: mysql_stmt_errno", mysql_stmt_errno(stmt), 0)
		ut.compareCString("mysql_stmt_execute: mysql_stmt_error", mysql_stmt_error(stmt), "")
		//------------------------------------------------------------
		if rc != 0 do return
		//------------------------------------------------------------
		_u8 = 22
		_i8 = 22
		_u16 = 22
		_i16 = 22
		_u24 = 22
		_i24 = 22
		_u32 = 22
		_i32 = 22
		_u64 = 22
		_i64 = 22
		_f32 = 22
		_f64 = 22

		_varchar = "22"
		_text = "22"
		_blob = stringToBytes("22")
		_blob_nullable := stringToBytes("22")

		_varchar_len = u64Len(_varchar)
		_text_len = u64Len(_text)
		_blob_len = u64Len(_blob)
		_blob_nullable_len := u64Len(_blob_nullable)

		binds[12].buffer_type = .MYSQL_TYPE_VAR_STRING
		binds[12].buffer = raw_data(_varchar)
		binds[12].buffer_length = _varchar_len
		binds[12].length = &_varchar_len

		binds[13].buffer_type = .MYSQL_TYPE_BLOB
		binds[13].buffer = raw_data(_text)
		binds[13].buffer_length = _text_len
		binds[13].length = &_text_len

		binds[14].buffer_type = .MYSQL_TYPE_BLOB
		binds[14].buffer = raw_data(_blob)
		binds[14].buffer_length = _blob_len
		binds[14].length = &_blob_len

		binds[15].buffer_type = .MYSQL_TYPE_BLOB
		binds[15].buffer = raw_data(_blob_nullable)
		binds[15].buffer_length = _blob_nullable_len
		binds[15].length = &_blob_nullable_len
		//------------------------------------------------------------
		status = mysql_stmt_bind_param(stmt, &binds[0])
		ut.compareInteger("mysql_stmt_bind_param: status", status, 0)
		ut.compareInteger("mysql_stmt_bind_param: mysql_stmt_errno", mysql_stmt_errno(stmt), 0)
		ut.compareCString("mysql_stmt_bind_param: mysql_stmt_error", mysql_stmt_error(stmt), "")
		//------------------------------------------------------------
		if status != 0 do return
		//------------------------------------------------------------
		rc = mysql_stmt_execute(stmt)
		ut.compareInteger("mysql_stmt_execute: rc", rc, 0)
		ut.compareInteger("mysql_stmt_execute: mysql_stmt_errno", mysql_stmt_errno(stmt), 0)
		ut.compareCString("mysql_stmt_execute: mysql_stmt_error", mysql_stmt_error(stmt), "")
		//------------------------------------------------------------
		if rc != 0 do return
		//------------------------------------------------------------
		_u8 = 33
		_i8 = 33
		_u16 = 33
		_i16 = 33
		_u24 = 33
		_i24 = 33
		_u32 = 33
		_i32 = 33
		_u64 = 33
		_i64 = 33
		_f32 = 33
		_f64 = 33

		_varchar = "33"
		_text = "33"
		_blob = stringToBytes("33")

		mem.zero(&binds, size_of(binds))

		binds[0] = bindColumn(&{buffer = &_u8, type_id = u8})
		binds[1] = bindColumn(&{buffer = &_i8, type_id = i8})
		binds[2] = bindColumn(&{buffer = &_u16, type_id = u16})
		binds[3] = bindColumn(&{buffer = &_i16, type_id = i16})
		binds[4] = bindColumn(&{buffer = &_u24, type_id = u32})
		binds[5] = bindColumn(&{buffer = &_i24, type_id = i32})
		binds[6] = bindColumn(&{buffer = &_u32, type_id = u32})
		binds[7] = bindColumn(&{buffer = &_i32, type_id = i32})
		binds[8] = bindColumn(&{buffer = &_u64, type_id = u64})
		binds[9] = bindColumn(&{buffer = &_i64, type_id = i64})
		binds[10] = bindColumn(&{buffer = &_f32, type_id = f32})
		binds[11] = bindColumn(&{buffer = &_f64, type_id = f64})

		binds[12] = bindColumn(
			&{buffer = raw_data(_varchar), length = u64Len(_varchar), type_id = string},
		)
		binds[13] = bindColumn(&{buffer = raw_data(_text), length = u64Len(_text), type_id = []u8})
		binds[14] = bindColumn(&{buffer = raw_data(_blob), length = u64Len(_blob), type_id = []u8})
		binds[15] = bindColumn()
		//------------------------------------------------------------
		status = mysql_stmt_bind_param(stmt, &binds[0])
		ut.compareInteger("mysql_stmt_bind_param: status", status, 0)
		ut.compareInteger("mysql_stmt_bind_param: mysql_stmt_errno", mysql_stmt_errno(stmt), 0)
		ut.compareCString("mysql_stmt_bind_param: mysql_stmt_error", mysql_stmt_error(stmt), "")
		//------------------------------------------------------------
		if status != 0 do return
		//------------------------------------------------------------
		rc = mysql_stmt_execute(stmt)
		ut.compareInteger("mysql_stmt_execute: rc", rc, 0)
		ut.compareInteger("mysql_stmt_execute: mysql_stmt_errno", mysql_stmt_errno(stmt), 0)
		ut.compareCString("mysql_stmt_execute: mysql_stmt_error", mysql_stmt_error(stmt), "")
		//------------------------------------------------------------
		if rc != 0 do return
		//------------------------------------------------------------
		affected := mysql_stmt_affected_rows(stmt)
		ut.compareInteger("mysql_stmt_affected_rows", affected, 1)
		//------------------------------------------------------------
		insert_id := mysql_stmt_insert_id(stmt)
		ut.compareInteger("mysql_stmt_insert_id", insert_id, 3)
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		// mysql_stmt_init
		//------------------------------------------------------------
		sql: cstring = "SELECT * FROM test"
		stmt := mysql_stmt_init(db_handle)
		ut.compareTypeID("mysql_stmt_init: stmt", type_of(stmt), ^MYSQL_STMT)
		ut.compareInteger("mysql_stmt_init: mysql_errno", mysql_errno(db_handle), 0)
		ut.compareCString("mysql_stmt_init: mysql_error", mysql_error(db_handle), "")
		//------------------------------------------------------------
		defer mysql_stmt_close(stmt)
		//------------------------------------------------------------
		// mysql_stmt_prepare
		//------------------------------------------------------------
		rc := mysql_stmt_prepare(stmt, sql, u64Len(sql))
		ut.compareInteger("mysql_stmt_prepare: rc", rc, 0)
		ut.compareInteger("mysql_stmt_prepare: mysql_stmt_errno", mysql_stmt_errno(stmt), 0)
		ut.compareCString("mysql_stmt_prepare: mysql_stmt_error", mysql_stmt_error(stmt), "")
		//------------------------------------------------------------
		if rc != 0 do return
		//------------------------------------------------------------
		// mysql_stmt_execute
		//------------------------------------------------------------
		rc = mysql_stmt_execute(stmt)
		ut.compareInteger("mysql_stmt_execute: rc", rc, 0)
		ut.compareInteger("mysql_stmt_execute: mysql_stmt_errno", mysql_stmt_errno(stmt), 0)
		ut.compareCString("mysql_stmt_execute: mysql_stmt_error", mysql_stmt_error(stmt), "")
		//------------------------------------------------------------
		if rc != 0 do return
		//------------------------------------------------------------
		id: u32
		_u8: u8
		_i8: i8
		_u16: u16
		_i16: i16
		_u24: u32 // odin does not have u24
		_i24: i32 // odin does not have u24
		_u32: u32
		_i32: i32
		_u64: u64
		_i64: i64
		_f32: f32
		_f64: f64

		_varchar: [256]u8 // 256 used for testing only
		_text: [256]u8 // 256 used for testing only
		_blob: [256]u8 // 256 used for testing only
		_blob_nullable: [256]u8 // 256 used for testing only

		bind_varchar: MySQLBind
		bind_text: MySQLBind
		bind_blob: MySQLBind
		bind_blob_nullable: MySQLBind
		//------------------------------------------------------------
		binds: [17]MYSQL_BIND

		mem.zero(&binds, len(binds))

		binds[0] = bindColumn(&{buffer = &id, type_id = u32})
		binds[1] = bindColumn(&{buffer = &_u8, type_id = u8})
		binds[2] = bindColumn(&{buffer = &_i8, type_id = i8})
		binds[3] = bindColumn(&{buffer = &_u16, type_id = u16})
		binds[4] = bindColumn(&{buffer = &_i16, type_id = i16})
		binds[5] = bindColumn(&{buffer = &_u24, type_id = u32})
		binds[6] = bindColumn(&{buffer = &_i24, type_id = i32})
		binds[7] = bindColumn(&{buffer = &_u32, type_id = u32})
		binds[8] = bindColumn(&{buffer = &_i32, type_id = i32})
		binds[9] = bindColumn(&{buffer = &_u64, type_id = u64})
		binds[10] = bindColumn(&{buffer = &_i64, type_id = i64})
		binds[11] = bindColumn(&{buffer = &_f32, type_id = f32})
		binds[12] = bindColumn(&{buffer = &_f64, type_id = f64})

		bind_varchar = MySQLBind {
			buffer  = &(_varchar[0]),
			length  = u64Len(_varchar),
			type_id = []u8,
		}
		binds[13] = bindColumn(&bind_varchar)

		bind_text = MySQLBind {
			buffer  = &(_text[0]),
			length  = u64Len(_text),
			type_id = []u8,
		}
		binds[14] = bindColumn(&bind_text)

		bind_blob = MySQLBind {
			buffer  = &(_blob[0]),
			length  = u64Len(_blob),
			type_id = []u8,
		}
		binds[15] = bindColumn(&bind_blob)

		bind_blob_nullable = MySQLBind {
			buffer  = &(_blob_nullable[0]),
			length  = u64Len(_blob_nullable),
			type_id = []u8,
		}
		binds[16] = bindColumn(&bind_blob_nullable)
		//------------------------------------------------------------
		// mysql_stmt_bind_result
		//------------------------------------------------------------
		status := mysql_stmt_bind_result(stmt, &binds[0])
		ut.compareInteger("mysql_stmt_bind_result: status", status, 0)
		ut.compareInteger("mysql_stmt_bind_result: mysql_stmt_errno", mysql_stmt_errno(stmt), 0)
		ut.compareCString("mysql_stmt_bind_result: mysql_stmt_error", mysql_stmt_error(stmt), "")
		//------------------------------------------------------------
		if status != 0 do return
		//------------------------------------------------------------
		// mysql_stmt_fetch
		//------------------------------------------------------------
		rc = mysql_stmt_fetch(stmt)
		//------------------------------------------------------------
		ut.compareInteger("mysql_stmt_fetch: rc", rc, 0)
		ut.compareCString("mysql_stmt_fetch: mysql_stmt_error", mysql_stmt_error(stmt), "")
		ut.compareCString("mysql_stmt_fetch: mysql_stmt_error", mysql_stmt_error(stmt), "")
		//------------------------------------------------------------
		ut.compareInteger("mysql_stmt_fetch: id", id, 1)
		//------------------------------------------------------------
		ut.compareInteger("mysql_stmt_fetch: _u8", _u8, 8)
		ut.compareInteger("mysql_stmt_fetch: _i8", _i8, -8)
		ut.compareInteger("mysql_stmt_fetch: _u16", _u16, 16)
		ut.compareInteger("mysql_stmt_fetch: _i16", _i16, -16)
		ut.compareInteger("mysql_stmt_fetch: _u24", _u24, 24)
		ut.compareInteger("mysql_stmt_fetch: _i24", _i24, -24)
		ut.compareInteger("mysql_stmt_fetch: _u32", _u32, 32)
		ut.compareInteger("mysql_stmt_fetch: _i32", _i32, -32)
		ut.compareInteger("mysql_stmt_fetch: _u64", _u64, 64)
		ut.compareInteger("mysql_stmt_fetch: _i64", _i64, -64)
		ut.compareFloat("mysql_stmt_fetch: _f32", _f32, 32.32)
		ut.compareFloat("mysql_stmt_fetch: _f64", _f64, 64.64)
		//------------------------------------------------------------
		ut.compareString(
			"mysql_stmt_fetch: _varchar",
			string(_varchar[:bind_varchar.length]),
			"_varchar",
		)
		ut.compareString("mysql_stmt_fetch: _text", string(_text[:bind_text.length]), "_text")
		ut.compareString("mysql_stmt_fetch: _blob", string(_blob[:bind_blob.length]), "_blob")
		ut.compareBool("mysql_stmt_fetch: _blob_nullable", bool(bind_blob_nullable.is_null), true)
		ut.compareInteger("mysql_stmt_fetch: _varchar_len", bind_varchar.length, 8)
		ut.compareInteger("mysql_stmt_fetch: _text_len", bind_text.length, 5)
		ut.compareInteger("mysql_stmt_fetch: _blob_len", bind_blob.length, 5)
		ut.compareInteger("mysql_stmt_fetch: _blob_nullable_len", bind_blob_nullable.length, 0)
		//------------------------------------------------------------
		// mysql_stmt_fetch
		//------------------------------------------------------------
		rc = mysql_stmt_fetch(stmt)
		//------------------------------------------------------------
		ut.compareInteger("mysql_stmt_fetch: rc", rc, 0)
		ut.compareInteger("mysql_stmt_fetch: mysql_stmt_errno", mysql_stmt_errno(stmt), 0)
		ut.compareCString("mysql_stmt_fetch: mysql_stmt_error", mysql_stmt_error(stmt), "")
		//------------------------------------------------------------
		ut.compareInteger("mysql_stmt_fetch: id", id, 2)
		//------------------------------------------------------------
		ut.compareInteger("mysql_stmt_fetch: _u8", _u8, 22)
		ut.compareInteger("mysql_stmt_fetch: _i8", _i8, 22)
		ut.compareInteger("mysql_stmt_fetch: _u16", _u16, 22)
		ut.compareInteger("mysql_stmt_fetch: _i16", _i16, 22)
		ut.compareInteger("mysql_stmt_fetch: _u24", _u24, 22)
		ut.compareInteger("mysql_stmt_fetch: _i24", _i24, 22)
		ut.compareInteger("mysql_stmt_fetch: _u32", _u32, 22)
		ut.compareInteger("mysql_stmt_fetch: _i32", _i32, 22)
		ut.compareInteger("mysql_stmt_fetch: _u64", _u64, 22)
		ut.compareInteger("mysql_stmt_fetch: _i64", _i64, 22)
		ut.compareFloat("mysql_stmt_fetch: _f32", _f32, 22)
		ut.compareFloat("mysql_stmt_fetch: _f64", _f64, 22)
		//------------------------------------------------------------
		ut.compareString(
			"mysql_stmt_fetch: _varchar",
			string(_varchar[:bind_varchar.length]),
			"22",
		)
		ut.compareString("mysql_stmt_fetch: _text", string(_text[:bind_text.length]), "22")
		ut.compareString("mysql_stmt_fetch: _blob", string(_blob[:bind_blob.length]), "22")
		ut.compareBool("mysql_stmt_fetch: _blob_nullable", bool(bind_blob_nullable.is_null), false)
		ut.compareInteger("mysql_stmt_fetch: _varchar_len", bind_varchar.length, 2)
		ut.compareInteger("mysql_stmt_fetch: _text_len", bind_text.length, 2)
		ut.compareInteger("mysql_stmt_fetch: _blob_len", bind_blob.length, 2)
		ut.compareInteger("mysql_stmt_fetch: _blob_nullable_len", bind_blob_nullable.length, 2)
		//------------------------------------------------------------
		// mysql_stmt_fetch
		//------------------------------------------------------------
		rc = mysql_stmt_fetch(stmt)
		//------------------------------------------------------------
		ut.compareInteger("mysql_stmt_fetch: rc", rc, 0)
		ut.compareInteger("mysql_stmt_fetch: mysql_stmt_errno", mysql_stmt_errno(stmt), 0)
		ut.compareCString("mysql_stmt_fetch: mysql_stmt_error", mysql_stmt_error(stmt), "")
		//------------------------------------------------------------
		ut.compareInteger("mysql_stmt_fetch: id", id, 3)
		//------------------------------------------------------------
		ut.compareInteger("mysql_stmt_fetch: _u8", _u8, 33)
		ut.compareInteger("mysql_stmt_fetch: _i8", _i8, 33)
		ut.compareInteger("mysql_stmt_fetch: _u16", _u16, 33)
		ut.compareInteger("mysql_stmt_fetch: _i16", _i16, 33)
		ut.compareInteger("mysql_stmt_fetch: _u24", _u24, 33)
		ut.compareInteger("mysql_stmt_fetch: _i24", _i24, 33)
		ut.compareInteger("mysql_stmt_fetch: _u32", _u32, 33)
		ut.compareInteger("mysql_stmt_fetch: _i32", _i32, 33)
		ut.compareInteger("mysql_stmt_fetch: _u64", _u64, 33)
		ut.compareInteger("mysql_stmt_fetch: _i64", _i64, 33)
		ut.compareFloat("mysql_stmt_fetch: _f32", _f32, 33)
		ut.compareFloat("mysql_stmt_fetch: _f64", _f64, 33)
		//------------------------------------------------------------
		ut.compareString(
			"mysql_stmt_fetch: _varchar",
			string(_varchar[:bind_varchar.length]),
			"33",
		)
		ut.compareString("mysql_stmt_fetch: _text", string(_text[:bind_text.length]), "33")
		ut.compareString("mysql_stmt_fetch: _blob", string(_blob[:bind_blob.length]), "33")
		ut.compareBool("mysql_stmt_fetch: _blob_nullable", bool(bind_blob_nullable.is_null), true)
		ut.compareInteger("mysql_stmt_fetch: _varchar_len", bind_varchar.length, 2)
		ut.compareInteger("mysql_stmt_fetch: _text_len", bind_text.length, 2)
		ut.compareInteger("mysql_stmt_fetch: _blob_len", bind_blob.length, 2)
		ut.compareInteger("mysql_stmt_fetch: _blob_nullable_len", bind_blob_nullable.length, 0)
		//------------------------------------------------------------
		// mysql_stmt_fetch
		//------------------------------------------------------------
		rc = mysql_stmt_fetch(stmt)
		//------------------------------------------------------------
		ut.compareInteger("mysql_stmt_fetch: rc", rc, MYSQL_NO_DATA)
		ut.compareInteger("mysql_stmt_fetch: mysql_stmt_errno", mysql_stmt_errno(stmt), 0)
		ut.compareCString("mysql_stmt_fetch: mysql_stmt_error", mysql_stmt_error(stmt), "")
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		// mysql_stmt_init
		//------------------------------------------------------------
		sql: cstring = "SELECT * FROM test"
		stmt := mysql_stmt_init(db_handle)
		ut.compareTypeID("mysql_stmt_init: stmt", type_of(stmt), ^MYSQL_STMT)
		ut.compareInteger("mysql_stmt_init: mysql_errno", mysql_errno(db_handle), 0)
		ut.compareCString("mysql_stmt_init: mysql_error", mysql_error(db_handle), "")
		//------------------------------------------------------------
		defer mysql_stmt_close(stmt)
		//------------------------------------------------------------
		// mysql_stmt_prepare
		//------------------------------------------------------------
		rc := mysql_stmt_prepare(stmt, sql, u64Len(sql))
		ut.compareInteger("mysql_stmt_prepare: rc", rc, 0)
		ut.compareInteger("mysql_stmt_prepare: mysql_stmt_errno", mysql_stmt_errno(stmt), 0)
		ut.compareCString("mysql_stmt_prepare: mysql_stmt_error", mysql_stmt_error(stmt), "")
		//------------------------------------------------------------
		if rc != 0 do return
		//------------------------------------------------------------
		// mysql_stmt_execute
		//------------------------------------------------------------
		rc = mysql_stmt_execute(stmt)
		ut.compareInteger("mysql_stmt_execute: rc", rc, 0)
		ut.compareInteger("mysql_stmt_execute: mysql_stmt_errno", mysql_stmt_errno(stmt), 0)
		ut.compareCString("mysql_stmt_execute: mysql_stmt_error", mysql_stmt_error(stmt), "")
		//------------------------------------------------------------
		if rc != 0 do return
		//------------------------------------------------------------
		// mysql_stmt_fetch
		//------------------------------------------------------------
		rc = mysql_stmt_fetch(stmt)
		ut.compareInteger("mysql_stmt_fetch: rc", rc, 0)
		//------------------------------------------------------------
		if rc != 0 do return
		//------------------------------------------------------------
		// mysql_stmt_fetch_column (called by fetchColumn* below)
		//------------------------------------------------------------
		id: u32
		_u8: u8
		_i8: i8
		_u16: u16
		_i16: i16
		_u24: u32 // odin does not have u24
		_i24: i32 // odin does not have i24
		_u32: u32
		_i32: i32
		_u64: u64
		_i64: i64
		_f32: f32
		_f64: f64
		//------------------------------------------------------------
		err: Error
		//------------------------------------------------------------
		id, err = fetchColumnUInt32(stmt, 0)
		ut.compareInteger("fetchColumnUInt32: id", id, 1)
		ut.compareInteger("fetchColumnUInt32: err", err, nil)
		//------------------------------------------------------------
		_u8, err = fetchColumnUInt8(stmt, 1)
		ut.compareInteger("fetchColumnUInt8: _u8", _u8, 8)
		ut.compareInteger("fetchColumnUInt8: err", err, nil)
		//------------------------------------------------------------
		_i8, err = fetchColumnInt8(stmt, 2)
		ut.compareInteger("fetchColumnInt8: _i8", _i8, -8)
		ut.compareInteger("fetchColumnInt8: err", err, nil)
		//------------------------------------------------------------
		_u16, err = fetchColumnUInt16(stmt, 3)
		ut.compareInteger("fetchColumnUInt16: _u16", _u16, 16)
		ut.compareInteger("fetchColumnUInt16: err", err, nil)
		//------------------------------------------------------------
		_i16, err = fetchColumnInt16(stmt, 4)
		ut.compareInteger("fetchColumnInt16: _i16", _i16, -16)
		ut.compareInteger("fetchColumnInt16: err", err, nil)
		//------------------------------------------------------------
		_u24, err = fetchColumnUInt24(stmt, 5)
		ut.compareInteger("fetchColumnUInt24: _u24", _u24, 24)
		ut.compareInteger("fetchColumnUInt24: err", err, nil)
		//------------------------------------------------------------
		_i24, err = fetchColumnInt24(stmt, 6)
		ut.compareInteger("fetchColumnInt24: _i24", _i24, -24)
		ut.compareInteger("fetchColumnInt24: err", err, nil)
		//------------------------------------------------------------
		_u32, err = fetchColumnUInt32(stmt, 7)
		ut.compareInteger("fetchColumnUInt8: _u32", _u32, 32)
		ut.compareInteger("fetchColumnUInt8: err", err, nil)
		//------------------------------------------------------------
		_i32, err = fetchColumnInt32(stmt, 8)
		ut.compareInteger("fetchColumnInt32: _i32", _i32, -32)
		ut.compareInteger("fetchColumnInt32: err", err, nil)
		//------------------------------------------------------------
		_u64, err = fetchColumnUInt64(stmt, 9)
		ut.compareInteger("fetchColumnUInt64: _u64", _u64, 64)
		ut.compareInteger("fetchColumnUInt64: err", err, nil)
		//------------------------------------------------------------
		_i64, err = fetchColumnInt64(stmt, 10)
		ut.compareInteger("fetchColumnInt64: _i64", _i64, -64)
		ut.compareInteger("fetchColumnInt64: err", err, nil)
		//------------------------------------------------------------
		_f32, err = fetchColumnFloat32(stmt, 11)
		ut.compareInteger("fetchColumnFloat32: _f32", _f32, f32(32.32))
		ut.compareInteger("fetchColumnFloat32: err", err, nil)
		//------------------------------------------------------------
		_f64, err = fetchColumnFloat64(stmt, 12)
		ut.compareInteger("fetchColumnFloat64: _f64", _f64, f64(64.64))
		ut.compareInteger("fetchColumnFloat64: err", err, nil)
		//------------------------------------------------------------
		{
			buffer: [256]u8
			n, err := fetchColumnBuffer(stmt, 13, buffer[:])
			ut.compareString("fetchColumnBuffer: _varchar", string(buffer[:n]), "_varchar")
			ut.compareInteger("fetchColumnBuffer: n", n, 8)
			ut.compareInteger("fetchColumnBuffer: err", err, nil)
		}
		//------------------------------------------------------------
		{
			_varchar, err := fetchColumnString(stmt, 13)
			defer delete(_varchar)
			ut.compareString("fetchColumnString: _varchar", _varchar, "_varchar")
			ut.compareInteger("fetchColumnString: _varchar", len(_varchar), 8)
			ut.compareInteger("fetchColumnString: err", err, nil)
		}
		//------------------------------------------------------------
		{
			_varchar, err := fetchColumnCString(stmt, 13)
			defer delete(_varchar)
			ut.compareCString("fetchColumnCString: _varchar", _varchar, "_varchar")
			ut.compareInteger("fetchColumnCString: _varchar", len(_varchar), 8)
			ut.compareInteger("fetchColumnCString: err", err, nil)
		}
		//------------------------------------------------------------
		{
			_text, err := fetchColumnBlob(stmt, 14)
			defer delete(_text)
			ut.compareBytes("fetchColumnBlob: _text", _text, []u8{'_', 't', 'e', 'x', 't'})
			ut.compareInteger("fetchColumnBlob: _text", len(_text), 5)
			ut.compareInteger("fetchColumnBlob: err", err, nil)
		}
		//------------------------------------------------------------
		{
			_blob, err := fetchColumnBlob(stmt, 15)
			defer delete(_blob)
			ut.compareBytes("fetchColumnBlob: _blob", _blob, []u8{'_', 'b', 'l', 'o', 'b'})
			ut.compareInteger("fetchColumnBlob: _blob", len(_blob), 5)
			ut.compareInteger("fetchColumnBlob: err", err, nil)
		}
		//------------------------------------------------------------
		{
			_blob_nullable, err := fetchColumnBlob(stmt, 16)
			defer delete(_blob_nullable)
			ut.compareBytes("fetchColumnBlob: _blob_nullable", _blob_nullable, []u8{})
			ut.compareInteger("fetchColumnBlob: _blob_nullable", len(_blob_nullable), 0)
			ut.compareInteger("fetchColumnBlob: err", err, nil)
		}
		//------------------------------------------------------------
		// updateMySQLColumn
		//------------------------------------------------------------
		mysql_column: MySQLColumn
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 0, &mysql_column)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 0)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "id")
			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.uint32)
			value, _ := mysql_column.value.(u32)
			ut.compareInteger("updateMySQLColumn: uint32", value, 1)
		}
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 1, &mysql_column)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 1)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "_u8")

			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.uint8)
			value, _ := mysql_column.value.(u8)
			ut.compareInteger("updateMySQLColumn: uint8", value, 8)
		}
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 2, &mysql_column)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 2)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "_i8")

			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.int8)
			value, _ := mysql_column.value.(i8)
			ut.compareInteger("updateMySQLColumn: int8", value, -8)
		}
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 3, &mysql_column)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 3)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "_u16")

			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.uint16)
			value, _ := mysql_column.value.(u16)
			ut.compareInteger("updateMySQLColumn: uint16", value, 16)
		}
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 4, &mysql_column)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 4)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "_i16")
			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.int16)
			value, _ := mysql_column.value.(i16)
			ut.compareInteger("updateMySQLColumn: int16", value, -16)
		}
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 5, &mysql_column)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 5)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "_u24")
			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.uint24)
			value, _ := mysql_column.value.(u32)
			ut.compareInteger("updateMySQLColumn: uint24", value, 24)
		}
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 6, &mysql_column)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 6)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "_i24")
			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.int24)
			value, _ := mysql_column.value.(i32)
			ut.compareInteger("updateMySQLColumn: int24", value, -24)
		}
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 7, &mysql_column)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 7)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "_u32")
			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.uint32)
			value, _ := mysql_column.value.(u32)
			ut.compareInteger("updateMySQLColumn: uint32", value, 32)
		}
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 8, &mysql_column)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 8)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "_i32")
			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.int32)
			value, _ := mysql_column.value.(i32)
			ut.compareInteger("updateMySQLColumn: int32", value, -32)
		}
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 9, &mysql_column)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 9)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "_u64")
			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.uint64)
			value, _ := mysql_column.value.(u64)
			ut.compareInteger("updateMySQLColumn: uint64", value, 64)
		}
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 10, &mysql_column)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 10)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "_i64")
			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.int64)
			value, _ := mysql_column.value.(i64)
			ut.compareInteger("updateMySQLColumn: int64", value, -64)
		}
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 11, &mysql_column)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 11)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "_f32")
			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.float32)
			value, _ := mysql_column.value.(f32)
			ut.compareFloat("updateMySQLColumn: float32", value, 32.32)
		}
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 12, &mysql_column)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 12)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "_f64")
			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.float64)
			value, _ := mysql_column.value.(f64)
			ut.compareFloat("updateMySQLColumn: float64", value, 64.64)
		}
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 13, &mysql_column, context.allocator)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 13)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "_varchar")
			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.string)
			value, _ := mysql_column.value.(string)
			ut.compareString("updateMySQLColumn: string", value, "_varchar")
		}
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 14, &mysql_column, context.allocator)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 14)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "_text")
			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.blob)
			value, _ := mysql_column.value.([]u8)
			ut.compareString("updateMySQLColumn: blob", string(value), "_text")
		}
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 15, &mysql_column, context.allocator)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 15)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "_blob")
			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.blob)
			value, _ := mysql_column.value.([]u8)
			ut.compareString("updateMySQLColumn: blob", string(value), "_blob")

		}
		//------------------------------------------------------------
		{
			err = updateMySQLColumn(stmt, 16, &mysql_column, context.allocator)
			defer freeMySQLColumn(&mysql_column)

			ut.compareError("updateMySQLColumn", err, nil)
			ut.compareInteger("updateMySQLColumn: index", mysql_column.index, 16)
			ut.compareString("updateMySQLColumn: name", mysql_column.name, "_blob_nullable")
			ut.compareEnum("updateMySQLColumn: type", mysql_column.type, ColumnType.blob)
			value, _ := mysql_column.value.([]u8)
			ut.compareString("updateMySQLColumn: blob", string(value), "")
		}
		//------------------------------------------------------------
		// getMySQLRow
		//------------------------------------------------------------
		fixed_row := FixedRow{}
		//------------------------------------------------------------
		defer {
			delete(fixed_row._varchar)
			delete(fixed_row._text)
			delete(fixed_row._blob)
			delete(fixed_row._blob_nullable)
		}
		//------------------------------------------------------------
		err = getMySQLRow(stmt, &fixed_row)
		ut.compareError("getMySQLRow", err, nil)
		ut.compareInteger("getMySQLRow: id", fixed_row.id, 1)
		ut.compareInteger("getMySQLRow: _u8", fixed_row._u8, 8)
		ut.compareInteger("getMySQLRow: _i8", fixed_row._i8, -8)
		ut.compareInteger("getMySQLRow: _u16", fixed_row._u16, 16)
		ut.compareInteger("getMySQLRow: _i16", fixed_row._i16, -16)
		ut.compareInteger("getMySQLRow: _u24", fixed_row._u24, 24)
		ut.compareInteger("getMySQLRow: _i24", fixed_row._i24, -24)
		ut.compareInteger("getMySQLRow: _u32", fixed_row._u32, 32)
		ut.compareInteger("getMySQLRow: _i32", fixed_row._i32, -32)
		ut.compareInteger("getMySQLRow: _u64", fixed_row._u64, 64)
		ut.compareInteger("getMySQLRow: _i64", fixed_row._i64, -64)
		ut.compareFloat("getMySQLRow: _f32", fixed_row._f32, 32.32)
		ut.compareFloat("getMySQLRow: _f64", fixed_row._f64, 64.64)
		ut.compareString("getMySQLRow: _varchar", fixed_row._varchar, "_varchar")
		ut.compareBytes("getMySQLRow: _text", fixed_row._text, []u8{'_', 't', 'e', 'x', 't'})
		ut.compareBytes("getMySQLRow: _blob", fixed_row._blob, []u8{'_', 'b', 'l', 'o', 'b'})
		ut.compareBytes("getMySQLRow: _blob_nullable", fixed_row._blob_nullable, []u8{})
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		// getMySQLColumnsTable
		//------------------------------------------------------------
		table, err := getMySQLColumnsTable(nil, "")
		ut.compareError("updateMySQLColumn", err, MySQLError.InvalidDBHandle)
		//------------------------------------------------------------
		table, err = getMySQLColumnsTable(db_handle, "SELECT * FROM test;")
		defer freeMySQLColumnsTable(table)

		ut.compareError("updateMySQLColumn", err, nil)
		ut.compareInteger("getMySQLColumnsTable: row_count", table.row_count, 3)
		ut.compareInteger("getMySQLColumnsTable: column_count", table.column_count, 17)
		//------------------------------------------------------------
		ut.compareInteger("getMySQLColumnsTable: mysql_columns", len(table.mysql_columns), 51)
		//------------------------------------------------------------
		mysql_column: MySQLColumn
		index: int
		name: string
		type: ColumnType
		value: ColumnValue
		value_uint8: u8
		value_int8: i8
		value_uint16: u16
		value_int16: i16
		value_uint24: u32
		value_int24: i32
		value_uint32: u32
		value_int32: i32
		value_uint64: u64
		value_int64: i64
		value_float32: f32
		value_float64: f64
		value_string: string
		value_blob: []u8
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[0]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_uint32, _ = mysql_column.value.(u32)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 0)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "id")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.uint32)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_uint32, 1)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[1]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_uint8, _ = mysql_column.value.(u8)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 1)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_u8")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.uint8)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_uint8, 8)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[2]
		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_int8, _ = mysql_column.value.(i8)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 2)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_i8")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.int8)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_int8, -8)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[3]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_uint16, _ = mysql_column.value.(u16)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 3)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_u16")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.uint16)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_uint16, 16)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[4]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_int16, _ = mysql_column.value.(i16)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 4)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_i16")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.int16)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_int16, -16)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[5]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_uint24, _ = mysql_column.value.(u32)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 5)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_u24")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.uint24)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_uint24, 24)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[6]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_int24, _ = mysql_column.value.(i32)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 6)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_i24")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.int24)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_int24, -24)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[7]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_uint32, _ = mysql_column.value.(u32)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 7)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_u32")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.uint32)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_uint32, 32)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[8]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_int32, _ = mysql_column.value.(i32)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 8)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_i32")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.int32)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_int32, -32)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[9]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_uint64, _ = mysql_column.value.(u64)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 9)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_u64")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.uint64)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_uint64, 64)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[10]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_int64, _ = mysql_column.value.(i64)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 10)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_i64")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.int64)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_int64, -64)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[11]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_float32, _ = mysql_column.value.(f32)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 11)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_f32")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.float32)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_float32, 32.32)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[12]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_float64, _ = mysql_column.value.(f64)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 12)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_f64")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.float64)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_float64, 64.64)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[13]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_string, _ = mysql_column.value.(string)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 13)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_varchar")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.string)
		ut.compareString("getMySQLColumnsTable: mysql_columns: value", value_string, "_varchar")
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[14]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_blob, _ = mysql_column.value.([]u8)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 14)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_text")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.blob)
		ut.compareString("getMySQLColumnsTable: mysql_columns: value", string(value_blob), "_text")
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[15]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_blob, _ = mysql_column.value.([]u8)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 15)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_blob")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.blob)
		ut.compareString("getMySQLColumnsTable: mysql_columns: value", string(value_blob), "_blob")
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[16]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_blob, _ = mysql_column.value.([]u8)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 16)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_blob_nullable")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.blob)
		ut.compareString("getMySQLColumnsTable: mysql_columns: value", string(value_blob), "")
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[17]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_uint32, _ = mysql_column.value.(u32)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 0)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "id")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.uint32)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_uint32, 2)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[18]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_uint8, _ = mysql_column.value.(u8)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 1)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_u8")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.uint8)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_uint8, 22)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[19]
		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_int8, _ = mysql_column.value.(i8)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 2)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_i8")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.int8)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_int8, 22)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[20]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_uint16, _ = mysql_column.value.(u16)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 3)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_u16")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.uint16)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_uint16, 22)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[21]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_int16, _ = mysql_column.value.(i16)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 4)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_i16")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.int16)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_int16, 22)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[22]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_uint24, _ = mysql_column.value.(u32)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 5)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_u24")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.uint24)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_uint24, 22)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[23]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_int24, _ = mysql_column.value.(i32)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 6)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_i24")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.int24)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_int24, 22)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[24]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_uint32, _ = mysql_column.value.(u32)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 7)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_u32")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.uint32)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_uint32, 22)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[25]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_int32, _ = mysql_column.value.(i32)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 8)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_i32")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.int32)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_int32, 22)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[26]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_uint64, _ = mysql_column.value.(u64)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 9)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_u64")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.uint64)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_uint64, 22)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[27]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_int64, _ = mysql_column.value.(i64)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 10)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_i64")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.int64)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_int64, 22)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[28]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_float32, _ = mysql_column.value.(f32)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 11)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_f32")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.float32)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_float32, 22)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[29]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_float64, _ = mysql_column.value.(f64)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 12)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_f64")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.float64)
		ut.compareInteger("getMySQLColumnsTable: mysql_columns: value", value_float64, 22)
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[30]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_string, _ = mysql_column.value.(string)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 13)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_varchar")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.string)
		ut.compareString("getMySQLColumnsTable: mysql_columns: value", value_string, "22")
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[31]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_blob, _ = mysql_column.value.([]u8)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 14)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_text")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.blob)
		ut.compareString("getMySQLColumnsTable: mysql_columns: value", string(value_blob), "22")
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[32]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_blob, _ = mysql_column.value.([]u8)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 15)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_blob")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.blob)
		ut.compareString("getMySQLColumnsTable: mysql_columns: value", string(value_blob), "22")
		//------------------------------------------------------------
		mysql_column = table.mysql_columns[33]

		index = mysql_column.index
		name = mysql_column.name
		type = mysql_column.type
		value_blob, _ = mysql_column.value.([]u8)

		ut.compareInteger("getMySQLColumnsTable: mysql_columns: index", index, 16)
		ut.compareString("getMySQLColumnsTable: mysql_columns: name", name, "_blob_nullable")
		ut.compareEnum("getMySQLColumnsTable: mysql_columns: type", type, ColumnType.blob)
		ut.compareString("getMySQLColumnsTable: mysql_columns: value", string(value_blob), "22")
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	//################################################################################
	//--------------------------------------------------------------------------------
	ut.printSummary()
	//--------------------------------------------------------------------------------
	//################################################################################
	//--------------------------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
