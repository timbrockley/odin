package main

//------------------------------------------------------------
// Copyright 2025 Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//------------------------------------------------------------

import "core:fmt"
import "core:net"
import "core:os"
import "core:strings"
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
	for !connected() {
		//----------------------------------------
		bar_len += 1
		if bar_len > MAX_BAR_LEN {
			bar_len = 1
		}
		//----------------------------------------
		fmt.print("\rWaiting for internet connection")
		fmt.printf(" [%-*s]", MAX_BAR_LEN, strings.repeat(".", bar_len))
		//----------------------------------------
		time.sleep(DURATION)
		//----------------------------------------
	}
	//----------------------------------------
	fmt.printf("%s", CR_CLEARLINE)
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
