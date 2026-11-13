//--------------------------------------------------------------------------------
package mysql
//--------------------------------------------------------------------------------
import "core:testing"
//--------------------------------------------------------------------------------
TestingFixedRow :: struct {
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
	_text:          string,
	_blob:          []u8,
	_blob_nullable: []u8,
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
	data := [3]u8{'A', 'B', 'C'}

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
// stringTobytes
//--------------------------------------------------------------------------------
@(test)
stringTobytes_test :: proc(t: ^testing.T) {
	//------------------------------------------------------------
	empty := stringToBytes("")
	testing.expect(t, len(empty) == 0)

	string_bytes := stringToBytes("ABCD\xF0\x9F\x90\xA7")

	testing.expect(t, len(string_bytes) == 8)

	testing.expect(t, string_bytes[0] == 'A')
	testing.expect(t, string_bytes[1] == 'B')
	testing.expect(t, string_bytes[2] == 'C')
	testing.expect(t, string_bytes[3] == 'D')

	testing.expect(t, string_bytes[4] == 0xF0)
	testing.expect(t, string_bytes[5] == 0x9F)
	testing.expect(t, string_bytes[6] == 0x90)
	testing.expect(t, string_bytes[7] == 0xA7)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
// bytesToString / bytesToCString
//--------------------------------------------------------------------------------
@(test)
bytesToString_test :: proc(t: ^testing.T) {
	//------------------------------------------------------------
	string_bytes := []u8{'A', 'B', 'C'}
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
	cstring_bytes := []u8{'A', 'B', 'C', '\x00'}
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
	testing_fixed_row := TestingFixedRow{}
	//------------------------------------------------------------
	test_rows := [16]MySQLColumn {
		{index = 0, name = "id", type = .uint32, value = u32(1)},
		{index = 1, name = "_u8", type = .uint8, value = u8(8)},
		{index = 2, name = "_i8", type = .int8, value = i8(-8)},
		{index = 3, name = "_u16", type = .uint16, value = u16(16)},
		{index = 4, name = "_i16", type = .int16, value = i16(-16)},
		{index = 5, name = "_u24", type = .uint24, value = u32(24)},
		{index = 6, name = "_i24", type = .int24, value = i32(-24)},
		{index = 7, name = "_u32", type = .uint32, value = u32(32)},
		{index = 8, name = "_i32", type = .int32, value = i32(-32)},
		{index = 9, name = "_u64", type = .uint64, value = u64(64)},
		{index = 10, name = "_i64", type = .int64, value = i64(-64)},
		{index = 11, name = "_f32", type = .float32, value = f32(32.32)},
		{index = 12, name = "_f64", type = .float64, value = f64(64.64)},
		{index = 13, name = "_text", type = .string, value = "_text"},
		{index = 14, name = "_blob", type = .blob, value = []u8{'_', 'b', 'l', 'o', 'b'}},
		{index = 15, name = "_blob_nullable", type = .null},
	}
	//------------------------------------------------------------
	{
		//------------------------------------------------------------
		err := updateRow(&testing_fixed_row, test_rows[:], context.allocator)
		//------------------------------------------------------------
		testing.expect_value(t, err, nil)
		//------------------------------------------------------------
		testing.expect_value(t, testing_fixed_row.id, 1)
		testing.expect_value(t, testing_fixed_row._u8, 8)
		testing.expect_value(t, testing_fixed_row._i8, -8)
		testing.expect_value(t, testing_fixed_row._u16, 16)
		testing.expect_value(t, testing_fixed_row._i16, -16)
		testing.expect_value(t, testing_fixed_row._u24, 24)
		testing.expect_value(t, testing_fixed_row._i24, -24)
		testing.expect_value(t, testing_fixed_row._u32, 32)
		testing.expect_value(t, testing_fixed_row._i32, -32)
		testing.expect_value(t, testing_fixed_row._u64, 64)
		testing.expect_value(t, testing_fixed_row._i64, -64)
		testing.expect_value(t, testing_fixed_row._f32, 32.32)
		testing.expect_value(t, testing_fixed_row._f64, 64.64)
		testing.expect_value(t, testing_fixed_row._text, "_text")
		testing.expect_value(t, string(testing_fixed_row._blob), "_blob")
		testing.expect(t, testing_fixed_row._blob_nullable == nil)
		//------------------------------------------------------------
		if err == nil {
			delete(testing_fixed_row._text, context.allocator)
			if testing_fixed_row._blob != nil do delete(testing_fixed_row._blob, context.allocator)
			if testing_fixed_row._blob_nullable != nil do delete(testing_fixed_row._blob_nullable, context.allocator)
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	{
		//------------------------------------------------------------
		testing_fixed_row_map := make(map[string]ColumnValue, context.allocator)
		//------------------------------------------------------------
		err := updateRowMap(&testing_fixed_row_map, test_rows[:], context.allocator)
		//------------------------------------------------------------
		testing.expect_value(t, err, nil)
		//------------------------------------------------------------
		id, _ := testing_fixed_row_map["id"].(u32)
		_u8, _ := testing_fixed_row_map["_u8"].(u8)
		_i8, _ := testing_fixed_row_map["_i8"].(i8)
		_u16, _ := testing_fixed_row_map["_u16"].(u16)
		_i16, _ := testing_fixed_row_map["_i16"].(i16)
		_u24, _ := testing_fixed_row_map["_u24"].(u32)
		_i24, _ := testing_fixed_row_map["_i24"].(i32)
		_u32, _ := testing_fixed_row_map["_u32"].(u32)
		_i32, _ := testing_fixed_row_map["_i32"].(i32)
		_u64, _ := testing_fixed_row_map["_u64"].(u64)
		_i64, _ := testing_fixed_row_map["_i64"].(i64)
		_f32, _ := testing_fixed_row_map["_f32"].(f32)
		_f64, _ := testing_fixed_row_map["_f64"].(f64)
		_text, _ := testing_fixed_row_map["_text"].(string)
		_blob, _ := testing_fixed_row_map["_blob"].([]u8)
		_blob_nullable, _ := testing_fixed_row_map["_blob_nullable"].([]u8)
		//------------------------------------------------------------
		testing.expect_value(t, id, 1)
		testing.expect_value(t, _u8, 8)
		testing.expect_value(t, _i8, -8)
		testing.expect_value(t, _u16, 16)
		testing.expect_value(t, _i16, -16)
		testing.expect_value(t, _u24, 24)
		testing.expect_value(t, _i24, -24)
		testing.expect_value(t, _u32, 32)
		testing.expect_value(t, _i32, -32)
		testing.expect_value(t, _u64, 64)
		testing.expect_value(t, _i64, -64)
		testing.expect_value(t, _f32, 32.32)
		testing.expect_value(t, _f64, 64.64)
		testing.expect_value(t, _text, "_text")
		testing.expect_value(t, string(_blob), "_blob")
		testing.expect(t, _blob_nullable == nil)
		//------------------------------------------------------------
		if err == nil {
			for _, value in testing_fixed_row_map {
				#partial switch v in value {
				case string:
					delete(v, context.allocator)
				case []u8:
					delete(v, context.allocator)
				}
			}
			delete(testing_fixed_row_map)
		}
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
