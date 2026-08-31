//--------------------------------------------------------------------------------
package sqlite
//--------------------------------------------------------------------------------
import "core:testing"
//--------------------------------------------------------------------------------
TestingFixedRow :: struct {
	id:      i64,
	blob:    []u8,
	text:    string,
	integer: i64,
	float:   f64,
}
//--------------------------------------------------------------------------------
// checkTableName
//--------------------------------------------------------------------------------
@(test)
checkTableName_test :: proc(t: ^testing.T) {
	//------------------------------------------------------------
	testing.expect_value(t, checkTableName(nil), false)
	testing.expect_value(t, checkTableName(""), false)
	testing.expect_value(t, checkTableName("1"), false)
	testing.expect_value(t, checkTableName("#"), false)
	testing.expect_value(t, checkTableName("A#"), false)
	testing.expect_value(t, checkTableName("A-"), false)
	testing.expect_value(t, checkTableName("_A"), true)
	testing.expect_value(t, checkTableName("_1"), true)
	testing.expect_value(t, checkTableName("A"), true)
	testing.expect_value(t, checkTableName("A1_A2"), true)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
// ptrToBytes / rawptrToBytes
//--------------------------------------------------------------------------------
@(test)
ptrToBytes_test :: proc(t: ^testing.T) {
	//------------------------------------------------------------
	data := [3]byte{'A', 'B', 'C'}

	ptr_bytes := ptrToBytes(&data[0], len(data))

	testing.expect_value(t, len(ptr_bytes), len(data))
	testing.expect_value(t, ptr_bytes[0], 'A')
	testing.expect_value(t, ptr_bytes[1], 'B')
	testing.expect_value(t, ptr_bytes[2], 'C')

	rawptr_bytes := rawptrToBytes(rawptr(&data[0]), len(data))

	testing.expect_value(t, len(rawptr_bytes), len(data))
	testing.expect_value(t, rawptr_bytes[0], 'A')
	testing.expect_value(t, rawptr_bytes[1], 'B')
	testing.expect_value(t, rawptr_bytes[2], 'C')
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
// bytesToString / bytesToCString
//--------------------------------------------------------------------------------
@(test)
bytesToString_test :: proc(t: ^testing.T) {
	//------------------------------------------------------------
	string_bytes := []byte{'A', 'B', 'C'}
	{
		result_string := bytesToString(string_bytes)
		testing.expect(t, type_of(result_string) == string)
		testing.expect_value(t, result_string, "ABC")
	}
	{
		result_string := bytesToString(&string_bytes, len(string_bytes))
		testing.expect(t, type_of(result_string) == string)
		testing.expect_value(t, result_string, "ABC")
	}
	{
		result_string := bytesToString(rawptr(&string_bytes[0]), len(string_bytes))
		testing.expect(t, type_of(result_string) == string)
		testing.expect_value(t, result_string, "ABC")
	}
	//------------------------------------------------------------
	cstring_bytes := []byte{'A', 'B', 'C', '\x00'}
	{
		result_cstring := bytesToCString(cstring_bytes)
		testing.expect(t, type_of(result_cstring) == cstring)
		testing.expect_value(t, result_cstring, "ABC")
	}
	{
		result_cstring := bytesToCString(&cstring_bytes[0])
		testing.expect(t, type_of(result_cstring) == cstring)
		testing.expect_value(t, result_cstring, "ABC")
	}
	{
		result_cstring := bytesToCString(rawptr(&cstring_bytes[0]))
		testing.expect(t, type_of(result_cstring) == cstring)
		testing.expect_value(t, result_cstring, "ABC")
	}
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
// updateRow / setStructFieldValue / updateRowMap
//--------------------------------------------------------------------------------
@(test)
updateRow_test :: proc(t: ^testing.T) {
	//------------------------------------------------------------
	fixed_row := TestingFixedRow{}
	//------------------------------------------------------------
	blob := "blob1"
	text := "text1"
	test_rows := [5]SQLiteColumn {
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
	//------------------------------------------------------------
	{
		//------------------------------------------------------------
		err := updateRow(&fixed_row, test_rows[:], context.allocator)
		//------------------------------------------------------------
		testing.expect_value(t, err, nil)
		//------------------------------------------------------------
		testing.expect_value(t, fixed_row.id, 1)
		testing.expect_value(t, string(fixed_row.blob), "blob1")
		testing.expect_value(t, fixed_row.text, "text1")
		testing.expect_value(t, fixed_row.integer, 1)
		testing.expect_value(t, fixed_row.float, 1.1)
		//------------------------------------------------------------
		if err == nil {
			delete(fixed_row.blob, context.allocator)
			delete(fixed_row.text, context.allocator)
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	{
		//------------------------------------------------------------
		fixed_row_map := make(map[string]ColumnValue, context.allocator)
		//------------------------------------------------------------
		err := updateRowMap(&fixed_row_map, test_rows[:], context.allocator)
		//------------------------------------------------------------
		testing.expect_value(t, err, nil)
		//------------------------------------------------------------
		id, _ := fixed_row_map["id"].(i64)
		blob, _ := fixed_row_map["blob"].([]u8)
		text, _ := fixed_row_map["text"].(string)
		integer, _ := fixed_row_map["integer"].(i64)
		float, _ := fixed_row_map["float"].(f64)
		//------------------------------------------------------------
		testing.expect_value(t, id, 1)
		testing.expect_value(t, text, "text1")
		testing.expect_value(t, string(blob), "blob1")
		testing.expect_value(t, integer, 1)
		testing.expect_value(t, float, 1.1)
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
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
// sqliteMalloc64 / sqliteRealloc64 / sqliteFree
//--------------------------------------------------------------------------------
@(test)
malloc_test :: proc(t: ^testing.T) {
	//------------------------------------------------------------
	ptr := sqliteMalloc64(16)

	testing.expect_value(t, ptr != nil, true)

	if ptr != nil {
		mem := cast([^]u8)(ptr)

		mem[0] = 'A'
		mem[1] = 'B'
		mem[2] = 'C'
		mem[3] = 0

		ptr = sqliteRealloc64(ptr, 64)

		testing.expect_value(t, ptr != nil, true)

		if ptr != nil {
			mem = cast([^]u8)(ptr)

			testing.expect_value(t, mem[0], u8('A'))
			testing.expect_value(t, mem[1], u8('B'))
			testing.expect_value(t, mem[2], u8('C'))
			testing.expect_value(t, mem[3], u8(0))

			sqliteFree(ptr)
		}
	}
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
