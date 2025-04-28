package main

import "core:fmt"
import "core:time"

main :: proc() {
	//----------------------------------------
	now := time.now()
	//----------------------------------------
	fmt.printfln(
		"Date: %s %02d %s %04d",
		time.weekday(now),
		time.day(now),
		time.Month(time.month(now)),
		time.year(now),
	)
	//----------------------------------------
	hour, minute, second := time.clock_from_time(now)
	fmt.printfln("Time: %02d:%02d:%02d", hour, minute, second)
	//----------------------------------------
	// buf: [time.MIN_HMS_LEN]u8
	// fmt.println("Time:", time.to_string_hms(now, buf[:]))
	//----------------------------------------
}
