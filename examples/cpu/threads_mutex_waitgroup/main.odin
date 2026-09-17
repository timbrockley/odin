package main

import "core:fmt"
import "core:math/rand"
import "core:sync"
import "core:thread"

//------------------------------------------------------------
sum: int
mutex: sync.Mutex
//------------------------------------------------------------
WorkerData :: struct {
	wg:    ^sync.Wait_Group,
	id:    int,
	value: int,
}
//------------------------------------------------------------
worker1 :: proc(t: ^thread.Thread) {
	//----------------------------------------
	data := cast(^WorkerData)t.data
	//----------------------------------------
	defer sync.wait_group_done(data.wg)
	//----------------------------------------
	sync.lock(&mutex)
	defer sync.unlock(&mutex)
	//----------------------------------------
	sum += data.value
	//----------------------------------------
	fmt.printfln("thread %d, value = %d, sum = %d", data.id, data.value, sum)
	//----------------------------------------
}
//------------------------------------------------------------
worker2 :: proc(data_ptr: rawptr) {
	//----------------------------------------
	data := cast(^WorkerData)data_ptr
	//----------------------------------------
	defer sync.wait_group_done(data.wg)
	//----------------------------------------
	sync.lock(&mutex)
	defer sync.unlock(&mutex)
	//----------------------------------------
	sum += data.value
	//----------------------------------------
	fmt.printfln("thread %d, value = %d, sum = %d", data.id, data.value, sum)
	//----------------------------------------
}
//------------------------------------------------------------
main :: proc() {
	//----------------------------------------
	wg: sync.Wait_Group
	//----------------------------------------
	sync.wait_group_add(&wg, 2)
	//----------------------------------------
	t1 := thread.create(worker1)
	t1.data = &WorkerData{wg = &wg, id = 1, value = rand.int_range(0, 9)}
	thread.start(t1)
	//----------------------------------------
	t2 := thread.create_and_start_with_data(
		&WorkerData{wg = &wg, id = 2, value = rand.int_range(0, 9)},
		worker2,
	)
	//----------------------------------------
	// wait for the threads to finish work
	thread.join(t1)
	thread.join(t2)

	// wait until internal counter reaches zero
	// sync.wait_group_wait(&wg)
	//----------------------------------------
	fmt.println("all workers finished")
	//----------------------------------------
}
//------------------------------------------------------------
