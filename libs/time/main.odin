#+feature dynamic-literals

package tb_time

// Copyright 2025, Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.

import "core:fmt"
import "core:math"
import "core:mem"
import vmem "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:reflect"
import "core:strings"
import "core:time"
import dt "core:time/datetime"

//------------------------------------------------------------

months: [13]string = {
	"Invalid Index",
	"Jan",
	"Feb",
	"Mar",
	"Apr",
	"May",
	"Jun",
	"Jul",
	"Aug",
	"Sep",
	"Oct",
	"Nov",
	"Dec",
}

MONTHS: [13]string = {
	"Invalid Index",
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December",
}

days: [8]string = {"Invalid Index", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}

DAYS: [8]string = {
	"Invalid Index",
	"Monday",
	"Tuesday",
	"Wednesday",
	"Thursday",
	"Friday",
	"Saturday",
	"Sunday",
}

dayNumbers: [13]int = {0, 1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335}

leapDayNumbers: [13]int = {0, 1, 32, 61, 92, 122, 153, 183, 214, 245, 275, 306, 336}

//------------------------------------------------------------

now :: proc() -> time.Time {return time.now()}

time_to_unix :: proc(tm: time.Time) -> i64 {return time.time_to_unix(tm)}

time_to_unix_nano :: proc(tm: time.Time) -> i64 {return time.time_to_unix_nano(tm)}

time_from_unix :: proc(seconds: i64) -> time.Time {
	return time.from_nanoseconds(seconds * 1_000_000_000)
}

time_from_unix_nano :: proc(nanoseconds: i64) -> time.Time {
	return time.from_nanoseconds(nanoseconds)
}

//------------------------------------------------------------

components_nano_to_time :: proc(
	#any_int year := i64(0),
	#any_int month := i64(0),
	#any_int day := i64(0),
	#any_int hour := i64(0),
	#any_int minute := i64(0),
	#any_int second := i64(0),
	#any_int nanoseconds := i64(0),
) -> (
	tm: time.Time,
	ok: bool,
) {
	// correct at time of writing (2025-04-02)
	// min(Time): 1677-09-21 00:12:44.145224192 +0000 UTC
	// max(Time): 2262-04-11 23:47:16.854775807 +0000 UTC
	datetime, err := dt.components_to_datetime(
		year,
		month > 0 ? month : 1,
		day > 0 ? day : 1,
		hour,
		minute,
		second,
		nanoseconds,
	)

	if err != .None {
		return
	}

	return time.compound_to_time(datetime)
}

new_time :: proc(
	#any_int year := i64(0),
	#any_int month := i64(0),
	#any_int day := i64(0),
	#any_int hour := i64(0),
	#any_int minute := i64(0),
	#any_int second := i64(0),
	#any_int nanoseconds := i64(0),
) -> (
	tm: time.Time,
) {

	tm, _ = components_nano_to_time(
		year,
		month > 0 ? month : 1,
		day > 0 ? day : 1,
		hour,
		minute,
		second,
		nanoseconds,
	)

	return tm
}

time_from_excel_datetime :: proc(excelDateTime: f64) -> time.Time {
	return time.from_nanoseconds(excel_datetime_unixtime(excelDateTime) * 1_000_000_000)
}

//------------------------------------------------------------

