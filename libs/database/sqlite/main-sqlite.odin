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
	id:            i64,
	uint64:        u64,
	integer:       i64,
	float:         f64,
	text:          string,
	blob:          []u8,
	blob_nullable: []u8,
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
	// sqlite3_open / sqlite3_close
	//--------------------------------------------------------------------------------
	db_handle: ^rawptr = nil
	//------------------------------------------------------------
	rc := sqlite3_open(DATABASE_FILEPATH, &db_handle)
	//------------------------------------------------------------
	ut.compareInteger("sqlite3_open", rc, SQLITE_OK)
	if rc != SQLITE_OK {
		fmt.printfln("%s", sqlite3_errmsg(db_handle))
		ut.printLine()
		return
	}
	//------------------------------------------------------------
	defer sqlite3_close(db_handle)
	//--------------------------------------------------------------------------------
	//################################################################################
	//--------------------------------------------------------------------------------
	// sqlite3_exec / sqlite3_free
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		sql: cstring = `PRAGMA journal_mode=WAL;
				DROP TABLE IF EXISTS test;
				CREATE TABLE IF NOT EXISTS test (id INTEGER PRIMARY KEY AUTOINCREMENT, uint64 INTEGER UNSIGNED DEFAULT 0 NOT NULL, integer INTEGER DEFAULT 0 NOT NULL, float REAL DEFAULT 0 NOT NULL, text VARCHAR(255) DEFAULT '' NOT NULL, blob BLOB DEFAULT '' NOT NULL, blob_nullable BLOB);
		 		INSERT INTO test (uint64, integer, float, text, blob) VALUES(1, 1, 1.1, 'text1', X'626C6F6231');
			 	SELECT * FROM test;`
		//------------------------------------------------------------
		errmsg: rawptr = nil
		rc := sqlite3_exec(db_handle, sql, execCallback, cast(rawptr)&ctx, &errmsg)
		if rc != SQLITE_OK {defer sqlite3_free(errmsg)}
		//------------------------------------------------------------
		ut.compareInteger("sqlite3_exec: rc", rc, SQLITE_OK)
		ut.compareCString("sqlite3_exec: errmsg", cstring(errmsg), nil)
		ut.compareInteger("sqlite3_exec: string_columns", len(ctx.string_columns), 8)
		if len(ctx.string_columns) > 1 {
			ut.compareString("sqlite3_exec: key", ctx.string_columns[0].key, "journal_mode")
			ut.compareString("sqlite3_exec: value", ctx.string_columns[0].value, "wal")
			ut.compareString("sqlite3_exec: key", ctx.string_columns[1].key, "id")
			ut.compareString("sqlite3_exec: value", ctx.string_columns[1].value, "1")
		}
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	//################################################################################
	//--------------------------------------------------------------------------------
	// sqlite3_get_table / sqlite3_free / sqlite3_free_table
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		results: ^cstring
		row_count: i32
		column_count: i32
		errmsg: rawptr
		//------------------------------------------------------------
		rc := sqlite3_get_table(
			db_handle,
			"SELECT * FROM test;",
			&results,
			&row_count,
			&column_count,
			&errmsg,
		)
		//------------------------------------------------------------
		ut.compareInteger("sqlite3_get_table: rc", rc, SQLITE_OK)
		ut.compareInteger("sqlite3_get_table: row_count", row_count, 1)
		ut.compareInteger("sqlite3_get_table: column_count", column_count, 7)
		ut.compareCString("sqlite3_get_table: errmsg", cstring(errmsg), nil)
		//------------------------------------------------------------
		if results == nil {
			//------------------------------------------------------------
			defer sqlite3_free(errmsg)
			//------------------------------------------------------------
		} else {
			//------------------------------------------------------------
			defer sqlite3_free_table(results)
			//------------------------------------------------------------
			results_table := cast([^]cstring)results
			//------------------------------------------------------------
			if row_count > 0 {
				ut.compareCString("sqlite3_get_table", results_table[0], "id")
				ut.compareCString("sqlite3_get_table", results_table[1], "uint64")
				ut.compareCString("sqlite3_get_table", results_table[2], "integer")
				ut.compareCString("sqlite3_get_table", results_table[3], "float")
				ut.compareCString("sqlite3_get_table", results_table[4], "text")
				ut.compareCString("sqlite3_get_table", results_table[5], "blob")
				ut.compareCString("sqlite3_get_table", results_table[6], "blob_nullable")
				ut.compareCString("sqlite3_get_table", results_table[7], "1")
				ut.compareCString("sqlite3_get_table", results_table[8], "1")
				ut.compareCString("sqlite3_get_table", results_table[9], "1")
				ut.compareCString("sqlite3_get_table", results_table[10], "1.1")
				ut.compareCString("sqlite3_get_table", results_table[11], "text1")
				ut.compareCString("sqlite3_get_table", results_table[12], "blob1")
				ut.compareCString("sqlite3_get_table", results_table[13], nil)
			}
			if row_count > 1 {
				ut.compareCString("sqlite3_get_table", results_table[14], "2")
				ut.compareCString("sqlite3_get_table", results_table[15], "2")
				ut.compareCString("sqlite3_get_table", results_table[16], "2")
				ut.compareCString("sqlite3_get_table", results_table[17], "2.2")
				ut.compareCString("sqlite3_get_table", results_table[18], "text2")
				ut.compareCString("sqlite3_get_table", results_table[19], "blob2")
				ut.compareCString("sqlite3_get_table", results_table[20], nil)
			}
			if row_count > 2 {
				ut.compareCString("sqlite3_get_table", results_table[21], "3")
				ut.compareCString("sqlite3_get_table", results_table[22], "3")
				ut.compareCString("sqlite3_get_table", results_table[23], "3")
				ut.compareCString("sqlite3_get_table", results_table[24], "3.3")
				ut.compareCString("sqlite3_get_table", results_table[25], "text3")
				ut.compareCString("sqlite3_get_table", results_table[26], "blob3")
				ut.compareCString("sqlite3_get_table", results_table[27], nil)
			}
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	// SQLiteColumnsTable / freeSQLiteColumnsTable
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		table, err := getSQLiteColumnsTable(db_handle, "SELECT * FROM test;")
		defer freeSQLiteColumnsTable(table)
		//------------------------------------------------------------
		if err != nil {
			//------------------------------------------------------------
			ut.compareError("getSQLiteColumnsTable", err, nil)
			//------------------------------------------------------------
		} else {
			//------------------------------------------------------------
			total_columns := len(table.sqlite_columns)
			ut.compareInteger("getSQLiteColumnsTable: total_columns", total_columns, 7)
			ut.compareInteger("getSQLiteColumnsTable: row_count", table.row_count, 1)
			ut.compareInteger("getSQLiteColumnsTable: column_count", table.column_count, 7)
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
	//################################################################################
	//--------------------------------------------------------------------------------
	// querySQLiteColumns
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		err := querySQLiteColumns(
			db_handle,
			"SELECT * FROM test;",
			queryCallback,
			cast(rawptr)&ctx,
		)
		ut.compareError("querySQLiteColumns", err, nil)

		ut.compareInteger("querySQLiteColumns", len(ctx.fixed_rows), 1)

		if len(ctx.fixed_rows) > 0 {
			ut.compareInteger("querySQLiteColumns: id", ctx.fixed_rows[0].id, 1)
			ut.compareInteger("querySQLiteColumns: uint64", ctx.fixed_rows[0].uint64, 1)
			ut.compareInteger("querySQLiteColumns: integer", ctx.fixed_rows[0].integer, 1)
			ut.compareFloat("querySQLiteColumns: float", ctx.fixed_rows[0].float, 1.1)
			ut.compareString("querySQLiteColumns: text", ctx.fixed_rows[0].text, "text1")
			ut.compareBytes(
				"querySQLiteColumns: blob",
				ctx.fixed_rows[0].blob,
				[]u8{'b', 'l', 'o', 'b', '1'},
			)
		}

		if len(ctx.fixed_rows) > 1 {
			ut.compareInteger("querySQLiteColumns: id", ctx.fixed_rows[1].id, 2)
			ut.compareInteger("querySQLiteColumns: uint64", ctx.fixed_rows[1].uint64, 2)
			ut.compareInteger("querySQLiteColumns: integer", ctx.fixed_rows[1].integer, 2)
			ut.compareFloat("querySQLiteColumns: float", ctx.fixed_rows[1].float, 2.2)
			ut.compareString("querySQLiteColumns: text", ctx.fixed_rows[1].text, "text2")
			ut.compareBytes(
				"querySQLiteColumns: blob",
				ctx.fixed_rows[1].blob,
				[]u8{'b', 'l', 'o', 'b', '2'},
			)
		}

		if len(ctx.fixed_rows) > 2 {
			ut.compareInteger("querySQLiteColumns: id", ctx.fixed_rows[2].id, 3)
			ut.compareInteger("querySQLiteColumns: uint64", ctx.fixed_rows[2].uint64, 3)
			ut.compareInteger("querySQLiteColumns: integer", ctx.fixed_rows[2].integer, 3)
			ut.compareFloat("querySQLiteColumns: float", ctx.fixed_rows[2].float, 3.3)
			ut.compareString("querySQLiteColumns: text", ctx.fixed_rows[2].text, "text3")
			ut.compareBytes(
				"querySQLiteColumns: blob",
				ctx.fixed_rows[2].blob,
				[]u8{'b', 'l', 'o', 'b', '3'},
			)
		}
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	// getTableRowCount / getRowCount / getColumnCount
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		{
			row_count, err := getTableRowCount(db_handle, "test")

			ut.compareInteger("getTableRowCount: row_count", row_count, 1)
			ut.compareError("getTableRowCount: err", err, nil)
		}
		//------------------------------------------------------------
		{
			row_count, err := getRowCount(db_handle, "SELECT * FROM test;")

			ut.compareInteger("getRowCount: row_count", row_count, 1)
			ut.compareError("getRowCount: err", err, nil)
		}
		//------------------------------------------------------------
		{
			column_count, err := getColumnCount(db_handle, "SELECT * FROM test LIMIT 1;")

			ut.compareInteger("getColumnCount: column_count", column_count, 7)
			ut.compareError("getColumnCount: err", err, nil)
		}
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	//################################################################################
	//--------------------------------------------------------------------------------
	// sqlite3_prepare_v2 / sqlite3_clear_bindings / sqlite3_bind* / sqlite3_step /
	// sqlite3_finalize / sqlite3_errmsg
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		stmt_handle: ^rawptr
		//------------------------------------------------------------
		sql := cstring(
			"INSERT INTO test (uint64, integer, float, text, blob) VALUES(?, ?, ?, ?, ?);",
		)
		//------------------------------------------------------------
		rc := sqlite3_prepare_v2(db_handle, sql, -1, &stmt_handle, nil)
		//------------------------------------------------------------
		defer sqlite3_finalize(stmt_handle)
		//------------------------------------------------------------
		ut.compareInteger("sqlite3_prepare_v2: rc", rc, SQLITE_OK)
		ut.compareCString("sqlite3_prepare_v2: errmsg", sqlite3_errmsg(db_handle), "not an error")
		//------------------------------------------------------------
		rc = sqlite3_clear_bindings(stmt_handle)
		ut.compareInteger("sqlite3_clear_bindings: rc", rc, SQLITE_OK)
		ut.compareCString(
			"sqlite3_clear_bindings: errmsg",
			sqlite3_errmsg(db_handle),
			"not an error",
		)
		//------------------------------------------------------------
		if rc == SQLITE_OK {
			//------------------------------------------------------------
			uint64: u64 = 2
			rc := sqlite3_bind_int64(stmt_handle, 1, transmute(i64)uint64)
			ut.compareInteger("sqlite3_bind_int64: rc", rc, SQLITE_OK)
			ut.compareCString(
				"sqlite3_bind_int64: errmsg",
				sqlite3_errmsg(db_handle),
				"not an error",
			)
			//------------------------------------------------------------
			rc = sqlite3_bind_int64(stmt_handle, 2, 2)
			ut.compareInteger("sqlite3_bind_int64: rc", rc, SQLITE_OK)
			ut.compareCString(
				"sqlite3_bind_int64: errmsg",
				sqlite3_errmsg(db_handle),
				"not an error",
			)
			//------------------------------------------------------------
			rc = sqlite3_bind_double(stmt_handle, 3, 2.2)
			ut.compareInteger("sqlite3_bind_double: rc", rc, SQLITE_OK)
			ut.compareCString(
				"sqlite3_bind_double: errmsg",
				sqlite3_errmsg(db_handle),
				"not an error",
			)
			//------------------------------------------------------------
			text := "text2"
			rc = sqlite3_bind_text(stmt_handle, 4, raw_data(text), i32Len(text), nil)
			ut.compareInteger("sqlite3_bind_text: rc", rc, SQLITE_OK)
			ut.compareCString(
				"sqlite3_bind_text: errmsg",
				sqlite3_errmsg(db_handle),
				"not an error",
			)
			//------------------------------------------------------------
			blob := "blob2"
			rc = sqlite3_bind_blob(stmt_handle, 5, raw_data(blob), i32Len(blob), nil)
			ut.compareInteger("sqlite3_bind_blob: rc", rc, SQLITE_OK)
			ut.compareCString(
				"sqlite3_bind_blob: errmsg",
				sqlite3_errmsg(db_handle),
				"not an error",
			)
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
		rc = sqlite3_step(stmt_handle)
		ut.compareInteger("sqlite3_step: rc", rc, SQLITE_DONE)
		ut.compareCString(
			"sqlite3_step: errmsg",
			sqlite3_errmsg(db_handle),
			"no more rows available",
		)
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	// sqlite3_prepare_v2 / sqlite3_clear_bindings / sqlite3_bind* / sqlite3_step /
	// sqlite3_finalize / sqlite3_errmsg
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		stmt_handle: ^rawptr
		//------------------------------------------------------------
		sql := cstring(
			"INSERT INTO test (uint64, integer, float, text, blob, blob_nullable) VALUES(?, ?, ?, ?, ?, ?);",
		)
		//------------------------------------------------------------
		rc := sqlite3_prepare_v2(db_handle, sql, -1, &stmt_handle, nil)
		//------------------------------------------------------------
		defer sqlite3_finalize(stmt_handle)
		//------------------------------------------------------------
		ut.compareInteger("sqlitePrepare: rc", rc, SQLITE_OK)
		ut.compareCString("sqlite3_prepare_v2: errmsg", sqlite3_errmsg(db_handle), "not an error")
		//------------------------------------------------------------
		rc = sqlite3_clear_bindings(stmt_handle)
		ut.compareInteger("sqlite3_clear_bindings: rc", rc, SQLITE_OK)
		ut.compareCString(
			"sqlite3_clear_bindings: errmsg",
			sqlite3_errmsg(db_handle),
			"not an error",
		)
		//------------------------------------------------------------
		if rc == SQLITE_OK {
			//------------------------------------------------------------
			uint64: u64 = 0xFFFF_FFFF_FFFF_FFFF
			rc = sqlite3_bind_int64(stmt_handle, 1, transmute(i64)uint64)
			ut.compareInteger("sqlite3_bind_int64: rc", rc, SQLITE_OK)
			ut.compareCString(
				"sqlite3_bind_int64: errmsg",
				sqlite3_errmsg(db_handle),
				"not an error",
			)
			//------------------------------------------------------------
			rc = sqlite3_bind_int64(stmt_handle, 2, 3)
			ut.compareInteger("sqlite3_bind_int64: rc", rc, SQLITE_OK)
			ut.compareCString(
				"sqlite3_bind_int64: errmsg",
				sqlite3_errmsg(db_handle),
				"not an error",
			)
			//------------------------------------------------------------
			rc = sqlite3_bind_double(stmt_handle, 3, 3.3)
			ut.compareInteger("sqlite3_bind_double: rc", rc, SQLITE_OK)
			ut.compareCString(
				"sqlite3_bind_double: errmsg",
				sqlite3_errmsg(db_handle),
				"not an error",
			)
			//------------------------------------------------------------
			text := "text3"
			rc = sqlite3_bind_text(stmt_handle, 4, raw_data(text), i32Len(text), nil)
			ut.compareInteger("sqlite3_bind_text: rc", rc, SQLITE_OK)
			ut.compareCString(
				"sqlite3_bind_text: errmsg",
				sqlite3_errmsg(db_handle),
				"not an error",
			)
			//------------------------------------------------------------
			blob := "blob3"
			rc = sqlite3_bind_blob(stmt_handle, 5, raw_data(blob), i32Len(blob), nil)
			ut.compareInteger("sqlite3_bind_blob: rc", rc, SQLITE_OK)
			ut.compareCString(
				"sqlite3_bind_blob: errmsg",
				sqlite3_errmsg(db_handle),
				"not an error",
			)
			//------------------------------------------------------------
			rc = sqlite3_bind_null(stmt_handle, 6)
			ut.compareInteger("sqlite3_bind_null: rc", rc, SQLITE_OK)
			ut.compareCString(
				"sqlite3_bind_null: errmsg",
				sqlite3_errmsg(db_handle),
				"not an error",
			)
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
		rc = sqlite3_step(stmt_handle)
		ut.compareInteger("sqlite3_step: rc", rc, SQLITE_DONE)
		ut.compareCString(
			"sqlite3_step: errmsg",
			sqlite3_errmsg(db_handle),
			"no more rows available",
		)
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	// sqlite3_prepare_v2 / sqlite3_column* / sqlite3_bind* / sqlite3_step / sqlite3_finalize
	//--------------------------------------------------------------------------------
	{
		//------------------------------------------------------------
		stmt_handle: ^rawptr
		//------------------------------------------------------------
		sql := cstring("SELECT * FROM test;")
		//------------------------------------------------------------
		rc := sqlite3_prepare_v2(db_handle, sql, -1, &stmt_handle, nil)
		//------------------------------------------------------------
		defer sqlite3_finalize(stmt_handle)
		//------------------------------------------------------------
		ut.compareInteger("sqlitePrepare: rc", rc, SQLITE_OK)
		ut.compareCString("sqlite3_prepare_v2: errmsg", sqlite3_errmsg(db_handle), "not an error")
		//------------------------------------------------------------
		// sqlite3_column_name
		//------------------------------------------------------------
		column_id_ptr := sqlite3_column_name(stmt_handle, 0)
		column_uint64_ptr := sqlite3_column_name(stmt_handle, 1)
		column_integer_ptr := sqlite3_column_name(stmt_handle, 2)
		column_float_ptr := sqlite3_column_name(stmt_handle, 3)
		column_text_ptr := sqlite3_column_name(stmt_handle, 4)
		column_blob_ptr := sqlite3_column_name(stmt_handle, 5)
		column_blob_nullable_ptr := sqlite3_column_name(stmt_handle, 6)
		//------------------------------------------------------------
		column_id := cstring(column_id_ptr)
		column_uint64 := cstring(column_uint64_ptr)
		column_integer := cstring(column_integer_ptr)
		column_float := cstring(column_float_ptr)
		column_text := cstring(column_text_ptr)
		column_blob := cstring(column_blob_ptr)
		column_blob_nullable := cstring(column_blob_nullable_ptr)
		//------------------------------------------------------------
		ut.compareCString("sqlite3_column_name: id", column_id, "id")
		ut.compareCString("sqlite3_column_name: uint64", column_uint64, "uint64")
		ut.compareCString("sqlite3_column_name: integer", column_integer, "integer")
		ut.compareCString("sqlite3_column_name: float", column_float, "float")
		ut.compareCString("sqlite3_column_name: text", column_text, "text")
		ut.compareCString("sqlite3_column_name: blob", column_blob, "blob")
		ut.compareCString(
			"sqlite3_column_name: blob_nullable",
			column_blob_nullable,
			"blob_nullable",
		)
		//------------------------------------------------------------
		if rc == SQLITE_OK {
			//------------------------------------------------------------
			// sqlite3_step
			//------------------------------------------------------------
			step_rc := sqlite3_step(stmt_handle)
			//------------------------------------------------------------
			ut.compareInteger("sqlite3_step", step_rc, SQLITE_ROW)
			ut.compareCString("sqlite3_step", sqlite3_errmsg(db_handle), "another row available")
			//------------------------------------------------------------
			if step_rc == SQLITE_ROW {
				//------------------------------------------------------------
				// sqlite3_column_type
				col0 := sqlite3_column_type(stmt_handle, 0)
				col1 := sqlite3_column_type(stmt_handle, 1)
				col2 := sqlite3_column_type(stmt_handle, 2)
				col3 := sqlite3_column_type(stmt_handle, 3)
				col4 := sqlite3_column_type(stmt_handle, 4)
				col5 := sqlite3_column_type(stmt_handle, 5)
				col6 := sqlite3_column_type(stmt_handle, 6)
				ut.compareInteger("sqlite3_column_type", col0, SQLITE_INTEGER)
				ut.compareInteger("sqlite3_column_type", col1, SQLITE_INTEGER)
				ut.compareInteger("sqlite3_column_type", col2, SQLITE_INTEGER)
				ut.compareInteger("sqlite3_column_type", col3, SQLITE_FLOAT)
				ut.compareInteger("sqlite3_column_type", col4, SQLITE_TEXT)
				ut.compareInteger("sqlite3_column_type", col5, SQLITE_BLOB)
				ut.compareInteger("sqlite3_column_type", col6, SQLITE_NULL)
				//------------------------------------------------------------
				// sqlite3_column_bytes (length)
				text_len := sqlite3_column_bytes(stmt_handle, 4)
				ut.compareInteger("sqlite3_column_bytes", text_len, 5)
				blob_len := sqlite3_column_bytes(stmt_handle, 5)
				ut.compareInteger("sqlite3_column_bytes", blob_len, 5)
				blob_nullable_len := sqlite3_column_bytes(stmt_handle, 6)
				ut.compareInteger("sqlite3_column_bytes", blob_nullable_len, 0)
				//------------------------------------------------------------
				// sqlite3_column*
				id := sqlite3_column_int64(stmt_handle, 0)
				uint64 := transmute(u64)(sqlite3_column_int64(stmt_handle, 1))
				integer := sqlite3_column_int64(stmt_handle, 2)
				float := sqlite3_column_double(stmt_handle, 3)
				text_ptr := sqlite3_column_text(stmt_handle, 4)
				text_string := sqliteTextString(stmt_handle, 4)
				text_cstring := sqliteTextCString(stmt_handle, 4)
				blob_ptr := sqlite3_column_blob(stmt_handle, 5)
				blob_string := sqliteBlobString(stmt_handle, 5)
				blob_cstring := sqliteBlobCString(stmt_handle, 5)
				blob_nullable_ptr := sqlite3_column_blob(stmt_handle, 6)
				blob_nullable_string := sqliteBlobString(stmt_handle, 6)
				blob_nullable_cstring := sqliteBlobCString(stmt_handle, 6)
				//------------------------------------------------------------
				// sqlite3_column*
				ut.compareTypeID("sqlite3_column_int64", type_of(id), i64)
				ut.compareTypeID("sqlite3_column_int64", type_of(uint64), u64)
				ut.compareTypeID("sqlite3_column_int64", type_of(integer), i64)
				ut.compareTypeID("sqlite3_column_double", type_of(float), f64)
				ut.compareTypeID("sqlite3_column_text", type_of(text_ptr), cstring)
				ut.compareTypeID("sqliteTextString", type_of(text_string), string)
				ut.compareTypeID("sqliteTextCString", type_of(text_cstring), cstring)
				ut.compareTypeID("sqlite3_column_blob", type_of(blob_ptr), rawptr)
				ut.compareTypeID("sqliteBlobString", type_of(blob_string), string)
				ut.compareTypeID("sqliteBlobCString", type_of(blob_cstring), cstring)
				ut.compareTypeID("sqlite3_column_blob", type_of(blob_nullable_ptr), rawptr)
				ut.compareTypeID("sqliteBlobString", type_of(blob_nullable_string), string)
				ut.compareTypeID("sqliteBlobCString", type_of(blob_nullable_cstring), cstring)
				//------------------------------------------------------------
				// sqlite3_column*
				ut.compareInteger("sqlite3_column_int64", id, 1)
				ut.compareInteger("sqlite3_column_int64", uint64, 1)
				ut.compareInteger("sqlite3_column_int64", integer, 1)
				ut.compareFloat("sqlite3_column_double", float, 1.1)
				ut.compareBytes(
					"sqlite3_column_text",
					cstringToBytes(text_ptr, text_len),
					[]u8{'t', 'e', 'x', 't', '1'},
				)
				ut.compareString("sqliteTextString", text_string, "text1")
				ut.compareCString("sqliteTextCString", text_cstring, "text1")
				ut.compareBytes(
					"sqlite3_column_blob",
					rawptrToBytes(blob_ptr, blob_len),
					[]u8{'b', 'l', 'o', 'b', '1'},
				)
				ut.compareBytes(
					"sqlite3_column_blob",
					rawptrToBytes(blob_nullable_ptr, blob_nullable_len),
					[]u8{},
				)
				ut.compareString("sqliteBlobString", blob_nullable_string, "")
				ut.compareCString("sqliteBlobCString", blob_nullable_cstring, "")
				//------------------------------------------------------------
				// sqlite3_column_count
				column_count := sqlite3_column_count(stmt_handle)
				ut.compareInteger("sqlite3_column_count", column_count, 7)
				//------------------------------------------------------------
				// sqlite3_data_count
				data_count := sqlite3_data_count(stmt_handle)
				ut.compareInteger("sqlite3_data_count", data_count, 7)
				//------------------------------------------------------------
			}
			//------------------------------------------------------------
			// sqlite3_step
			//------------------------------------------------------------
			step_rc = sqlite3_step(stmt_handle)
			//------------------------------------------------------------
			ut.compareInteger("sqlite3_step", step_rc, SQLITE_ROW)
			ut.compareCString("sqlite3_step", sqlite3_errmsg(db_handle), "another row available")
			//------------------------------------------------------------
			if step_rc == SQLITE_ROW {
				//------------------------------------------------------------
				// sqlite3_column_type
				col0 := sqlite3_column_type(stmt_handle, 0)
				col1 := sqlite3_column_type(stmt_handle, 1)
				col2 := sqlite3_column_type(stmt_handle, 2)
				col3 := sqlite3_column_type(stmt_handle, 3)
				col4 := sqlite3_column_type(stmt_handle, 4)
				col5 := sqlite3_column_type(stmt_handle, 5)
				col6 := sqlite3_column_type(stmt_handle, 6)
				ut.compareInteger("sqlite3_column_type", col0, SQLITE_INTEGER)
				ut.compareInteger("sqlite3_column_type", col1, SQLITE_INTEGER)
				ut.compareInteger("sqlite3_column_type", col2, SQLITE_INTEGER)
				ut.compareInteger("sqlite3_column_type", col3, SQLITE_FLOAT)
				ut.compareInteger("sqlite3_column_type", col4, SQLITE_TEXT)
				ut.compareInteger("sqlite3_column_type", col5, SQLITE_BLOB)
				ut.compareInteger("sqlite3_column_type", col6, SQLITE_NULL)
				//------------------------------------------------------------
				// sqlite3_column_bytes (length)
				text_len := sqlite3_column_bytes(stmt_handle, 4)
				ut.compareInteger("sqlite3_column_bytes", text_len, 5)
				blob_len := sqlite3_column_bytes(stmt_handle, 5)
				ut.compareInteger("sqlite3_column_bytes", blob_len, 5)
				blob_nullable_len := sqlite3_column_bytes(stmt_handle, 6)
				ut.compareInteger("sqlite3_column_bytes", blob_nullable_len, 0)
				//------------------------------------------------------------
				id := sqlite3_column_int64(stmt_handle, 0)
				uint64 := transmute(u64)(sqlite3_column_int64(stmt_handle, 1))
				integer := sqlite3_column_int64(stmt_handle, 2)
				float := sqlite3_column_double(stmt_handle, 3)
				text_ptr := sqlite3_column_text(stmt_handle, 4)
				text_string := sqliteTextString(stmt_handle, 4)
				text_cstring := sqliteTextCString(stmt_handle, 4)
				blob_ptr := sqlite3_column_blob(stmt_handle, 5)
				blob_string := sqliteBlobString(stmt_handle, 5)
				blob_cstring := sqliteBlobCString(stmt_handle, 5)
				blob_nullable_ptr := sqlite3_column_blob(stmt_handle, 6)
				blob_nullable_string := sqliteBlobString(stmt_handle, 6)
				blob_nullable_cstring := sqliteBlobCString(stmt_handle, 6)
				//------------------------------------------------------------
				// sqliteColumn*
				ut.compareTypeID("sqlite3_column_int64", type_of(id), i64)
				ut.compareTypeID("sqlite3_column_int64", type_of(uint64), u64)
				ut.compareTypeID("sqlite3_column_int64", type_of(integer), i64)
				ut.compareTypeID("sqlite3_column_double", type_of(float), f64)
				ut.compareTypeID("sqlite3_column_text", type_of(text_ptr), cstring)
				ut.compareTypeID("sqliteTextString", type_of(text_string), string)
				ut.compareTypeID("sqliteTextCString", type_of(text_cstring), cstring)
				ut.compareTypeID("sqlite3_column_blob", type_of(blob_ptr), rawptr)
				ut.compareTypeID("sqliteBlobString", type_of(blob_string), string)
				ut.compareTypeID("sqliteBlobCString", type_of(blob_cstring), cstring)
				ut.compareTypeID("sqlite3_column_blob", type_of(blob_nullable_ptr), rawptr)
				ut.compareTypeID("sqliteBlobString", type_of(blob_nullable_string), string)
				ut.compareTypeID("sqliteBlobCString", type_of(blob_nullable_cstring), cstring)
				//------------------------------------------------------------
				// sqliteColumn*
				ut.compareInteger("sqlite3_column_int64", id, 2)
				ut.compareInteger("sqlite3_column_int64", uint64, 2)
				ut.compareInteger("sqlite3_column_int64", integer, 2)
				ut.compareFloat("sqlite3_column_double", float, 2.2)
				ut.compareBytes(
					"sqlite3_column_text",
					cstringToBytes(text_ptr, text_len),
					[]u8{'t', 'e', 'x', 't', '2'},
				)
				ut.compareString("sqliteTextString", text_string, "text2")
				ut.compareCString("sqliteTextCString", text_cstring, "text2")
				ut.compareBytes(
					"sqlite3_column_blob",
					rawptrToBytes(blob_ptr, blob_len),
					[]u8{'b', 'l', 'o', 'b', '2'},
				)
				ut.compareString("sqliteBlobString", blob_string, "blob2")
				ut.compareCString("sqliteBlobCString", blob_cstring, "blob2")
				ut.compareBytes(
					"sqlite3_column_blob",
					rawptrToBytes(blob_nullable_ptr, blob_nullable_len),
					[]u8{},
				)
				ut.compareString("sqliteBlobString", blob_nullable_string, "")
				ut.compareCString("sqliteBlobCString", blob_nullable_cstring, "")
				//------------------------------------------------------------
			}
			//------------------------------------------------------------
			// sqlite3_step
			//------------------------------------------------------------
			step_rc = sqlite3_step(stmt_handle)
			//------------------------------------------------------------
			ut.compareInteger("sqlite3_step", step_rc, SQLITE_ROW)
			ut.compareCString("sqlite3_step", sqlite3_errmsg(db_handle), "another row available")
			//------------------------------------------------------------
			if step_rc == SQLITE_ROW {
				//------------------------------------------------------------
				// sqlite3_column_type
				col0 := sqlite3_column_type(stmt_handle, 0)
				col1 := sqlite3_column_type(stmt_handle, 1)
				col2 := sqlite3_column_type(stmt_handle, 2)
				col3 := sqlite3_column_type(stmt_handle, 3)
				col4 := sqlite3_column_type(stmt_handle, 4)
				col5 := sqlite3_column_type(stmt_handle, 5)
				col6 := sqlite3_column_type(stmt_handle, 6)
				ut.compareInteger("sqlite3_column_type", col0, SQLITE_INTEGER)
				ut.compareInteger("sqlite3_column_type", col1, SQLITE_INTEGER)
				ut.compareInteger("sqlite3_column_type", col2, SQLITE_INTEGER)
				ut.compareInteger("sqlite3_column_type", col3, SQLITE_FLOAT)
				ut.compareInteger("sqlite3_column_type", col4, SQLITE_TEXT)
				ut.compareInteger("sqlite3_column_type", col5, SQLITE_BLOB)
				ut.compareInteger("sqlite3_column_type", col6, SQLITE_NULL)
				//------------------------------------------------------------
				// sqlite3_column_bytes (length)
				text_len := sqlite3_column_bytes(stmt_handle, 4)
				ut.compareInteger("sqlite3_column_bytes", text_len, 5)
				blob_len := sqlite3_column_bytes(stmt_handle, 5)
				ut.compareInteger("sqlite3_column_bytes", blob_len, 5)
				blob_nullable_len := sqlite3_column_bytes(stmt_handle, 6)
				ut.compareInteger("sqlite3_column_bytes", blob_nullable_len, 0)
				//------------------------------------------------------------
				id := sqlite3_column_int64(stmt_handle, 0)
				uint64 := transmute(u64)(sqlite3_column_int64(stmt_handle, 1))
				integer := sqlite3_column_int64(stmt_handle, 2)
				float := sqlite3_column_double(stmt_handle, 3)
				text_ptr := sqlite3_column_text(stmt_handle, 4)
				text_string := sqliteTextString(stmt_handle, 4)
				text_cstring := sqliteTextCString(stmt_handle, 4)
				blob_ptr := sqlite3_column_blob(stmt_handle, 5)
				blob_string := sqliteBlobString(stmt_handle, 5)
				blob_cstring := sqliteBlobCString(stmt_handle, 5)
				blob_nullable_ptr := sqlite3_column_blob(stmt_handle, 6)
				blob_nullable_string := sqliteBlobString(stmt_handle, 6)
				blob_nullable_cstring := sqliteBlobCString(stmt_handle, 6)
				//------------------------------------------------------------
				unsigned_uint64 := isUnsigned(stmt_handle, 1)
				unsigned_integer := isUnsigned(stmt_handle, 2)
				//------------------------------------------------------------
				// sqliteColumn*
				ut.compareTypeID("sqlite3_column_int64", type_of(id), i64)
				ut.compareTypeID("sqlite3_column_int64", type_of(uint64), u64)
				ut.compareTypeID("sqlite3_column_int64", type_of(integer), i64)
				ut.compareTypeID("sqlite3_column_double", type_of(float), f64)
				ut.compareTypeID("sqlite3_column_text", type_of(text_ptr), cstring)
				ut.compareTypeID("sqliteTextString", type_of(text_string), string)
				ut.compareTypeID("sqliteTextCString", type_of(text_cstring), cstring)
				ut.compareTypeID("sqlite3_column_blob", type_of(blob_ptr), rawptr)
				ut.compareTypeID("sqliteBlobString", type_of(blob_string), string)
				ut.compareTypeID("sqliteBlobCString", type_of(blob_cstring), cstring)
				ut.compareTypeID("sqlite3_column_blob", type_of(blob_nullable_ptr), rawptr)
				ut.compareTypeID("sqliteBlobString", type_of(blob_nullable_string), string)
				ut.compareTypeID("sqliteBlobCString", type_of(blob_nullable_cstring), cstring)
				//------------------------------------------------------------
				// sqliteColumn*
				ut.compareInteger("sqlite3_column_int64", id, 3)
				ut.compareInteger("sqlite3_column_int64", uint64, 0xFFFF_FFFF_FFFF_FFFF)
				ut.compareInteger("sqlite3_column_int64", integer, 3)
				ut.compareFloat("sqlite3_column_double", float, 3.3)
				ut.compareBytes(
					"sqlite3_column_text",
					cstringToBytes(text_ptr, text_len),
					[]u8{'t', 'e', 'x', 't', '3'},
				)
				ut.compareString("sqliteTextString", text_string, "text3")
				ut.compareCString("sqliteTextCString", text_cstring, "text3")

				ut.compareBytes(
					"sqlite3_column_blob",
					rawptrToBytes(blob_ptr, blob_len),
					[]u8{'b', 'l', 'o', 'b', '3'},
				)
				ut.compareString("sqliteBlobString", blob_string, "blob3")
				ut.compareCString("sqliteBlobCString", blob_cstring, "blob3")
				ut.compareNull("sqlite3_column_blob", blob_nullable_ptr)
				ut.compareString("sqliteBlobString", blob_nullable_string, "")
				ut.compareCString("sqliteBlobCString", blob_nullable_cstring, "")
				//------------------------------------------------------------
				ut.compareBool("isUnsigned", unsigned_uint64, true)
				ut.compareBool("isUnsigned", unsigned_integer, false)
				//------------------------------------------------------------
			}
			//------------------------------------------------------------
			// sqlite3_step
			//------------------------------------------------------------
			step_rc = sqlite3_step(stmt_handle)
			ut.compareInteger("sqlite3_step", step_rc, SQLITE_DONE)
			ut.compareCString("sqlite3_step", sqlite3_errmsg(db_handle), "no more rows available")
			//------------------------------------------------------------
			// sqlite3_reset
			//------------------------------------------------------------
			reset_rc := sqlite3_reset(stmt_handle)
			ut.compareInteger("sqlite3_reset: rc", rc, SQLITE_OK)
			ut.compareCString("sqlite3_reset: errmsg", sqlite3_errmsg(db_handle), "not an error")
			//------------------------------------------------------------
			// sqlite3_step
			//------------------------------------------------------------
			step_rc = sqlite3_step(stmt_handle)
			ut.compareInteger("sqlite3_step: rc", step_rc, SQLITE_ROW)
			ut.compareCString(
				"sqlite3_step: errmsg",
				sqlite3_errmsg(db_handle),
				"another row available",
			)
			//------------------------------------------------------------
			// getSQLiteRow
			//------------------------------------------------------------
			fixed_row := FixedRow{}
			//------------------------------------------------------------
			err := getSQLiteRow(stmt_handle, &fixed_row)
			//------------------------------------------------------------
			ut.compareError("getSQLiteRow", err, nil)
			//------------------------------------------------------------
			ut.compareInteger("getSQLiteRow", fixed_row.id, 1)
			ut.compareInteger("getSQLiteRow", fixed_row.uint64, 1)
			ut.compareInteger("getSQLiteRow", fixed_row.integer, 1)
			ut.compareFloat("getSQLiteRow", fixed_row.float, 1.1)
			ut.compareString("getSQLiteRow", fixed_row.text, "text1")
			ut.compareBytes("getSQLiteRow", fixed_row.blob, []u8{'b', 'l', 'o', 'b', '1'})
			//------------------------------------------------------------
			if err == nil {
				delete(fixed_row.text, context.allocator)
				delete(fixed_row.blob, context.allocator)
			}
			//------------------------------------------------------------
			// sqlite3_step
			//------------------------------------------------------------
			step_rc = sqlite3_step(stmt_handle)
			ut.compareInteger("sqlite3_step: rc", step_rc, SQLITE_ROW)
			ut.compareCString(
				"sqlite3_step: errmsg",
				sqlite3_errmsg(db_handle),
				"another row available",
			)
			//------------------------------------------------------------
			// sqlite3_step
			//------------------------------------------------------------
			step_rc = sqlite3_step(stmt_handle)
			ut.compareInteger("sqlite3_step: rc", step_rc, SQLITE_ROW)
			ut.compareCString(
				"sqlite3_step: errmsg",
				sqlite3_errmsg(db_handle),
				"another row available",
			)
			//------------------------------------------------------------
			// sqlite3_step
			//------------------------------------------------------------
			step_rc = sqlite3_step(stmt_handle)
			ut.compareInteger("sqlite3_step: rc", step_rc, SQLITE_DONE)
			ut.compareCString(
				"sqlite3_step: errmsg",
				sqlite3_errmsg(db_handle),
				"no more rows available",
			)
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
	}
	//--------------------------------------------------------------------------------
	//################################################################################
	//--------------------------------------------------------------------------------
	// populate SQLiteColumns
	//--------------------------------------------------------------------------------
	text := "text1"
	blob := "blob1"
	//--------------------------------------------------------------------------------
	sqlite_columns := [7]SQLiteColumn {
		{index = 0, name = "id", column_type = .SQLITE_INTEGER, integer = 1},
		{
			index = 1,
			name = "uint64",
			column_type = .SQLITE_INTEGER,
			is_unsigned = true,
			integer = transmute(i64)u64(0xFFFF_FFFF_FFFF_FFFF),
		},
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
		{index = 6, name = "blob_nullable", column_type = .SQLITE_NULL},
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
		ut.compareInteger("updateRow", fixed_row.uint64, 0xFFFF_FFFF_FFFF_FFFF)
		ut.compareInteger("updateRow", fixed_row.integer, 1)
		ut.compareFloat("updateRow", fixed_row.float, 1.1)
		ut.compareString("updateRow", fixed_row.text, "text1")
		ut.compareBytes("updateRow", fixed_row.blob, []u8{'b', 'l', 'o', 'b', '1'})
		ut.compareNull("updateRow", fixed_row.blob_nullable)
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
		uint64, _ := fixed_row_map["uint64"].(u64)
		integer, _ := fixed_row_map["integer"].(i64)
		float, _ := fixed_row_map["float"].(f64)
		text, _ := fixed_row_map["text"].(string)
		blob, _ := fixed_row_map["blob"].([]u8)
		blob_nullable, _ := fixed_row_map["blob_nullable"].([]u8)
		//------------------------------------------------------------
		ut.compareInteger("updateRowMap", id, 1)
		ut.compareInteger("updateRowMap", uint64, 0xFFFF_FFFF_FFFF_FFFF)
		ut.compareInteger("updateRowMap", integer, 1)
		ut.compareFloat("updateRowMap", float, 1.1)
		ut.compareString("updateRowMap", text, "text1")
		ut.compareBytes("updateRowMap", blob, []u8{'b', 'l', 'o', 'b', '1'})
		ut.compareNull("updateRow", blob_nullable)
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
		//--------------------------------------------------------------------------------
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
			fixed_row.uint64 = transmute(u64)column.integer
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
