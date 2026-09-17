#+feature global-context

package lib

import "../unittest"
import "core:log"
import "core:testing"

//--------------------------------------------------------------------------------
@(test)
init_test :: proc(t: ^testing.T) {
	//----------------------------------------
	log.info("init_test running")
	//----------------------------------------
	unittest.initBroadcast()
	//----------------------------------------
	err := unittest.sendSignal("test_add")
	testing.expect_value(t, err, nil)
	//----------------------------------------
}
//--------------------------------------------------------------------------------
@(test)
test_add :: proc(t: ^testing.T) {
	//----------------------------------------
	{
		log.info("test_add waiting")
		unittest.initWait()
		if err := unittest.receiveSignal("test_add"); err != nil {log.fatal(err); return}
		log.info("test_add running")
	}
	//----------------------------------------
	{
		result, err := add(2, 3)
		testing.expect(t, result == 5, "add(2, 3) should be 5")
		testing.expect(t, err == nil, "err should nil")
	}
	//----------------------------------------
	{
		err := unittest.sendSignal("test_sub")
		testing.expect_value(t, err, nil)
	}
	//----------------------------------------
}
//--------------------------------------------------------------------------------
@(test)
test_sub :: proc(t: ^testing.T) {
	//----------------------------------------
	{
		log.info("test_sub waiting")
		unittest.initWait()
		if err := unittest.receiveSignal("test_sub"); err != nil {log.fatal(err); return}
		log.info("test_sub running")
	}
	//----------------------------------------
	{
		result, err := sub(5, 3)
		testing.expect(t, result == 2, "sub(5, 3) should be 2")
		testing.expect_value(t, err, nil)
	}
	//----------------------------------------
}
//--------------------------------------------------------------------------------