is_leap_year :: proc(timeValue: union {
		time.Time,
		int,
	}) -> bool {

	year: int

	switch _ in timeValue {
	case time.Time:
		year = time.year(timeValue.(time.Time))
	case int:
		year = timeValue.(int)
	}

	return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

is_dst :: proc(tm: time.Time) -> bool {

	year := time.year(tm)
	month := int(time.month(tm))
	day := time.day(tm)

	if (month < 3 || month > 10) {return false}
	if (month > 3 && month < 10) {return true}

	dow := dow(new_time(year, month, 31))
	lastDay := (dow == 7) ? 31 : 31 - dow

	return (month == 3) ? (day >= lastDay) ? true : false : (day < lastDay) ? true : false
}

//------------------------------------------------------------

cymd :: proc(tm: time.Time) -> int {
	return time.year(tm) * 1_00_00 + int(time.month(tm)) * 1_00 + time.day(tm)
}

ymd :: proc(tm: time.Time) -> int {
	return (time.year(tm) % 1_00 * 1_00_00) + int(time.month(tm)) * 1_00 + time.day(tm)
}

cy :: proc(tm: time.Time) -> int {return time.year(tm)}

y :: proc(tm: time.Time) -> int {return time.year(tm) % 1_00}

m :: proc(tm: time.Time) -> int {return int(time.month(tm))}

d :: proc(tm: time.Time) -> int {return time.day(tm)}

md :: proc(tm: time.Time) -> int {return int(time.month(tm)) * 1_00 + time.day(tm)}

dm :: proc(tm: time.Time) -> int {return time.day(tm) * 1_00 + int(time.month(tm))}

//------------------------------------------------------------

cyddd :: proc(tm: time.Time) -> int {
	return time.year(tm) * 1_000 + ddd(tm)
}

ddd :: proc(tm: time.Time) -> int {

	month := int(time.month(tm))

	if is_leap_year(tm) {
		return safe_array_value(leapDayNumbers, month) + time.day(tm) - 1
	} else {
		return safe_array_value(dayNumbers, month) + time.day(tm) - 1
	}
}

dow :: proc(timeValue: union {
		time.Time,
		time.Weekday,
		int,
	}) -> (dow: int) {

	switch _ in timeValue {
	case time.Time:
		dow = int(time.weekday(timeValue.(time.Time)))
	case time.Weekday:
		dow = int(timeValue.(time.Weekday))
	case int:
		dow = timeValue.(int)
	}

	return (dow <= 0 || dow > 7) ? 7 : dow
}

dowD :: proc(timeValue: union {
		time.Time,
		time.Weekday,
		int,
	}) -> string {

	return safe_array_value(days, dow(timeValue))
}

dowDD :: proc(timeValue: union {
		time.Time,
		time.Weekday,
		int,
	}) -> string {

	return safe_array_value(DAYS, dow(timeValue))
}

monthM :: proc(timeValue: union {
		time.Time,
		time.Month,
		int,
	}) -> string {

	month: int

	switch _ in timeValue {
	case time.Time:
		month = int(time.month(timeValue.(time.Time)))
	case time.Month:
		month = int(timeValue.(time.Month))
	case int:
		month = timeValue.(int)
	}

	return safe_array_value(months, month)
}

monthMM :: proc(timeValue: union {
		time.Time,
		time.Month,
		int,
	}) -> string {

	month: int

	switch _ in timeValue {
	case time.Time:
		month = int(time.month(timeValue.(time.Time)))
	case time.Month:
		month = int(timeValue.(time.Month))
	case int:
		month = timeValue.(int)
	}

	return safe_array_value(MONTHS, month)
}

//------------------------------------------------------------

iso_year :: proc(tm: time.Time) -> int {
	return int(cywk(tm) / 1_00)
}

cywk :: proc(tm: time.Time) -> int {

	year := time.year(tm)
	weekNumber := wk(tm)
	dayNumber := ddd(tm)

	if (dayNumber < 10 && weekNumber > 51) {
		year -= 1
	} else if (dayNumber > 350 && weekNumber < 2) {
		year += 1
	}

	return year * 100 + weekNumber
}

wk :: proc(tm: time.Time) -> int {

	year := time.year(tm)
	weekNumber := 0

	dayOfyear := ddd(tm)
	jan1Weekday := dow(new_time(year))
	weekDay := dow(tm)
	yearNumber := year

	if (dayOfyear <= (8 - jan1Weekday) && jan1Weekday > 4) {

		yearNumber = year - 1
		tmPrevious := new_time(yearNumber)

		if (jan1Weekday == 5 || (jan1Weekday == 6 && is_leap_year(tmPrevious))) {
			weekNumber = 53
		} else {
			weekNumber = 52
		}

	} else {

		daysInYear := is_leap_year(tm) ? 366 : 365

		if ((daysInYear - dayOfyear) < (4 - weekDay)) {

			yearNumber = year + 1
			weekNumber = 1

		} else {

			isoAdjustedDAYS := dayOfyear + (7 - weekDay) + (jan1Weekday - 1)
			weekNumber = int(isoAdjustedDAYS / 7)

			if (jan1Weekday > 4) {weekNumber -= 1}

		}
	}

	return weekNumber
}

q :: proc(timeValue: union {
		time.Time,
		time.Month,
		int,
	}) -> (month: int) {

	switch _ in timeValue {
	case time.Time:
		month = int(time.month(timeValue.(time.Time)))
	case time.Month:
		month = int(timeValue.(time.Month))
	case int:
		month = timeValue.(int)
	}

	if month >= 1 && month <= 3 {return 1}
	if month >= 4 && month <= 6 {return 2}
	if month >= 7 && month <= 9 {return 3}

	return 4
}

//------------------------------------------------------------

hhmmsszzz :: proc(tm: time.Time) -> int {
	hour, minute, second, nanosecond := time.precise_clock_from_time(tm)
	return hour * 1_00_00_000 + minute * 1_00_000 + second * 1_000 + int(nanosecond / 1_000_000)
}

hhmmss :: proc(tm: time.Time) -> int {
	hour, minute, second := time.clock_from_time(tm)
	return hour * 1_00_00 + minute * 1_00 + second
}

hhmm :: proc(tm: time.Time) -> int {
	hour, minute, _ := time.clock_from_time(tm)
	return hour * 1_00 + minute
}

hh :: proc(tm: time.Time) -> int {hour, _, _ := time.clock_from_time(tm);return hour}

mm :: proc(tm: time.Time) -> int {_, minute, _ := time.clock_from_time(tm);return minute}

ss :: proc(tm: time.Time) -> int {_, _, second := time.clock_from_time(tm);return second}

zzz :: proc(tm: time.Time) -> int {
	_, _, _, nanosecond := time.precise_clock_from_time(tm)
	return int(nanosecond / 1_000_000)
}

ms :: zzz

ns :: proc(tm: time.Time) -> int {
	_, _, _, nanosecond := time.precise_clock_from_time(tm)
	return nanosecond
}

//------------------------------------------------------------

utns :: proc(tm: time.Time) -> int {return int(time.time_to_unix_nano(tm))}

utms :: proc(tm: time.Time) -> int {return int(time.time_to_unix_nano(tm) / 1_000_000)}

ut :: proc(tm: time.Time) -> int {return int(time.time_to_unix(tm))}

//------------------------------------------------------------

hhmmss_seconds :: proc(hhmmss: int) -> int {
	hour := int(hhmmss / 1_00_00)
	minute := int((hhmmss - hour * 1_00_00) / 1_00)
	return hour * 3600 + minute * 60 + hhmmss - hour * 1_00_00 - minute * 1_00
}

seconds_hhmmss :: proc(seconds: int) -> int {
	hour := int(seconds / 3600)
	minute := int((seconds % 3600) / 60)
	return hour * 1_00_00 + minute * 1_00 + int(seconds % 3600) % 60
}

//------------------------------------------------------------

hhmm_mins :: proc(hhmm: int) -> int {
	hour := int(hhmm / 1_00)
	minute := hhmm - hour * 1_00
	return hour * 60 + minute
}

mins_hhmm :: proc(mins: int) -> int {
	hour := int(mins / 60)
	return hour * 1_00 + int(mins % 60)
}

//------------------------------------------------------------

excel_datetime :: proc(tm: time.Time) -> f64 {
	return f64(time.time_to_unix(tm)) / 86400 + 25569
}

excel_date :: proc(tm: time.Time) -> f64 {
	dateOnly, _ := components_nano_to_time(time.year(tm), int(time.month(tm)), time.day(tm))
	return f64(time.time_to_unix(dateOnly)) / 86400 + 25569
}

excel_date_cymd :: proc(excelDateTime: f64) -> int {
	excelDate := math.trunc_f64(excelDateTime)
	tm := time.from_nanoseconds(excel_datetime_unixtime(excelDate) * 1_000_000_000)
	return time.year(tm) * 1_00_00 + int(time.month(tm)) * 1_00 + time.day(tm)
}

cymd_excel_date :: proc(cymd: int) -> f64 {

	year := int(cymd / 1_00_00)
	month := int((cymd - year * 1_00_00) / 1_00)
	day := cymd - year * 1_00_00 - month * 1_00

	tm, ok := components_nano_to_time(year, month, day)
	if ok == false {return 0}

	return f64(time.time_to_unix(tm)) / 86400 + 25569
}

//------------------------------------------------------------

excel_time :: proc(tm: time.Time) -> f64 {
	hour, minute, second := time.clock_from_time(tm)
	return f64(hour * 3600 + minute * 60 + second) / 86400
}

excel_time_hhmmss :: proc(excelDateTime: f64) -> int {

	excelTime := excelDateTime - math.trunc_f64(excelDateTime)

	seconds := int(math.round(excelTime * 86400))
	hour := seconds / 3600
	minute := (seconds % 3600) / 60

	return hour * 10_000 + minute * 1_00 + int(seconds % 3600) % 60
}

hhmmss_excel_time :: proc(hhmmss: int) -> f64 {

	hour := int(hhmmss / 1_00_00)
	minute := int((hhmmss - hour * 1_00_00) / 1_00)
	second := hhmmss - hour * 1_00_00 - minute * 1_00

	return f64(hour * 3600 + minute * 60 + second) / 86400
}

//------------------------------------------------------------

excel_datetime_unixtime :: proc(excelDateTime: f64) -> i64 {
	return i64(math.round((excelDateTime - 25569) * 86400))
}

unixtime_excel_datetime :: proc(ut: i64) -> f64 {
	return f64(ut) / 86400 + 25569
}

//------------------------------------------------------------

format :: proc(allocator: mem.Allocator, tm: time.Time, template: string) -> string {

	output := template

	/*
		replacements in a set order to avoid template clashes
	*/

	output, _ = strings.replace_all(output, "utms", fmt.tprintf("%013d", utms(tm)), allocator)
	output, _ = strings.replace_all(output, "ut", fmt.tprintf("%010d", ut(tm)), allocator)
	output, _ = strings.replace_all(output, "ddd", fmt.tprintf("%03d", ddd(tm)), allocator)
	output, _ = strings.replace_all(output, "hh", fmt.tprintf("%02d", hh(tm)), allocator)
	output, _ = strings.replace_all(output, "mm", fmt.tprintf("%02d", mm(tm)), allocator)
	output, _ = strings.replace_all(output, "ss", fmt.tprintf("%02d", ss(tm)), allocator)
	output, _ = strings.replace_all(output, "zzz", fmt.tprintf("%03d", zzz(tm)), allocator)
	output, _ = strings.replace_all(output, "DST", is_dst(tm) ? "@1" : "", allocator)
	output, _ = strings.replace_all(output, "cywk", fmt.tprintf("%06d", cywk(tm)), allocator)
	output, _ = strings.replace_all(output, "wk", fmt.tprintf("%02d", wk(tm)), allocator)
	output, _ = strings.replace_all(output, "CY", fmt.tprintf("%04d", iso_year(tm)), allocator)
	output, _ = strings.replace_all(output, "cy", fmt.tprintf("%04d", cy(tm)), allocator)
	output, _ = strings.replace_all(output, "y", fmt.tprintf("%02d", y(tm)), allocator)
	output, _ = strings.replace_all(output, "m", fmt.tprintf("%02d", m(tm)), allocator)
	output, _ = strings.replace_all(output, "d", fmt.tprintf("%02d", d(tm)), allocator)
	output, _ = strings.replace_all(output, "MM", "@2", allocator)
	output, _ = strings.replace_all(output, "M", "@3", allocator)
	output, _ = strings.replace_all(output, "DD", dowDD(tm), allocator)
	output, _ = strings.replace_all(output, "D", dowD(tm), allocator)
	output, _ = strings.replace_all(output, "q", fmt.tprintf("%01d", q(tm)), allocator)

	output, _ = strings.replace_all(output, "@1", "DST", allocator)
	output, _ = strings.replace_all(output, "@2", monthMM(tm), allocator)
	output, _ = strings.replace_all(output, "@3", monthM(tm), allocator)

	return output
}

//------------------------------------------------------------

safe_array_value :: proc(array: [$N]$T, index := int(0)) -> T {
	return index >= 0 && index < N ? array[index] : T{}
}

//------------------------------------------------------------

main :: proc() {
	fmt.printfln("%s: main function", filepath.base(os.args[0]))
}

//------------------------------------------------------------
