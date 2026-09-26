//--------------------------------------------------------------------------------
package sqlite
//--------------------------------------------------------------------------------
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:strings"
import ut "libs/unittest"
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
DATABASE_FILEPATH :: "test-sqlite.db"
//--------------------------------------------------------------------------------
StringColumn :: struct {
	key:   string,
	value: string,
}
//--------------------------------------------------------------------------------
FixedRow :: struct {
	id:      i64,
	uint64:  u64,
	integer: i64,
	float:   f64,
	text:    string,
	blob:    []u8,
}
//--------------------------------------------------------------------------------
CallbackContext :: struct {
	//----------------------------------------
	allocator:      mem.Allocator,
	string_columns: [dynamic]StringColumn,
	fixed_rows:     [dynamic]FixedRow,
	//----------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
main :: proc() {
	//--------------------------------------------------------------------------------
	ut.init({show_passes = false, skip_after_fail = true})
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
	//------------------------------------------------------------
	ctx := CallbackContext {
		allocator = context.allocator,
	}
	//------------------------------------------------------------
	defer {
		//----------------------------------------
		for row in ctx.string_columns {
			delete(row.key)
			delete(row.value)
		}
		delete(ctx.string_columns)
		//----------------------------------------
		for row in ctx.fixed_rows {
			delete(row.text)
			delete(row.blob)
		}
		delete(ctx.fixed_rows)
		//----------------------------------------
	}
	//--------------------------------------------------------------------------------
	//################################################################################
	//--------------------------------------------------------------------------------
	// init
	//--------------------------------------------------------------------------------
	sqlitedb := init()
	ut.compareTypeID("init: SQLiteDB", type_of(sqlitedb), SQLiteDB)
	//--------------------------------------------------------------------------------
	// connect
	//--------------------------------------------------------------------------------
	err := connect(&sqlitedb, DATABASE_FILEPATH)
	//------------------------------------------------------------
	ut.compareError("connect", err, nil)
	//------------------------------------------------------------
	if err != nil do return
	//--------------------------------------------------------------------------------
	defer close(&sqlitedb)
	//--------------------------------------------------------------------------------
	// sqliteExec / sqliteFree
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		sql: cstring = `PRAGMA journal_mode=WAL;
			DROP TABLE IF EXISTS test;
			CREATE TABLE IF NOT EXISTS test (id INTEGER PRIMARY KEY AUTOINCREMENT, uint64 INTEGER DEFAULT 0 NOT NULL, integer INTEGER DEFAULT 0 NOT NULL, float REAL DEFAULT 0 NOT NULL, text VARCHAR(255) DEFAULT '' NOT NULL, blob BLOB);
	 		INSERT INTO test (uint64, integer, float, text, blob) VALUES(1, 1, 1.1, 'text1', X'626C6F6231');
		 	SELECT * FROM test;`
		//------------------------------------------------------------
		errmsg: rawptr = nil
		rc := sqliteExec(&sqlitedb, sql, execCallback, cast(rawptr)&ctx, &errmsg)
		if rc != SQLITE_OK {defer sqliteFree(errmsg)}
		//------------------------------------------------------------
		ut.compareInteger("sqliteExec: rc", rc, SQLITE_OK)
		ut.compareCString("sqliteExec: errmsg", cstring(errmsg), nil)
		ut.compareInteger("sqliteExec: string_columns", len(ctx.string_columns), 7)
		if len(ctx.string_columns) > 1 {
			ut.compareString("sqliteExec: key", ctx.string_columns[0].key, "journal_mode")
			ut.compareString("sqliteExec: value", ctx.string_columns[0].value, "wal")
			ut.compareString("sqliteExec: key", ctx.string_columns[1].key, "id")
			ut.compareString("sqliteExec: value", ctx.string_columns[1].value, "1")
		}
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	// sqlitePrepare / sqliteClearBindings / sqliteBind* / sqliteStep / sqliteFinalize
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		stmt_handle: ^rawptr
		//------------------------------------------------------------
		sql := cstring(
			"INSERT INTO test (uint64, integer, float, text, blob) VALUES(?, ?, ?, ?, ?);",
		)
		//------------------------------------------------------------
		rc := sqlitePrepare(&sqlitedb, sql, &stmt_handle)
		//------------------------------------------------------------
		defer sqliteFinalize(&sqlitedb, stmt_handle)
		//------------------------------------------------------------
		ut.compareInteger("sqlitePrepare: rc", rc, SQLITE_OK)
		ut.compareCString("sqlitePrepare: errmsg", errorMessage(&sqlitedb), "")
		//------------------------------------------------------------
		rc = sqliteClearBindings(&sqlitedb, stmt_handle)
		ut.compareInteger("sqliteClearBindings: rc", rc, SQLITE_OK)
		ut.compareCString("sqliteClearBindings: errmsg", errorMessage(&sqlitedb), "")
		//------------------------------------------------------------
		if rc == SQLITE_OK {
			//------------------------------------------------------------
			rc = sqliteBindUInt64(&sqlitedb, stmt_handle, 1, 2)
			ut.compareInteger("sqliteBindUInt64: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindUInt64: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
			rc = sqliteBindInt64(&sqlitedb, stmt_handle, 2, 2)
			ut.compareInteger("sqliteBindInt64: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindInt64: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
			rc = sqliteBindDouble(&sqlitedb, stmt_handle, 3, 2.2)
			ut.compareInteger("sqliteBindDouble: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindDouble: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
			text := "text2"
			rc = sqliteBindText(&sqlitedb, stmt_handle, 4, raw_data(text), i32Len(text), nil)
			ut.compareInteger("sqliteBindText: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindText: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
			blob := "blob2"
			rc = sqliteBindBlob(&sqlitedb, stmt_handle, 5, raw_data(blob), i32Len(blob), nil)
			ut.compareInteger("sqliteBindBlob: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindBlob: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
		rc = sqliteStep(&sqlitedb, stmt_handle)
		ut.compareInteger("sqliteStep: rc", rc, SQLITE_DONE)
		ut.compareCString("sqliteStep: errmsg", errorMessage(&sqlitedb), "no more rows available")
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	// sqlitePrepare / sqliteClearBindings / sqliteBind* / sqliteStep / sqliteFinalize
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		stmt_handle: ^rawptr
		//------------------------------------------------------------
		sql := cstring(
			"INSERT INTO test (uint64, integer, float, text, blob) VALUES(?, ?, ?, ?, ?);",
		)
		//------------------------------------------------------------
		rc := sqlitePrepare(&sqlitedb, sql, &stmt_handle)
		//------------------------------------------------------------
		defer sqliteFinalize(&sqlitedb, stmt_handle)
		//------------------------------------------------------------
		ut.compareInteger("sqlitePrepare: rc", rc, SQLITE_OK)
		ut.compareCString("sqlitePrepare: errmsg", errorMessage(&sqlitedb), "")
		//------------------------------------------------------------
		rc = sqliteClearBindings(&sqlitedb, stmt_handle)
		ut.compareInteger("sqliteClearBindings: rc", rc, SQLITE_OK)
		ut.compareCString("sqliteClearBindings: errmsg", errorMessage(&sqlitedb), "")
		//------------------------------------------------------------
		if rc == SQLITE_OK {
			//------------------------------------------------------------
			rc = sqliteBindUInt64(&sqlitedb, stmt_handle, 1, 3)
			ut.compareInteger("sqliteBindUInt64: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindUInt64: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
			rc = sqliteBindInt64(&sqlitedb, stmt_handle, 2, 3)
			ut.compareInteger("sqliteBindInt64: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindInt64: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
			rc = sqliteBindDouble(&sqlitedb, stmt_handle, 3, 3.3)
			ut.compareInteger("sqliteBindDouble: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindDouble: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
			text := "text3"
			rc = sqliteBindText(&sqlitedb, stmt_handle, 4, raw_data(text), i32Len(text), nil)
			ut.compareInteger("sqliteBindText: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindText: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
			rc = sqliteBindNull(&sqlitedb, stmt_handle, 5)
			ut.compareInteger("sqliteBindBlob: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindBlob: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
		rc = sqliteStep(&sqlitedb, stmt_handle)
		ut.compareInteger("sqliteStep: rc", rc, SQLITE_DONE)
		ut.compareCString("sqliteStep: errmsg", errorMessage(&sqlitedb), "no more rows available")
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	// sqlitePrepare / sqliteColumn* / sqliteStep / sqliteFinalize
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		stmt_handle: ^rawptr
		//------------------------------------------------------------
		sql := cstring("SELECT * FROM test;")
		//------------------------------------------------------------
		rc := sqlitePrepare(&sqlitedb, sql, &stmt_handle)
		//------------------------------------------------------------
		ut.compareInteger("sqlitePrepare: rc", rc, SQLITE_OK)
		ut.compareCString("sqlitePrepare: errmsg", errorMessage(&sqlitedb), "")
		//------------------------------------------------------------
		// sqliteColumnName
		//------------------------------------------------------------
		column_id_ptr := sqliteColumnName(&sqlitedb, stmt_handle, 0)
		column_uint64_ptr := sqliteColumnName(&sqlitedb, stmt_handle, 1)
		column_integer_ptr := sqliteColumnName(&sqlitedb, stmt_handle, 2)
		column_float_ptr := sqliteColumnName(&sqlitedb, stmt_handle, 3)
		column_text_ptr := sqliteColumnName(&sqlitedb, stmt_handle, 4)
		column_blob_ptr := sqliteColumnName(&sqlitedb, stmt_handle, 5)
		//------------------------------------------------------------
		column_id := cstring(column_id_ptr)
		column_uint64 := cstring(column_uint64_ptr)
		column_integer := cstring(column_integer_ptr)
		column_float := cstring(column_float_ptr)
		column_text := cstring(column_text_ptr)
		column_blob := cstring(column_blob_ptr)
		//------------------------------------------------------------
		ut.compareCString("sqliteColumnName: id", column_id, "id")
		ut.compareCString("sqliteColumnName: uint64", column_uint64, "uint64")
		ut.compareCString("sqliteColumnName: integer", column_integer, "integer")
		ut.compareCString("sqliteColumnName: float", column_float, "float")
		ut.compareCString("sqliteColumnName: text", column_text, "text")
		ut.compareCString("sqliteColumnName: blob", column_blob, "blob")
		//------------------------------------------------------------
		if rc == SQLITE_OK {
			//------------------------------------------------------------
			// sqliteStep
			//------------------------------------------------------------
			step_rc := sqliteStep(&sqlitedb, stmt_handle)
			//------------------------------------------------------------
			ut.compareInteger("sqliteStep", step_rc, SQLITE_ROW)
			//------------------------------------------------------------
			if step_rc == SQLITE_ROW {
				//------------------------------------------------------------
				// returnCode / errorMessage
				ut.compareInteger("sqliteStep", returnCode(&sqlitedb), SQLITE_ROW)
				ut.compareCString("sqliteStep", errorMessage(&sqlitedb), "another row available")
				//------------------------------------------------------------
				// sqliteColumnType
				col0 := sqliteColumnType(&sqlitedb, stmt_handle, 0)
				col1 := sqliteColumnType(&sqlitedb, stmt_handle, 1)
				col2 := sqliteColumnType(&sqlitedb, stmt_handle, 2)
				col3 := sqliteColumnType(&sqlitedb, stmt_handle, 3)
				col4 := sqliteColumnType(&sqlitedb, stmt_handle, 4)
				col5 := sqliteColumnType(&sqlitedb, stmt_handle, 5)
				ut.compareInteger("sqliteColumnType", col0, SQLITE_INTEGER)
				ut.compareInteger("sqliteColumnType", col1, SQLITE_INTEGER)
				ut.compareInteger("sqliteColumnType", col2, SQLITE_INTEGER)
				ut.compareInteger("sqliteColumnType", col3, SQLITE_FLOAT)
				ut.compareInteger("sqliteColumnType", col4, SQLITE_TEXT)
				ut.compareInteger("sqliteColumnType", col5, SQLITE_BLOB)
				//------------------------------------------------------------
				// sqliteColumnBytes (length)
				text_len := sqliteColumnBytes(&sqlitedb, stmt_handle, 4)
				ut.compareInteger("sqliteColumnBytes", text_len, 5)
				blob_len := sqliteColumnBytes(&sqlitedb, stmt_handle, 5)
				ut.compareInteger("sqliteColumnBytes", blob_len, 5)
				//------------------------------------------------------------
				id := sqliteColumnInt64(&sqlitedb, stmt_handle, 0)
				uint64 := sqliteColumnUInt64(&sqlitedb, stmt_handle, 1)
				integer := sqliteColumnInt64(&sqlitedb, stmt_handle, 2)
				float := sqliteColumnDouble(&sqlitedb, stmt_handle, 3)
				text_ptr := sqliteColumnText(&sqlitedb, stmt_handle, 4)
				text_string := sqliteTextString(&sqlitedb, stmt_handle, 4)
				text_cstring := sqliteTextCString(&sqlitedb, stmt_handle, 4)
				blob_ptr := sqliteColumnBlob(&sqlitedb, stmt_handle, 5)
				blob_string := sqliteBlobString(&sqlitedb, stmt_handle, 5)
				blob_cstring := sqliteBlobCString(&sqlitedb, stmt_handle, 5)
				//------------------------------------------------------------
				// sqliteColumn*
				ut.compareTypeID("sqliteColumnInt64", type_of(id), i64)
				ut.compareTypeID("sqliteColumnUInt64", type_of(uint64), u64)
				ut.compareTypeID("sqliteColumnInt64", type_of(integer), i64)
				ut.compareTypeID("sqliteColumnDouble", type_of(float), f64)
				ut.compareTypeID("sqliteColumnText", type_of(text_ptr), rawptr)
				ut.compareTypeID("sqliteTextString", type_of(text_string), string)
				ut.compareTypeID("sqliteTextCString", type_of(text_cstring), cstring)
				ut.compareTypeID("sqliteColumnBlob", type_of(blob_ptr), rawptr)
				ut.compareTypeID("sqliteBlobString", type_of(blob_string), string)
				ut.compareTypeID("sqliteBlobCString", type_of(blob_cstring), cstring)
				//------------------------------------------------------------
				// sqliteColumn*
				ut.compareInteger("sqliteColumnInt64", id, 1)
				ut.compareInteger("sqliteColumnUInt64", uint64, 1)
				ut.compareInteger("sqliteColumnInt64", integer, 1)
				ut.compareFloat("sqliteColumnDouble", float, 1.1)
				ut.compareBytes(
					"sqliteColumnText",
					rawptrToBytes(text_ptr, text_len),
					[]byte{'t', 'e', 'x', 't', '1'},
				)
				ut.compareString("sqliteTextString", text_string, "text1")
				ut.compareCString("sqliteTextCString", text_cstring, "text1")
				ut.compareBytes(
					"sqliteColumnBlob",
					rawptrToBytes(blob_ptr, blob_len),
					[]byte{'b', 'l', 'o', 'b', '1'},
				)
				ut.compareString("sqliteBlobString", blob_string, "blob1")
				ut.compareCString("sqliteBlobCString", blob_cstring, "blob1")
				//------------------------------------------------------------
				// sqliteColumnCount
				column_count := sqliteColumnCount(&sqlitedb, stmt_handle)
				ut.compareInteger("sqliteColumnCount", column_count, 6)
				//------------------------------------------------------------
				// sqliteDataCount
				data_count := sqliteDataCount(&sqlitedb, stmt_handle)
				ut.compareInteger("sqliteDataCount", data_count, 6)
				//------------------------------------------------------------
			}
			//------------------------------------------------------------
			// sqliteStep
			//------------------------------------------------------------
			step_rc = sqliteStep(&sqlitedb, stmt_handle)
			//------------------------------------------------------------
			ut.compareInteger("sqliteStep", step_rc, SQLITE_ROW)
			//------------------------------------------------------------
			if step_rc == SQLITE_ROW {
				//------------------------------------------------------------
				// returnCode / errorMessage
				ut.compareInteger("sqliteStep", returnCode(&sqlitedb), SQLITE_ROW)
				ut.compareCString("sqliteStep", errorMessage(&sqlitedb), "another row available")
				//------------------------------------------------------------
				// sqliteColumnType
				col0 := sqliteColumnType(&sqlitedb, stmt_handle, 0)
				col1 := sqliteColumnType(&sqlitedb, stmt_handle, 1)
				col2 := sqliteColumnType(&sqlitedb, stmt_handle, 2)
				col3 := sqliteColumnType(&sqlitedb, stmt_handle, 3)
				col4 := sqliteColumnType(&sqlitedb, stmt_handle, 4)
				col5 := sqliteColumnType(&sqlitedb, stmt_handle, 5)
				ut.compareInteger("sqliteColumnType", col0, SQLITE_INTEGER)
				ut.compareInteger("sqliteColumnType", col1, SQLITE_INTEGER)
				ut.compareInteger("sqliteColumnType", col2, SQLITE_INTEGER)
				ut.compareInteger("sqliteColumnType", col3, SQLITE_FLOAT)
				ut.compareInteger("sqliteColumnType", col4, SQLITE_TEXT)
				ut.compareInteger("sqliteColumnType", col5, SQLITE_BLOB)
				//------------------------------------------------------------
				// sqliteColumnBytes (length)
				text_len := sqliteColumnBytes(&sqlitedb, stmt_handle, 4)
				ut.compareInteger("sqliteColumnBytes", text_len, 5)
				blob_len := sqliteColumnBytes(&sqlitedb, stmt_handle, 5)
				ut.compareInteger("sqliteColumnBytes", blob_len, 5)
				//------------------------------------------------------------
				id := sqliteColumnInt64(&sqlitedb, stmt_handle, 0)
				uint64 := sqliteColumnUInt64(&sqlitedb, stmt_handle, 1)
				integer := sqliteColumnInt64(&sqlitedb, stmt_handle, 2)
				float := sqliteColumnDouble(&sqlitedb, stmt_handle, 3)
				text_ptr := sqliteColumnText(&sqlitedb, stmt_handle, 4)
				text_string := sqliteTextString(&sqlitedb, stmt_handle, 4)
				text_cstring := sqliteTextCString(&sqlitedb, stmt_handle, 4)
				blob_ptr := sqliteColumnBlob(&sqlitedb, stmt_handle, 5)
				blob_string := sqliteBlobString(&sqlitedb, stmt_handle, 5)
				blob_cstring := sqliteBlobCString(&sqlitedb, stmt_handle, 5)
				//------------------------------------------------------------
				// sqliteColumn*
				ut.compareTypeID("sqliteColumnInt64", type_of(id), i64)
				ut.compareTypeID("sqliteColumnUInt64", type_of(uint64), u64)
				ut.compareTypeID("sqliteColumnInt64", type_of(integer), i64)
				ut.compareTypeID("sqliteColumnDouble", type_of(float), f64)
				ut.compareTypeID("sqliteColumnText", type_of(text_ptr), rawptr)
				ut.compareTypeID("sqliteTextString", type_of(text_string), string)
				ut.compareTypeID("sqliteTextCString", type_of(text_cstring), cstring)
				ut.compareTypeID("sqliteColumnBlob", type_of(blob_ptr), rawptr)
				ut.compareTypeID("sqliteBlobString", type_of(blob_string), string)
				ut.compareTypeID("sqliteBlobCString", type_of(blob_cstring), cstring)
				//------------------------------------------------------------
				// sqliteColumn*
				ut.compareInteger("sqliteColumnInt64", id, 2) // todo uint64 ? + others
				ut.compareInteger("sqliteColumnUInt64", uint64, 2)
				ut.compareInteger("sqliteColumnInt64", integer, 2)
				ut.compareFloat("sqliteColumnDouble", float, 2.2)
				ut.compareBytes(
					"sqliteColumnText",
					rawptrToBytes(text_ptr, text_len),
					[]byte{'t', 'e', 'x', 't', '2'},
				)
				ut.compareString("sqliteTextString", text_string, "text2")
				ut.compareCString("sqliteTextCString", text_cstring, "text2")
				ut.compareBytes(
					"sqliteColumnBlob",
					rawptrToBytes(blob_ptr, blob_len),
					[]byte{'b', 'l', 'o', 'b', '2'},
				)
				ut.compareString("sqliteBlobString", blob_string, "blob2")
				ut.compareCString("sqliteBlobCString", blob_cstring, "blob2")
				//------------------------------------------------------------
			}
			//------------------------------------------------------------
			// sqliteStep
			//------------------------------------------------------------
			step_rc = sqliteStep(&sqlitedb, stmt_handle)
			//------------------------------------------------------------
			ut.compareInteger("sqliteStep", step_rc, SQLITE_ROW)
			//------------------------------------------------------------
			if step_rc == SQLITE_ROW {
				//------------------------------------------------------------
				// returnCode / errorMessage
				ut.compareInteger("sqliteStep", returnCode(&sqlitedb), SQLITE_ROW)
				ut.compareCString("sqliteStep", errorMessage(&sqlitedb), "another row available")
				//------------------------------------------------------------
				// sqliteColumnType
				col0 := sqliteColumnType(&sqlitedb, stmt_handle, 0)
				col1 := sqliteColumnType(&sqlitedb, stmt_handle, 1)
				col2 := sqliteColumnType(&sqlitedb, stmt_handle, 2)
				col3 := sqliteColumnType(&sqlitedb, stmt_handle, 3)
				col4 := sqliteColumnType(&sqlitedb, stmt_handle, 4)
				col5 := sqliteColumnType(&sqlitedb, stmt_handle, 5)
				ut.compareInteger("sqliteColumnType", col0, SQLITE_INTEGER)
				ut.compareInteger("sqliteColumnType", col1, SQLITE_INTEGER)
				ut.compareInteger("sqliteColumnType", col2, SQLITE_INTEGER)
				ut.compareInteger("sqliteColumnType", col3, SQLITE_FLOAT)
				ut.compareInteger("sqliteColumnType", col4, SQLITE_TEXT)
				ut.compareInteger("sqliteColumnType", col5, SQLITE_NULL)
				//------------------------------------------------------------
				// sqliteColumnBytes (length)
				text_len := sqliteColumnBytes(&sqlitedb, stmt_handle, 4)
				ut.compareInteger("sqliteColumnBytes", text_len, 5)
				blob_len := sqliteColumnBytes(&sqlitedb, stmt_handle, 5)
				ut.compareInteger("sqliteColumnBytes", blob_len, 0)
				//------------------------------------------------------------
				id := sqliteColumnInt64(&sqlitedb, stmt_handle, 0)
				uint64 := sqliteColumnUInt64(&sqlitedb, stmt_handle, 1)
				integer := sqliteColumnInt64(&sqlitedb, stmt_handle, 2)
				float := sqliteColumnDouble(&sqlitedb, stmt_handle, 3)
				text_ptr := sqliteColumnText(&sqlitedb, stmt_handle, 4)
				text_string := sqliteTextString(&sqlitedb, stmt_handle, 4)
				text_cstring := sqliteTextCString(&sqlitedb, stmt_handle, 4)
				blob_ptr := sqliteColumnBlob(&sqlitedb, stmt_handle, 5)
				blob_string := sqliteBlobString(&sqlitedb, stmt_handle, 5)
				blob_cstring := sqliteBlobCString(&sqlitedb, stmt_handle, 5)
				//------------------------------------------------------------
				// sqliteColumn*
				ut.compareTypeID("sqliteColumnInt64", type_of(id), i64)
				ut.compareTypeID("sqliteColumnUInt64", type_of(uint64), u64)
				ut.compareTypeID("sqliteColumnInt64", type_of(integer), i64)
				ut.compareTypeID("sqliteColumnDouble", type_of(float), f64)
				ut.compareTypeID("sqliteColumnText", type_of(text_ptr), rawptr)
				ut.compareTypeID("sqliteTextString", type_of(text_string), string)
				ut.compareTypeID("sqliteTextCString", type_of(text_cstring), cstring)
				ut.compareTypeID("sqliteColumnBlob", type_of(blob_ptr), rawptr)
				ut.compareTypeID("sqliteBlobString", type_of(blob_string), string)
				ut.compareTypeID("sqliteBlobCString", type_of(blob_cstring), cstring)
				//------------------------------------------------------------
				// sqliteColumn*
				ut.compareInteger("sqliteColumnInt64", id, 3)
				ut.compareInteger("sqliteColumnUInt64", uint64, 3)
				ut.compareInteger("sqliteColumnInt64", integer, 3)
				ut.compareFloat("sqliteColumnDouble", float, 3.3)
				ut.compareBytes(
					"sqliteColumnText",
					rawptrToBytes(text_ptr, text_len),
					[]byte{'t', 'e', 'x', 't', '3'},
				)
				ut.compareString("sqliteTextString", text_string, "text3")
				ut.compareCString("sqliteTextCString", text_cstring, "text3")
				ut.compareNull("sqliteColumnBlob", blob_ptr)
				ut.compareString("sqliteBlobString", blob_string, "")
				ut.compareCString("sqliteBlobCString", blob_cstring, "")
				//------------------------------------------------------------
			}
			//------------------------------------------------------------
			// sqliteStep
			//------------------------------------------------------------
			step_rc = sqliteStep(&sqlitedb, stmt_handle)
			ut.compareInteger("sqliteStep: rc", step_rc, SQLITE_DONE)
			if step_rc == SQLITE_DONE {
				//------------------------------------------------------------
				// returnCode / errorMessage
				ut.compareInteger("sqliteStep: rc", returnCode(&sqlitedb), SQLITE_DONE)
				ut.compareCString(
					"sqliteStep: errmsg",
					errorMessage(&sqlitedb),
					"no more rows available",
				)
				//------------------------------------------------------------
			}
			//------------------------------------------------------------
			// sqliteReset
			//------------------------------------------------------------
			reset_rc := sqliteReset(&sqlitedb, stmt_handle)
			ut.compareInteger("sqliteReset: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteReset: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
			// sqliteStep
			//------------------------------------------------------------
			step_rc = sqliteStep(&sqlitedb, stmt_handle)
			ut.compareInteger("sqliteStep: rc", step_rc, SQLITE_ROW)
			ut.compareInteger("sqliteStep: returnCode", returnCode(&sqlitedb), SQLITE_ROW)
			ut.compareCString(
				"querySQLiteColumns",
				errorMessage(&sqlitedb),
				"another row available",
			)
			//------------------------------------------------------------
			// sqliteStep
			//------------------------------------------------------------
			step_rc = sqliteStep(&sqlitedb, stmt_handle)
			ut.compareInteger("sqliteStep: rc", step_rc, SQLITE_ROW)
			ut.compareInteger("sqliteStep: returnCode", returnCode(&sqlitedb), SQLITE_ROW)
			ut.compareCString(
				"querySQLiteColumns",
				errorMessage(&sqlitedb),
				"another row available",
			)
			//------------------------------------------------------------
			// sqliteStep
			//------------------------------------------------------------
			step_rc = sqliteStep(&sqlitedb, stmt_handle)
			ut.compareInteger("sqliteStep: rc", step_rc, SQLITE_ROW)
			ut.compareInteger("sqliteStep: returnCode", returnCode(&sqlitedb), SQLITE_ROW)
			ut.compareCString(
				"querySQLiteColumns",
				errorMessage(&sqlitedb),
				"another row available",
			)
			//------------------------------------------------------------
			// sqliteStep
			//------------------------------------------------------------
			step_rc = sqliteStep(&sqlitedb, stmt_handle)
			ut.compareInteger("sqliteStep: rc", step_rc, SQLITE_DONE)
			ut.compareInteger("sqliteStep: returnCode", returnCode(&sqlitedb), SQLITE_DONE)
			ut.compareCString(
				"querySQLiteColumns",
				errorMessage(&sqlitedb),
				"no more rows available",
			)
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
		sqliteFinalize(&sqlitedb, stmt_handle)
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	// populate [6]SQLiteColumn
	//--------------------------------------------------------------------------------
	text := "text1"
	blob := "blob1"
	sqlite_columns := [6]SQLiteColumn {
		{index = 0, name = "id", column_type = .SQLITE_INTEGER, integer = 1},
		{index = 1, name = "uint64", column_type = .SQLITE_INTEGER, uint64 = 1},
		{index = 2, name = "integer", column_type = .SQLITE_INTEGER, integer = 1},
		{index = 3, name = "float", column_type = .SQLITE_FLOAT, float = 1.1},
		{
			index = 4,
			name = "text",
			column_type = .SQLITE_TEXT,
			ptr = raw_data(text),
			len = len(text),
		},
		{
			index = 5,
			name = "blob",
			column_type = .SQLITE_BLOB,
			ptr = raw_data(blob),
			len = len(blob),
		},
	}
	//--------------------------------------------------------------------------------
	// updateRow
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		fixed_row := FixedRow{}
		//------------------------------------------------------------
		err := updateRow(&fixed_row, sqlite_columns[:], context.allocator)
		//------------------------------------------------------------
		ut.compareError("updateRow", err, nil)
		//------------------------------------------------------------
		ut.compareInteger("updateRow", fixed_row.id, 1)
		ut.compareInteger("updateRow", fixed_row.uint64, 1)
		ut.compareInteger("updateRow", fixed_row.integer, 1)
		ut.compareFloat("updateRow", fixed_row.float, 1.1)
		ut.compareString("updateRow", fixed_row.text, "text1")
		ut.compareBytes("updateRow", fixed_row.blob, []byte{'b', 'l', 'o', 'b', '1'})
		//------------------------------------------------------------
		if err == nil {
			delete(fixed_row.blob, context.allocator)
			delete(fixed_row.text, context.allocator)
		}
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	// updateRowMap
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		fixed_row_map := make(map[string]SQLiteColumnValue, context.allocator)
		//------------------------------------------------------------
		err := updateRowMap(&fixed_row_map, sqlite_columns[:], context.allocator)
		//------------------------------------------------------------
		ut.compareError("updateRowMap", err, nil)
		//------------------------------------------------------------
		id, _ := fixed_row_map["id"].(i64)
		integer, _ := fixed_row_map["integer"].(i64)
		float, _ := fixed_row_map["float"].(f64)
		text, _ := fixed_row_map["text"].(string)
		blob, _ := fixed_row_map["blob"].([]u8)
		//------------------------------------------------------------
		ut.compareInteger("updateRowMap", id, 1)
		ut.compareInteger("updateRowMap", integer, 1)
		ut.compareFloat("updateRowMap", float, 1.1)
		ut.compareString("updateRowMap", text, "text1")
		ut.compareBytes("updateRowMap", blob, []byte{'b', 'l', 'o', 'b', '1'})
		//------------------------------------------------------------
		if err == nil {
			for _, value in fixed_row_map {
				#partial switch v in value {
				case string:
					delete(v, context.allocator)
				case []u8:
					delete(v, context.allocator)
				}
			}
			delete(fixed_row_map)
		}
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	// sqliteGetTable / sqliteFree / sqliteFreeTable
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		results: ^cstring
		row_count: i32
		column_count: i32
		errmsg: rawptr
		//------------------------------------------------------------
		rc := sqliteGetTable(
			&sqlitedb,
			"SELECT * FROM test;",
			&results,
			&row_count,
			&column_count,
			&errmsg,
		)
		//------------------------------------------------------------
		ut.compareInteger("sqliteGetTable: rc", rc, SQLITE_OK)
		ut.compareInteger("sqliteGetTable: row_count", row_count, 3)
		ut.compareInteger("sqliteGetTable: column_count", column_count, 6)
		ut.compareCString("sqliteGetTable: errmsg", cstring(errmsg), nil)
		//------------------------------------------------------------
		if results == nil {
			//------------------------------------------------------------
			defer sqliteFree(errmsg)
			//------------------------------------------------------------
		} else {
			//------------------------------------------------------------
			defer sqliteFreeTable(&sqlitedb, results)
			//------------------------------------------------------------
			results_table := cast([^]cstring)results
			//------------------------------------------------------------
			if row_count > 0 {
				ut.compareCString("sqliteGetTable", results_table[0], "id")
				ut.compareCString("sqliteGetTable", results_table[1], "uint64")
				ut.compareCString("sqliteGetTable", results_table[2], "integer")
				ut.compareCString("sqliteGetTable", results_table[3], "float")
				ut.compareCString("sqliteGetTable", results_table[4], "text")
				ut.compareCString("sqliteGetTable", results_table[5], "blob")
				ut.compareCString("sqliteGetTable", results_table[6], "1")
				ut.compareCString("sqliteGetTable", results_table[7], "1")
				ut.compareCString("sqliteGetTable", results_table[8], "1")
				ut.compareCString("sqliteGetTable", results_table[9], "1.1")
				ut.compareCString("sqliteGetTable", results_table[10], "text1")
				ut.compareCString("sqliteGetTable", results_table[11], "blob1")
			}
			if row_count > 1 {
				ut.compareCString("sqliteGetTable", results_table[12], "2")
				ut.compareCString("sqliteGetTable", results_table[13], "2")
				ut.compareCString("sqliteGetTable", results_table[14], "2")
				ut.compareCString("sqliteGetTable", results_table[15], "2.2")
				ut.compareCString("sqliteGetTable", results_table[16], "text2")
				ut.compareCString("sqliteGetTable", results_table[17], "blob2")
			}
			if row_count > 2 {
				ut.compareCString("sqliteGetTable", results_table[18], "3")
				ut.compareCString("sqliteGetTable", results_table[19], "3")
				ut.compareCString("sqliteGetTable", results_table[20], "3")
				ut.compareCString("sqliteGetTable", results_table[21], "3.3")
				ut.compareCString("sqliteGetTable", results_table[22], "text3")
				ut.compareCString("sqliteGetTable", results_table[23], nil)
			}
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	// getTableRowCount / getRowCount / getColumnCount
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		{
			row_count, err := getTableRowCount(&sqlitedb, "test")

			ut.compareInteger("getTableRowCount: row_count", row_count, 3)
			ut.compareError("getTableRowCount: err", err, nil)
			ut.compareInteger("getTableRowCount: returnCode", returnCode(&sqlitedb), SQLITE_OK)
			ut.compareCString("getTableRowCount", errorMessage(&sqlitedb), "")
		}
		//------------------------------------------------------------
		{
			row_count, err := getRowCount(&sqlitedb, "SELECT * FROM test;")

			ut.compareInteger("getRowCount: row_count", row_count, 3)
			ut.compareError("getRowCount: err", err, nil)
			ut.compareInteger("getRowCount: returnCode", returnCode(&sqlitedb), SQLITE_OK)
			ut.compareCString("getRowCount", errorMessage(&sqlitedb), "")
		}
		//------------------------------------------------------------
		{
			column_count, err := getColumnCount(&sqlitedb, "SELECT * FROM test LIMIT 1;")

			ut.compareInteger("getColumnCount: column_count", column_count, 6)
			ut.compareError("getColumnCount: err", err, nil)
			ut.compareInteger("getColumnCount: returnCode", returnCode(&sqlitedb), SQLITE_OK)
			ut.compareCString("getColumnCount", errorMessage(&sqlitedb), "")
		}
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	// SQLiteColumnsTable / freeSQLiteColumnsTable
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		table, err := getSQLiteColumnsTable(&sqlitedb, "SELECT * FROM test;")
		defer freeSQLiteColumnsTable(&sqlitedb, table)
		//------------------------------------------------------------
		if err != nil {
			//------------------------------------------------------------
			ut.compareError("getSQLiteColumnsTable", err, nil)
			//------------------------------------------------------------
		} else {
			//------------------------------------------------------------
			total_columns := len(table.sqlite_columns)
			ut.compareInteger("getSQLiteColumnsTable: total_columns", total_columns, 18)
			ut.compareInteger("getSQLiteColumnsTable: row_count", table.row_count, 3)
			ut.compareInteger("getSQLiteColumnsTable: column_count", table.column_count, 6)
			//------------------------------------------------------------
			if table.row_count > 0 && total_columns > 0 {
				//------------------------------------------------------------
				column := table.sqlite_columns[0]
				ut.compareCString("getSQLiteColumnsTable: name", column.name, "id")
				ut.compareEnum(
					"getSQLiteColumnsTable: column_type",
					column.column_type,
					SQLiteColumnType.SQLITE_INTEGER,
				)
				ut.compareInteger("getSQLiteColumnsTable: uint64", column.uint64, 1)
				ut.compareInteger("getSQLiteColumnsTable: integer", column.integer, 1)
				//------------------------------------------------------------
				column = table.sqlite_columns[1]
				ut.compareCString("getSQLiteColumnsTable: name", column.name, "uint64")
				ut.compareEnum(
					"getSQLiteColumnsTable: column_type",
					column.column_type,
					SQLiteColumnType.SQLITE_INTEGER,
				)
				ut.compareInteger("getSQLiteColumnsTable: integer", column.integer, 1)
				//------------------------------------------------------------
				column = table.sqlite_columns[2]
				ut.compareCString("getSQLiteColumnsTable: name", column.name, "integer")
				ut.compareEnum(
					"getSQLiteColumnsTable: column_type",
					column.column_type,
					SQLiteColumnType.SQLITE_INTEGER,
				)
				ut.compareInteger("getSQLiteColumnsTable: integer", column.integer, 1)
				//------------------------------------------------------------
				column = table.sqlite_columns[3]
				ut.compareCString("getSQLiteColumnsTable: name", column.name, "float")
				ut.compareEnum(
					"getSQLiteColumnsTable: column_type",
					column.column_type,
					SQLiteColumnType.SQLITE_FLOAT,
				)
				ut.compareFloat("getSQLiteColumnsTable: float", column.float, 1.1)
				//------------------------------------------------------------
				column = table.sqlite_columns[4]
				ut.compareCString("getSQLiteColumnsTable: name", column.name, "text")
				ut.compareEnum(
					"getSQLiteColumnsTable: column_type",
					column.column_type,
					SQLiteColumnType.SQLITE_TEXT,
				)
				ut.compareTypeID("getSQLiteColumnsTable: ptr", type_of(column.ptr), [^]u8)
				ut.compareString(
					"getSQLiteColumnsTable: ptr",
					string(column.ptr[0:column.len]),
					string("text1"),
				)
				ut.compareInteger("getSQLiteColumnsTable: len", column.len, 5)
				//------------------------------------------------------------
				column = table.sqlite_columns[5]
				ut.compareCString("getSQLiteColumnsTable: name", column.name, "blob")
				ut.compareEnum(
					"getSQLiteColumnsTable: column_type",
					column.column_type,
					SQLiteColumnType.SQLITE_BLOB,
				)
				ut.compareTypeID("getSQLiteColumnsTable: ptr", type_of(column.ptr), [^]u8)
				ut.compareString(
					"getSQLiteColumnsTable: ptr",
					string(column.ptr[0:column.len]),
					string("blob1"),
				)
				ut.compareInteger("getSQLiteColumnsTable: len", column.len, 5)
				//------------------------------------------------------------
			}
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	// querySQLiteColumns
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		err := querySQLiteColumns(
			&sqlitedb,
			"SELECT * FROM test;",
			queryCallback,
			cast(rawptr)&ctx,
		)
		ut.compareError("querySQLiteColumns", err, nil)
		ut.compareInteger("querySQLiteColumns", returnCode(&sqlitedb), SQLITE_OK)
		ut.compareCString("querySQLiteColumns", errorMessage(&sqlitedb), "")

		ut.compareInteger("querySQLiteColumns", len(ctx.fixed_rows), 3)

		if len(ctx.fixed_rows) > 0 {
			ut.compareInteger("querySQLiteColumns: id", ctx.fixed_rows[0].id, 1)
			ut.compareInteger("querySQLiteColumns: uint64", ctx.fixed_rows[0].uint64, 1)
			ut.compareInteger("querySQLiteColumns: integer", ctx.fixed_rows[0].integer, 1)
			ut.compareFloat("querySQLiteColumns: float", ctx.fixed_rows[0].float, 1.1)
			ut.compareString("querySQLiteColumns: text", ctx.fixed_rows[0].text, "text1")
			ut.compareBytes(
				"querySQLiteColumns: blob",
				ctx.fixed_rows[0].blob,
				[]byte{'b', 'l', 'o', 'b', '1'},
			)
		}

		if len(ctx.fixed_rows) > 1 {
			ut.compareInteger("querySQLiteColumns: id", ctx.fixed_rows[1].id, 2)
			ut.compareInteger("querySQLiteColumns: uint64", ctx.fixed_rows[1].uint64, 2)
			ut.compareInteger("querySQLiteColumns: integer", ctx.fixed_rows[1].integer, 2)
			ut.compareFloat("querySQLiteColumns: float", ctx.fixed_rows[1].float, 2.2)
			ut.compareBytes(
				"querySQLiteColumns: blob",
				ctx.fixed_rows[1].blob,
				[]byte{'b', 'l', 'o', 'b', '2'},
			)
			ut.compareString("querySQLiteColumns: text", ctx.fixed_rows[1].text, "text2")
		}

		if len(ctx.fixed_rows) > 2 {
			ut.compareInteger("querySQLiteColumns: id", ctx.fixed_rows[2].id, 3)
			ut.compareInteger("querySQLiteColumns: uint64", ctx.fixed_rows[2].uint64, 3)
			ut.compareInteger("querySQLiteColumns: integer", ctx.fixed_rows[2].integer, 3)
			ut.compareFloat("querySQLiteColumns: float", ctx.fixed_rows[2].float, 3.3)
			ut.compareBytes("querySQLiteColumns: blob", ctx.fixed_rows[2].blob, []byte{})
			ut.compareString("querySQLiteColumns: text", ctx.fixed_rows[2].text, "text3")
		}
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	ut.printSummary()
	//--------------------------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
execCallback :: proc "c" (
	ctx_ptr: rawptr,
	argc: i32,
	argv: [^]cstring,
	azColName: [^]cstring,
) -> i32 {
	//------------------------------------------------------------
	ctx := cast(^CallbackContext)ctx_ptr
	//------------------------------------------------------------
	context = runtime.Context {
		allocator = ctx.allocator,
	}
	//------------------------------------------------------------
	string_column := StringColumn{}
	//------------------------------------------------------------
	for index in 0 ..< int(argc) {
		//----------------------------------------
		string_column.key = strings.clone(string(azColName[index]))
		//----------------------------------------
		if argv[index] == nil {
			string_column.value = strings.clone("NULL")
		} else {
			string_column.value = strings.clone(string(argv[index]))
		}
		//----------------------------------------
		append(&ctx.string_columns, string_column)
		//----------------------------------------
	}
	//------------------------------------------------------------
	return SQLITE_OK
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
queryCallback :: proc "c" (
	ctx_ptr: rawptr,
	columns_ptr: [^]SQLiteColumn,
	column_count: i32,
) -> i32 {
	//------------------------------------------------------------
	ctx := cast(^CallbackContext)ctx_ptr
	//------------------------------------------------------------
	context = runtime.Context {
		allocator = ctx.allocator,
	}
	//------------------------------------------------------------
	fixed_row := FixedRow{}
	//------------------------------------------------------------
	for column in columns_ptr[:column_count] {
		//----------------------------------------
		switch column.name {
		case "id":
			fixed_row.id = column.integer
		case "uint64":
			fixed_row.uint64 = column.uint64
		case "integer":
			fixed_row.integer = column.integer
		case "float":
			fixed_row.float = column.float
		case "text":
			fixed_row.text = strings.clone(string(column.ptr[:column.len]))
		case "blob":
			if column.column_type != .SQLITE_NULL {
				fixed_row.blob, _ = make([]u8, column.len, context.allocator)
				copy(fixed_row.blob[:], column.ptr[:column.len])
			}
		case:
		}
		//----------------------------------------
	}
	//------------------------------------------------------------
	append(&ctx.fixed_rows, fixed_row)
	//------------------------------------------------------------
	return SQLITE_OK
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
