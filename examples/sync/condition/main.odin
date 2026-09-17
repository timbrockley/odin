
//------------------------------------------------------------

package main

import "core:fmt"
import "core:sync"
import "core:thread"
import "core:time"

//------------------------------------------------------------
TESTS :: 5
//------------------------------------------------------------
mutex: sync.Mutex
cond: sync.Cond
//------------------------------------------------------------
generation: int = 0
done: bool = false
//------------------------------------------------------------
main :: proc() {
	//------------------------------------------------------------
	fmt.println("main is running")

	t := thread.create(worker)
	thread.start(t)

	for i in 1 ..= TESTS {
		time.sleep(500 * time.Millisecond)

		sync.mutex_lock(&mutex)
		generation += 1
		fmt.printf("main fired event %d\n", generation)
		sync.cond_broadcast(&cond)
		sync.mutex_unlock(&mutex)
	}

	sync.mutex_lock(&mutex)
	done = true
	sync.cond_broadcast(&cond)
	sync.mutex_unlock(&mutex)

	thread.join(t)
	//------------------------------------------------------------
}
//------------------------------------------------------------
worker :: proc(t: ^thread.Thread) {
	//------------------------------------------------------------
	last_generation := 0
	//------------------------------------------------------------
	for {
		//------------------------------------------------------------
		sync.mutex_lock(&mutex)
		//------------------------------------------------------------
		for generation == last_generation && !done {
			sync.cond_wait(&cond, &mutex)
		}
		//------------------------------------------------------------
		if (generation != last_generation) {
			//------------------------------------------------------------
			fmt.printf("worker received event %d\n", generation)
			//------------------------------------------------------------
			last_generation = generation
			sync.mutex_unlock(&mutex)
			//------------------------------------------------------------
			continue
			//------------------------------------------------------------
		}
		//------------------------------------------------------------
		if done {
			sync.mutex_unlock(&mutex)
			break
		}
		//------------------------------------------------------------
		sync.mutex_unlock(&mutex)
		//------------------------------------------------------------
	}
	//------------------------------------------------------------
	fmt.println("worker exiting")
	//------------------------------------------------------------
}
//------------------------------------------------------------
