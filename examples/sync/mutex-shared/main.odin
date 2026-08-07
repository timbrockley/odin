//------------------------------------------------------------

package main

import "core:fmt"
import "core:sync"
import "core:thread"
import "core:time"

//------------------------------------------------------------
rw_mutex: sync.RW_Mutex
value: int = 100
//------------------------------------------------------------
reader :: proc(t: ^thread.Thread) {
	//------------------------------------------------------------
	sync.rw_mutex_shared_lock(&rw_mutex)
	defer sync.rw_mutex_shared_unlock(&rw_mutex)

	fmt.printfln("reader %d started, value = %d", t.id, value)

	time.sleep(2 * time.Second)

	fmt.printfln("reader %d finished", t.id)
	//------------------------------------------------------------
}
//------------------------------------------------------------
writer :: proc(t: ^thread.Thread) {
	//------------------------------------------------------------
	sync.rw_mutex_lock(&rw_mutex)
	defer sync.rw_mutex_unlock(&rw_mutex)

	fmt.printfln("writer started, changing value")

	value = 200

	time.sleep(500 * time.Millisecond)

	fmt.printfln("writer finished, value = %d", value)
	//------------------------------------------------------------
}
//------------------------------------------------------------
main :: proc() {
	//------------------------------------------------------------
	r1 := thread.create(reader)
	r2 := thread.create(reader)
	r3 := thread.create(reader)

	w := thread.create(writer)

	thread.start(r1)
	thread.start(r2)
	thread.start(r3)

	time.sleep(200 * time.Millisecond)

	thread.start(w)

	thread.join(r1)
	thread.join(r2)
	thread.join(r3)
	thread.join(w)
	//------------------------------------------------------------
}
//------------------------------------------------------------
