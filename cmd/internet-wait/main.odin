package main

//------------------------------------------------------------
// Copyright 2026 Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//------------------------------------------------------------

import "core:fmt"
import "core:net"
import "core:time"

//----------------------------------------
ADDRESS := net.IP4_Address{1, 1, 1, 1}
PORT := 53
//----------------------------------------
MAX_BAR_LEN :: 10
DURATION :: 100 * time.Millisecond // milliseconds
CR_CLEARLINE :: "\r\x1b[2K"
//----------------------------------------
main :: proc() {
	//----------------------------------------
	bar_len := 0
	//----------------------------------------
	bar_index: int = 0
	bar: [MAX_BAR_LEN]u8
	//----------------------------------------
	for !connected() {
		//----------------------------------------
		bar_len += 1
		if bar_len > MAX_BAR_LEN {
			bar_len = 1
		}
		//----------------------------------------
		fmt.print("\rWaiting for internet connection")
		//----------------------------------------
		fillBar(&bar, bar_index)
		fmt.printf(" [%s]", bar)
		//----------------------------------------
		bar_index = (bar_index < MAX_BAR_LEN) ? bar_index + 1 : 1
		//----------------------------------------
		time.sleep(DURATION)
		//----------------------------------------
	}
	//----------------------------------------
	fmt.printf("%s", CR_CLEARLINE)
	//----------------------------------------
}
//----------------------------------------
fillBar :: proc(bar: ^[MAX_BAR_LEN]u8, bar_index: int) {
	//----------------------------------------
	index := (bar_index < MAX_BAR_LEN) ? bar_index : MAX_BAR_LEN
	//----------------------------------------
	for i in 0 ..< index {
		bar^[i] = '.'
	}
	//----------------------------------------
	for i in index ..< MAX_BAR_LEN {
		bar^[i] = ' '
	}
	//----------------------------------------
}
//----------------------------------------
connected :: proc() -> bool {
	//----------------------------------------
	tcp_socket, err := net.dial_tcp_from_address_and_port(ADDRESS, PORT)
	//----------------------------------------
	if err != nil {return false}
	//----------------------------------------
	defer net.close(tcp_socket)
	return true
	//----------------------------------------
}
//----------------------------------------
