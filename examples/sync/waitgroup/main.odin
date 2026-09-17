//------------------------------------------------------------

package main

import "core:fmt"
import "core:math/rand"
import "core:sync"
import "core:thread"

//------------------------------------------------------------
mutex: sync.Mutex
sum: int
//------------------------------------------------------------
WorkerData :: struct {
	wg:    ^sync.Wait_Group,
	id:    int,
	value: int,
}
//------------------------------------------------------------
worker :: proc(t: ^thread.Thread) {
	//------------------------------------------------------------
	data := cast(^WorkerData)t.data
	//------------------------------------------------------------
	defer sync.wait_group_done(data.wg)
	//------------------------------------------------------------
	sync.lock(&mutex)
	defer sync.unlock(&mutex)
	//------------------------------------------------------------
	sum += data.value
	//------------------------------------------------------------
	fmt.printfln("thread %d, value = %d, sum = %d", data.id, data.value, sum)
	//------------------------------------------------------------
}
//------------------------------------------------------------
main :: proc() {
	//------------------------------------------------------------
	wg: sync.Wait_Group
	//------------------------------------------------------------
	sync.wait_group_add(&wg, 2)
	//------------------------------------------------------------
	t1 := thread.create(worker)
	t1.data = &WorkerData{wg = &wg, id = 1, value = rand.int_range(1, 9)}
	//------------------------------------------------------------
	t2 := thread.create(worker)
	t2.data = &WorkerData{wg = &wg, id = 2, value = rand.int_range(1, 9)}
	//------------------------------------------------------------
	thread.start(t1)
	thread.start(t2)
	//------------------------------------------------------------
	// wait for the threads to finish work
	// thread.join(t1)
	// thread.join(t2)

	// wait until internal counter reaches zero
	sync.wait_group_wait(&wg)
	//------------------------------------------------------------
	fmt.println("all workers finished")
	//------------------------------------------------------------
}
//------------------------------------------------------------
