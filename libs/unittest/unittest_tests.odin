package unittest

import "core:log"
import "core:testing"

//--------------------------------------------------------------------------------
@(test)
init_test :: proc(t: ^testing.T) {
	//----------------------------------------
	log.info("init_test running")
	//----------------------------------------
	initBroadcast()
	//----------------------------------------
	err := sendSignal("test_one")
	testing.expect_value(t, err, nil)
	//----------------------------------------
}
//--------------------------------------------------------------------------------
@(test)
test_one :: proc(t: ^testing.T) {
	//----------------------------------------
	{
		log.info("test_one waiting")
		initWait()
		if err := receiveSignal("test_one"); err != nil {log.fatal(err); return}
		log.info("test_one running")
	}
	//----------------------------------------
	{
		err := sendSignal("test_two")
		testing.expect_value(t, err, nil)
	}
	//----------------------------------------
}
//--------------------------------------------------------------------------------
@(test)
test_two :: proc(t: ^testing.T) {
	//----------------------------------------
	{
		log.info("test_two waiting")
		initWait()
		if err := receiveSignal("test_two"); err != nil {log.fatal(err); return}
		log.info("test_two running")
	}
	//----------------------------------------
}
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
