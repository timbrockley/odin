//------------------------------------------------------------

package main

import "core:fmt"
import "core:sync"
import "core:thread"
import "core:time"

//------------------------------------------------------------
THREAD_COUNT :: 4
//------------------------------------------------------------
barrier: sync.Barrier
//------------------------------------------------------------
worker :: proc(t: ^thread.Thread) {
	//------------------------------------------------------------
	fmt.printf("Worker %d: stage 1\n", t.id)

	time.sleep(10 * time.Millisecond)

	fmt.printf("Worker %d: waiting\n", t.id)

	leader := sync.barrier_wait(&barrier)

	if leader {
		fmt.println("=== Everyone reached the barrier ===")
	}

	fmt.printf("Worker %d: stage 2\n", t.id)

	time.sleep(50 * time.Millisecond)

	leader = sync.barrier_wait(&barrier)

	if leader {
		fmt.println("=== All workers finished ===")
	}

	fmt.printf("Worker %d: done\n", t.id)
	//------------------------------------------------------------
}
//------------------------------------------------------------
main :: proc() {
	//------------------------------------------------------------
	sync.barrier_init(&barrier, THREAD_COUNT)

	threads: [THREAD_COUNT]^thread.Thread

	for i in 0 ..< THREAD_COUNT {
		threads[i] = thread.create(worker)
		thread.start(threads[i])
	}

	for t in threads {
		thread.join(t)
	}
	//------------------------------------------------------------
}
//------------------------------------------------------------
