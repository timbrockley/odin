
//------------------------------------------------------------

package main

import "core:fmt"
import "core:sync/chan"
import "core:thread"
import "core:time"

//--------------------------------------------------------------------------------
// The producer sends count number of messages.
producer :: proc(send_chan: chan.Chan(int, .Send), count: int) {
	//------------------------------------------------------------
	for id in 1 ..= count {
		fmt.println("[PRODUCER] Sending:", id)
		success := chan.send(send_chan, id)
		if !success {
			fmt.println("[PRODUCER] Failed to send, channel may be closed.")
			return
		}
	}
	//------------------------------------------------------------
	// Signal that production is complete by closing the channel.
	chan.close(send_chan)
	fmt.println("[PRODUCER] Done producing, channel closed.")
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
// The consumer reads from the channel until it's closed.
// Closing the channel acts as a signal to stop.
consumer :: proc(recv_chan: chan.Chan(int, .Recv)) {
	//------------------------------------------------------------
	for {
		time.sleep(500 * time.Millisecond)
		value, ok := chan.recv(recv_chan)
		if !ok {
			break
		}
		fmt.println("[CONSUMER] Received:", value)
	}
	fmt.println("[CONSUMER] Channel closed, stopping.")
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
main :: proc() {
	//------------------------------------------------------------
	// Create an unbuffered channel for int messages
	c, err := chan.create(chan.Chan(int), context.allocator)
	assert(err == .None)
	defer chan.destroy(c)
	//------------------------------------------------------------
	// Start the consumer thread
	consumer_thread := thread.create_and_start_with_poly_data(chan.as_recv(c), consumer)
	defer thread.destroy(consumer_thread)
	//------------------------------------------------------------
	// Start the producer thread with 5 messages (change count as needed)
	producer_thread := thread.create_and_start_with_poly_data2(chan.as_send(c), 5, producer)
	defer thread.destroy(producer_thread)
	//------------------------------------------------------------
	// Wait for both threads to complete
	thread.join_multiple(consumer_thread, producer_thread)
	//------------------------------------------------------------
}
//--------------------------------------------------------------------------------
