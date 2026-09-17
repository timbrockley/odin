//--------------------------------------------------------------------------------
#+feature global-context
//--------------------------------------------------------------------------------

package sync_demo

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:sync"
import "core:sync/chan"
import "core:testing"

//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
DemoSyncError :: union #shared_nil {
	ChannelError,
	mem.Allocator_Error,
}
ChannelError :: enum {
	None,
	SendSignalError,
	ReceiveSignalError,
}
//------------------------------------------------------------
mutex: sync.Mutex
cond: sync.Cond
waitCondition: bool
channels: map[string]chan.Chan(bool)
//------------------------------------------------------------
// arena: virtual.Arena
// allocator := virtual.arena_allocator(&arena)
allocator: mem.Allocator
//------------------------------------------------------------
@(init)
setContext :: proc() {
	//------------------------------------------------------------
	allocator = context.allocator
	channels = make(map[string]chan.Chan(bool), allocator)
	//------------------------------------------------------------
}
//------------------------------------------------------------
@(fini)
// cleanup :: proc() {virtual.arena_destroy(&arena)}
cleanup :: proc() {delete(channels)}
//------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
@(test)
init_test :: proc(t: ^testing.T) {
	//------------------------------------------------------------
	log.info("init_test running")
	//------------------------------------------------------------
	initBroadcast()
	//------------------------------------------------------------
	err := sendSignal("test_one")
	testing.expect_value(t, err, nil)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
@(test)
test_one :: proc(t: ^testing.T) {
	//------------------------------------------------------------
	{
		log.info("test_one waiting")
		initWait()
		if err := receiveSignal("test_one"); err != nil {log.fatal(err); return}
		log.info("test_one running")
	}
	//------------------------------------------------------------
	{
		err := sendSignal("test_two")
		testing.expect_value(t, err, nil)
	}
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
@(test)
test_two :: proc(t: ^testing.T) {
	//------------------------------------------------------------
	{
		log.info("test_two waiting")
		initWait()
		if err := receiveSignal("test_two"); err != nil {log.fatal(err); return}
		log.info("test_two running")
	}
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
initBroadcast :: proc() {
	sync.mutex_lock(&mutex); defer sync.mutex_unlock(&mutex)
	waitCondition = true
	sync.cond_broadcast(&cond)
}
//------------------------------------------------------------
initWait :: proc() {
	sync.mutex_lock(&mutex); defer sync.mutex_unlock(&mutex)
	for !waitCondition {sync.cond_wait(&cond, &mutex)}
}
//------------------------------------------------------------
getChannel :: proc(name: string) -> (chan.Chan(bool), DemoSyncError) {
	//------------------------------------------------------------
	sync.mutex_lock(&mutex)
	defer sync.mutex_unlock(&mutex)

	channel, exists := channels[name]
	if (!exists) {
		err: DemoSyncError
		channel, err = chan.create(chan.Chan(bool), allocator)
		if err != nil {return {}, err}
		channels[name] = channel
	}

	return channel, nil
	//------------------------------------------------------------
}
//------------------------------------------------------------
sendSignal :: proc(name: string) -> DemoSyncError {
	channel, err := getChannel(name); if err != nil {return err}
	if success := chan.send(channel, true); !success {return .SendSignalError}
	return nil
}
//------------------------------------------------------------
receiveSignal :: proc(name: string) -> DemoSyncError {
	channel, err := getChannel(name); if err != nil {return err}
	if _, ok := chan.recv(channel); !ok {return .ReceiveSignalError}
	return nil
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
main :: proc() {
	//-----------------------------------------------------------
	fmt.printfln("%s: main function", filepath.base(os.args[0]))
	//-----------------------------------------------------------
}
//--------------------------------------------------------------------------------
//################################################################################
//--------------------------------------------------------------------------------
