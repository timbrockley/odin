package main

//------------------------------------------------------------
// Copyright 2025 Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//------------------------------------------------------------

import "core:fmt"
import "core:net"
import "core:os"

ADDRESS := net.IP4_Address{1, 1, 1, 1}
PORT := 53

main :: proc() {
	//----------------------------------------
	tcp_socket, err := net.dial_tcp_from_address_and_port(ADDRESS, PORT)
	//----------------------------------------
	if err != nil {os.exit(1)}
	//----------------------------------------
	net.close(tcp_socket)
	os.exit(0)
	//----------------------------------------
}
