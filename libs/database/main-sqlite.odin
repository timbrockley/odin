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
	blob:    []u8,
	text:    string,
	integer: i64,
	float:   f64,
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
	ut.init({show_passes = false})
	//------------------------------------------------------------
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	//------------------------------------------------------------
	defer {
		if len(track.allocation_map) > 0 {
			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)}
		}
		if len(track.bad_free_array) > 0 {
			fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
			for entry in track.bad_free_array {fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)}
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
			CREATE TABLE IF NOT EXISTS test (id INTEGER PRIMARY KEY AUTOINCREMENT, blob BLOB, text VARCHAR(255) DEFAULT '' NOT NULL, integer INTEGER DEFAULT 0 NOT NULL, float REAL DEFAULT 0 NOT NULL);
	 		INSERT INTO test (blob, text, integer, float) VALUES(X'626C6F6231', 'text1', 1, 1.1);
		 	SELECT * FROM test;`
		//------------------------------------------------------------
		errmsg: rawptr = nil
		rc := sqliteExec(&sqlitedb, sql, callback, cast(rawptr)&ctx, &errmsg)
		if rc != SQLITE_OK {defer sqliteFree(errmsg)}
		//------------------------------------------------------------
		ut.compareInteger("sqliteExec: rc", rc, SQLITE_OK)
		ut.compareCString("sqliteExec: errmsg", cstring(errmsg), nil)
		ut.compareInteger("sqliteExec: string_columns", len(ctx.string_columns), 6)
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
		sql := cstring("INSERT INTO test (blob, text, integer, float) VALUES(?, ?, ?, ?);")
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
			blob := "blob2"
			rc = sqliteBindBlob(&sqlitedb, stmt_handle, 1, raw_data(blob), i32Len(blob), nil)
			ut.compareInteger("sqliteBindBlob: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindBlob: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
			text := "text2"
			rc = sqliteBindText(&sqlitedb, stmt_handle, 2, raw_data(text), i32Len(text), nil)
			ut.compareInteger("sqliteBindText: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindText: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
			rc = sqliteBindInt64(&sqlitedb, stmt_handle, 3, 2)
			ut.compareInteger("sqliteBindInt64: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindInt64: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
			rc = sqliteBindDouble(&sqlitedb, stmt_handle, 4, 2.2)
			ut.compareInteger("sqliteBindDouble: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindDouble: errmsg", errorMessage(&sqlitedb), "")
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
		sql := cstring("INSERT INTO test (blob, text, integer, float) VALUES(?, ?, ?, ?);")
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
			rc = sqliteBindNull(&sqlitedb, stmt_handle, 1)
			ut.compareInteger("sqliteBindBlob: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindBlob: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
			text := "text3"
			rc = sqliteBindText(&sqlitedb, stmt_handle, 2, raw_data(text), i32Len(text), nil)
			ut.compareInteger("sqliteBindText: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindText: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
			rc = sqliteBindInt64(&sqlitedb, stmt_handle, 3, 3)
			ut.compareInteger("sqliteBindInt64: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindInt64: errmsg", errorMessage(&sqlitedb), "")
			//------------------------------------------------------------
			rc = sqliteBindDouble(&sqlitedb, stmt_handle, 4, 3.3)
			ut.compareInteger("sqliteBindDouble: rc", rc, SQLITE_OK)
			ut.compareCString("sqliteBindDouble: errmsg", errorMessage(&sqlitedb), "")
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
		column_blob_ptr := sqliteColumnName(&sqlitedb, stmt_handle, 1)
		column_text_ptr := sqliteColumnName(&sqlitedb, stmt_handle, 2)
		column_integer_ptr := sqliteColumnName(&sqlitedb, stmt_handle, 3)
		column_float_ptr := sqliteColumnName(&sqlitedb, stmt_handle, 4)
		//------------------------------------------------------------
		column_id := cstring(column_id_ptr)
		column_blob := cstring(column_blob_ptr)
		column_text := cstring(column_text_ptr)
		column_integer := cstring(column_integer_ptr)
		column_float := cstring(column_float_ptr)
		//------------------------------------------------------------
		ut.compareCString("sqliteColumnName: id", column_id, "id")
		ut.compareCString("sqliteColumnName: blob", column_blob, "blob")
		ut.compareCString("sqliteColumnName: text", column_text, "text")
		ut.compareCString("sqliteColumnName: integer", column_integer, "integer")
		ut.compareCString("sqliteColumnName: float", column_float, "float")
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
				ut.compareInteger("sqliteColumnType", col0, SQLITE_INTEGER)
				ut.compareInteger("sqliteColumnType", col1, SQLITE_BLOB)
				ut.compareInteger("sqliteColumnType", col2, SQLITE_TEXT)
				ut.compareInteger("sqliteColumnType", col3, SQLITE_INTEGER)
				ut.compareInteger("sqliteColumnType", col4, SQLITE_FLOAT)
				//------------------------------------------------------------
				// sqliteColumnBytes (length)
				blob_len := sqliteColumnBytes(&sqlitedb, stmt_handle, 1)
				ut.compareInteger("sqliteColumnBytes", blob_len, 5)
				text_len := sqliteColumnBytes(&sqlitedb, stmt_handle, 2)
				ut.compareInteger("sqliteColumnBytes", text_len, 5)
				//------------------------------------------------------------
				id := sqliteColumnInt64(&sqlitedb, stmt_handle, 0)
				blob_ptr := sqliteColumnBlob(&sqlitedb, stmt_handle, 1)
				blob_string := sqliteBlobString(&sqlitedb, stmt_handle, 1)
				blob_cstring := sqliteBlobCString(&sqlitedb, stmt_handle, 1)
				text_ptr := sqliteColumnText(&sqlitedb, stmt_handle, 2)
				text_string := sqliteTextString(&sqlitedb, stmt_handle, 2)
				text_cstring := sqliteTextCString(&sqlitedb, stmt_handle, 2)
				integer := sqliteColumnInt64(&sqlitedb, stmt_handle, 3)
				float := sqliteColumnDouble(&sqlitedb, stmt_handle, 4)
				//------------------------------------------------------------
				// sqliteColumn*
				ut.compareTypeID("sqliteColumnInt64", type_of(id), i64)
				ut.compareTypeID("sqliteColumnBlob", type_of(blob_ptr), rawptr)
				ut.compareTypeID("sqliteBlobString", type_of(blob_string), string)
				ut.compareTypeID("sqliteBlobCString", type_of(blob_cstring), cstring)
				ut.compareTypeID("sqliteColumnText", type_of(text_ptr), rawptr)
				ut.compareTypeID("sqliteTextString", type_of(text_string), string)
				ut.compareTypeID("sqliteTextCString", type_of(text_cstring), cstring)
				ut.compareTypeID("sqliteColumnInt64", type_of(integer), i64)
				ut.compareTypeID("sqliteColumnDouble", type_of(float), f64)
				//------------------------------------------------------------
				// sqliteColumn*
				ut.compareInteger("sqliteColumnInt64", id, 1)
				ut.compareBytes(
					"sqliteColumnBlob",
					rawptrToBytes(blob_ptr, blob_len),
					[]byte{'b', 'l', 'o', 'b', '1'},
				)
				ut.compareString("sqliteBlobString", blob_string, "blob1")
				ut.compareCString("sqliteBlobCString", blob_cstring, "blob1")
				ut.compareBytes(
					"sqliteColumnText",
					rawptrToBytes(text_ptr, text_len),
					[]byte{'t', 'e', 'x', 't', '1'},
				)
				ut.compareString("sqliteTextString", text_string, "text1")
				ut.compareCString("sqliteTextCString", text_cstring, "text1")
				ut.compareInteger("sqliteColumnInt64", integer, 1)
				ut.compareFloat("sqliteColumnDouble", float, 1.1)
				//------------------------------------------------------------
				// sqliteColumnCount
				column_count := sqliteColumnCount(&sqlitedb, stmt_handle)
				ut.compareInteger("sqliteColumnType", column_count, 5)
				//------------------------------------------------------------
				// sqliteDataCount
				data_count := sqliteDataCount(&sqlitedb, stmt_handle)
				ut.compareInteger("sqliteColumnType", data_count, 5)
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
				ut.compareInteger("sqliteColumnType", col0, SQLITE_INTEGER)
				ut.compareInteger("sqliteColumnType", col1, SQLITE_BLOB)
				ut.compareInteger("sqliteColumnType", col2, SQLITE_TEXT)
				ut.compareInteger("sqliteColumnType", col3, SQLITE_INTEGER)
				ut.compareInteger("sqliteColumnType", col4, SQLITE_FLOAT)
				//------------------------------------------------------------
				// sqliteColumnBytes (length)
				blob_len := sqliteColumnBytes(&sqlitedb, stmt_handle, 1)
				ut.compareInteger("sqliteColumnBytes", blob_len, 5)
				text_len := sqliteColumnBytes(&sqlitedb, stmt_handle, 2)
				ut.compareInteger("sqliteColumnBytes", text_len, 5)
				//------------------------------------------------------------
				id := sqliteColumnInt64(&sqlitedb, stmt_handle, 0)
				blob_ptr := sqliteColumnBlob(&sqlitedb, stmt_handle, 1)
				blob_string := sqliteBlobString(&sqlitedb, stmt_handle, 1)
				blob_cstring := sqliteBlobCString(&sqlitedb, stmt_handle, 1)
				text_ptr := sqliteColumnText(&sqlitedb, stmt_handle, 2)
				text_string := sqliteTextString(&sqlitedb, stmt_handle, 2)
				text_cstring := sqliteTextCString(&sqlitedb, stmt_handle, 2)
				integer := sqliteColumnInt64(&sqlitedb, stmt_handle, 3)
				float := sqliteColumnDouble(&sqlitedb, stmt_handle, 4)
				//------------------------------------------------------------
				// sqliteColumn*
				ut.compareTypeID("sqliteColumnInt64", type_of(id), i64)
				ut.compareTypeID("sqliteColumnBlob", type_of(blob_ptr), rawptr)
				ut.compareTypeID("sqliteBlobString", type_of(blob_string), string)
				ut.compareTypeID("sqliteBlobCString", type_of(blob_cstring), cstring)
				ut.compareTypeID("sqliteColumnText", type_of(text_ptr), rawptr)
				ut.compareTypeID("sqliteTextString", type_of(text_string), string)
				ut.compareTypeID("sqliteTextCString", type_of(text_cstring), cstring)
				ut.compareTypeID("sqliteColumnInt64", type_of(integer), i64)
				ut.compareTypeID("sqliteColumnDouble", type_of(float), f64)
				//------------------------------------------------------------
				// sqliteColumn*
				ut.compareInteger("sqliteColumnInt64", id, 2)
				ut.compareBytes(
					"sqliteColumnBlob",
					rawptrToBytes(blob_ptr, blob_len),
					[]byte{'b', 'l', 'o', 'b', '2'},
				)
				ut.compareString("sqliteBlobString", blob_string, "blob2")
				ut.compareCString("sqliteBlobCString", blob_cstring, "blob2")
				ut.compareBytes(
					"sqliteColumnText",
					rawptrToBytes(text_ptr, text_len),
					[]byte{'t', 'e', 'x', 't', '2'},
				)
				ut.compareString("sqliteTextString", text_string, "text2")
				ut.compareCString("sqliteTextCString", text_cstring, "text2")
				ut.compareInteger("sqliteColumnInt64", integer, 2)
				ut.compareFloat("sqliteColumnDouble", float, 2.2)
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
				ut.compareInteger("sqliteColumnType", col0, SQLITE_INTEGER)
				ut.compareInteger("sqliteColumnType", col1, SQLITE_NULL)
				ut.compareInteger("sqliteColumnType", col2, SQLITE_TEXT)
				ut.compareInteger("sqliteColumnType", col3, SQLITE_INTEGER)
				ut.compareInteger("sqliteColumnType", col4, SQLITE_FLOAT)
				//------------------------------------------------------------
				// sqliteColumnBytes (length)
				blob_len := sqliteColumnBytes(&sqlitedb, stmt_handle, 1)
				ut.compareInteger("sqliteColumnBytes", blob_len, 0)
				text_len := sqliteColumnBytes(&sqlitedb, stmt_handle, 2)
				ut.compareInteger("sqliteColumnBytes", text_len, 5)
				//------------------------------------------------------------
				id := sqliteColumnInt64(&sqlitedb, stmt_handle, 0)
				blob_ptr := sqliteColumnBlob(&sqlitedb, stmt_handle, 1)
				blob_string := sqliteBlobString(&sqlitedb, stmt_handle, 1)
				blob_cstring := sqliteBlobCString(&sqlitedb, stmt_handle, 1)
				text_ptr := sqliteColumnText(&sqlitedb, stmt_handle, 2)
				text_string := sqliteTextString(&sqlitedb, stmt_handle, 2)
				text_cstring := sqliteTextCString(&sqlitedb, stmt_handle, 2)
				integer := sqliteColumnInt64(&sqlitedb, stmt_handle, 3)
				float := sqliteColumnDouble(&sqlitedb, stmt_handle, 4)
				//------------------------------------------------------------
				// sqliteColumn*
				ut.compareTypeID("sqliteColumnInt64", type_of(id), i64)
				ut.compareTypeID("sqliteColumnBlob", type_of(blob_ptr), rawptr)
				ut.compareTypeID("sqliteBlobString", type_of(blob_string), string)
				ut.compareTypeID("sqliteBlobCString", type_of(blob_cstring), cstring)
				ut.compareTypeID("sqliteColumnText", type_of(text_ptr), rawptr)
				ut.compareTypeID("sqliteTextString", type_of(text_string), string)
				ut.compareTypeID("sqliteTextCString", type_of(text_cstring), cstring)
				ut.compareTypeID("sqliteColumnInt64", type_of(integer), i64)
				ut.compareTypeID("sqliteColumnDouble", type_of(float), f64)
				//------------------------------------------------------------
				// sqliteColumn*
				ut.compareInteger("sqliteColumnInt64", id, 3)
				ut.compareNull("sqliteColumnBlob", blob_ptr)
				ut.compareString("sqliteBlobString", blob_string, "")
				ut.compareCString("sqliteBlobCString", blob_cstring, "")
				ut.compareBytes(
					"sqliteColumnText",
					rawptrToBytes(text_ptr, text_len),
					[]byte{'t', 'e', 'x', 't', '3'},
				)
				ut.compareString("sqliteTextString", text_string, "text3")
				ut.compareCString("sqliteTextCString", text_cstring, "text3")
				ut.compareInteger("sqliteColumnInt64", integer, 3)
				ut.compareFloat("sqliteColumnDouble", float, 3.3)
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
			ut.compareCString("queryCallback", errorMessage(&sqlitedb), "another row available")
			//------------------------------------------------------------
			// sqliteStep
			//------------------------------------------------------------
			step_rc = sqliteStep(&sqlitedb, stmt_handle)
			ut.compareInteger("sqliteStep: rc", step_rc, SQLITE_ROW)
			ut.compareInteger("sqliteStep: returnCode", returnCode(&sqlitedb), SQLITE_ROW)
			ut.compareCString("queryCallback", errorMessage(&sqlitedb), "another row available")
			//------------------------------------------------------------
			// sqliteStep
			//------------------------------------------------------------
			step_rc = sqliteStep(&sqlitedb, stmt_handle)
			ut.compareInteger("sqliteStep: rc", step_rc, SQLITE_ROW)
			ut.compareInteger("sqliteStep: returnCode", returnCode(&sqlitedb), SQLITE_ROW)
			ut.compareCString("queryCallback", errorMessage(&sqlitedb), "another row available")
			//------------------------------------------------------------
			// sqliteStep
			//------------------------------------------------------------
			step_rc = sqliteStep(&sqlitedb, stmt_handle)
			ut.compareInteger("sqliteStep: rc", step_rc, SQLITE_DONE)
			ut.compareInteger("sqliteStep: returnCode", returnCode(&sqlitedb), SQLITE_DONE)
			ut.compareCString("queryCallback", errorMessage(&sqlitedb), "no more rows available")
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
		sqliteFinalize(&sqlitedb, stmt_handle)
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	// populate [5]SQLiteColumn
	//--------------------------------------------------------------------------------
	blob := "blob1"
	text := "text1"
	sqlite_columns := [5]SQLiteColumn {
		{index = 0, name = "id", column_type = .SQLITE_INTEGER, integer = 1},
		{
			index = 1,
			name = "blob",
			column_type = .SQLITE_BLOB,
			ptr = raw_data(blob),
			len = len(blob),
		},
		{
			index = 2,
			name = "text",
			column_type = .SQLITE_TEXT,
			ptr = raw_data(text),
			len = len(text),
		},
		{index = 3, name = "integer", column_type = .SQLITE_INTEGER, integer = 1},
		{index = 4, name = "float", column_type = .SQLITE_FLOAT, float = 1.1},
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
		ut.compareBytes("updateRow", fixed_row.blob, []byte{'b', 'l', 'o', 'b', '1'})
		ut.compareString("updateRow", fixed_row.text, "text1")
		ut.compareInteger("updateRow", fixed_row.integer, 1)
		ut.compareFloat("updateRow", fixed_row.float, 1.1)
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
		fixed_row_map := make(map[string]ColumnValue, context.allocator)
		//------------------------------------------------------------
		err := updateRowMap(&fixed_row_map, sqlite_columns[:], context.allocator)
		//------------------------------------------------------------
		ut.compareError("updateRowMap", err, nil)
		//------------------------------------------------------------
		id, _ := fixed_row_map["id"].(i64)
		blob, _ := fixed_row_map["blob"].([]u8)
		text, _ := fixed_row_map["text"].(string)
		integer, _ := fixed_row_map["integer"].(i64)
		float, _ := fixed_row_map["float"].(f64)
		//------------------------------------------------------------
		ut.compareInteger("updateRowMap", id, 1)
		ut.compareBytes("updateRowMap", blob, []byte{'b', 'l', 'o', 'b', '1'})
		ut.compareString("updateRowMap", text, "text1")
		ut.compareInteger("updateRowMap", integer, 1)
		ut.compareFloat("updateRowMap", float, 1.1)
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
		ut.compareInteger("sqliteGetTable: column_count", column_count, 5)
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
			table := cast([^]cstring)results
			//------------------------------------------------------------
			if row_count > 0 {
				ut.compareCString("sqliteGetTable", table[0], "id")
				ut.compareCString("sqliteGetTable", table[1], "blob")
				ut.compareCString("sqliteGetTable", table[2], "text")
				ut.compareCString("sqliteGetTable", table[3], "integer")
				ut.compareCString("sqliteGetTable", table[4], "float")
				ut.compareCString("sqliteGetTable", table[5], "1")
				ut.compareCString("sqliteGetTable", table[6], "blob1")
				ut.compareCString("sqliteGetTable", table[7], "text1")
				ut.compareCString("sqliteGetTable", table[8], "1")
				ut.compareCString("sqliteGetTable", table[9], "1.1")
			}
			if row_count > 1 {
				ut.compareCString("sqliteGetTable", table[10], "2")
				ut.compareCString("sqliteGetTable", table[11], "blob2")
				ut.compareCString("sqliteGetTable", table[12], "text2")
				ut.compareCString("sqliteGetTable", table[13], "2")
				ut.compareCString("sqliteGetTable", table[14], "2.2")
			}
			if row_count > 2 {
				ut.compareCString("sqliteGetTable", table[15], "3")
				ut.compareCString("sqliteGetTable", table[16], nil)
				ut.compareCString("sqliteGetTable", table[17], "text3")
				ut.compareCString("sqliteGetTable", table[18], "3")
				ut.compareCString("sqliteGetTable", table[19], "3.3")
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

			ut.compareInteger("getColumnCount: column_count", column_count, 5)
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
		table := SQLiteColumnsTable{}
		//------------------------------------------------------------
		err := getSQLiteColumnsTable(&sqlitedb, "SELECT * FROM test;", &table)
		//------------------------------------------------------------
		ut.compareError("getSQLiteColumnsTable", err, nil)
		//------------------------------------------------------------
		if err == nil {
			//------------------------------------------------------------
			defer freeSQLiteColumnsTable(&sqlitedb, &table)
			//------------------------------------------------------------
			table_row_len := len(table.sqlite_columns)
			ut.compareInteger("getSQLiteColumnsTable: table_row_len", table_row_len, 15)
			ut.compareInteger("getSQLiteColumnsTable: row_count", table.row_count, 3)
			ut.compareInteger("getSQLiteColumnsTable: column_count", table.column_count, 5)
			//------------------------------------------------------------
			if table.row_count > 0 && table_row_len > 0 {
				//------------------------------------------------------------
				column := table.sqlite_columns[0]
				ut.compareCString("getSQLiteColumnsTable: name", column.name, "id")
				ut.compareEnum(
					"getSQLiteColumnsTable: column_type",
					column.column_type,
					SQLiteColumnType.SQLITE_INTEGER,
				)
				ut.compareInteger("getSQLiteColumnsTable: integer", column.integer, 1)
				//------------------------------------------------------------
				column = table.sqlite_columns[1]
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
				column = table.sqlite_columns[2]
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
				column = table.sqlite_columns[3]
				ut.compareCString("getSQLiteColumnsTable: name", column.name, "integer")
				ut.compareEnum(
					"getSQLiteColumnsTable: column_type",
					column.column_type,
					SQLiteColumnType.SQLITE_INTEGER,
				)
				ut.compareInteger("getSQLiteColumnsTable: integer", column.integer, 1)
				//------------------------------------------------------------
				column = table.sqlite_columns[4]
				ut.compareCString("getSQLiteColumnsTable: name", column.name, "float")
				ut.compareEnum(
					"getSQLiteColumnsTable: column_type",
					column.column_type,
					SQLiteColumnType.SQLITE_FLOAT,
				)
				ut.compareFloat("getSQLiteColumnsTable: float", column.float, 1.1)
				//------------------------------------------------------------
			}
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	// queryCallback
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		err := queryCallback(&sqlitedb, "SELECT * FROM test;", newCallback, cast(rawptr)&ctx)
		ut.compareError("queryCallback", err, nil)
		ut.compareInteger("queryCallback", returnCode(&sqlitedb), SQLITE_OK)
		ut.compareCString("queryCallback", errorMessage(&sqlitedb), "")

		ut.compareInteger("queryCallback", len(ctx.fixed_rows), 3)

		if len(ctx.fixed_rows) > 0 {
			ut.compareInteger("queryCallback: id", ctx.fixed_rows[0].id, 1)
			ut.compareBytes(
				"queryCallback: blob",
				ctx.fixed_rows[0].blob,
				[]byte{'b', 'l', 'o', 'b', '1'},
			)
			ut.compareString("queryCallback: text", ctx.fixed_rows[0].text, "text1")
			ut.compareInteger("queryCallback: integer", ctx.fixed_rows[0].integer, 1)
			ut.compareFloat("queryCallback: float", ctx.fixed_rows[0].float, 1.1)
		}

		if len(ctx.fixed_rows) > 1 {
			ut.compareInteger("queryCallback: id", ctx.fixed_rows[1].id, 2)
			ut.compareBytes(
				"queryCallback: blob",
				ctx.fixed_rows[1].blob,
				[]byte{'b', 'l', 'o', 'b', '2'},
			)
			ut.compareString("queryCallback: text", ctx.fixed_rows[1].text, "text2")
			ut.compareInteger("queryCallback: integer", ctx.fixed_rows[1].integer, 2)
			ut.compareFloat("queryCallback: float", ctx.fixed_rows[1].float, 2.2)
		}

		if len(ctx.fixed_rows) > 2 {
			ut.compareInteger("queryCallback: id", ctx.fixed_rows[2].id, 3)
			ut.compareBytes("queryCallback: blob", ctx.fixed_rows[2].blob, []byte{})
			ut.compareString("queryCallback: text", ctx.fixed_rows[2].text, "text3")
			ut.compareInteger("queryCallback: integer", ctx.fixed_rows[2].integer, 3)
			ut.compareFloat("queryCallback: float", ctx.fixed_rows[2].float, 3.3)
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
callback :: proc "c" (ctx_ptr: rawptr, argc: i32, argv: [^]cstring, azColName: [^]cstring) -> i32 {
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
newCallback :: proc "c" (ctx_ptr: rawptr, columns_ptr: [^]SQLiteColumn, column_count: i32) -> i32 {
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
		case "blob":
			if column.column_type != .SQLITE_NULL {
				fixed_row.blob, _ = make([]u8, column.len, context.allocator)
				copy(fixed_row.blob[:], column.ptr[:column.len])
			}
		case "text":
			fixed_row.text = strings.clone(string(column.ptr[:column.len]))
		case "integer":
			fixed_row.integer = column.integer
		case "float":
			fixed_row.float = column.float
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
