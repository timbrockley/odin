#+feature dynamic-literals

package tb_time

//------------------------------------------------------------
// Copyright 2025, Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//------------------------------------------------------------

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

DAY_NUMBERS: [13]int = {0, 1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335}

LEAP_YEAR_DAY_NUMBERS: [13]int = {0, 1, 32, 61, 92, 122, 153, 183, 214, 245, 275, 306, 336}

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

componentsToTime :: proc(
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

newTime :: proc(
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

	tm, _ = componentsToTime(
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

timeFromExcelDateTime :: proc(excel_datetime: f64) -> time.Time {
	return time.from_nanoseconds(excelDateTime_to_unixtime(excel_datetime) * 1_000_000_000)
}

//------------------------------------------------------------

isLeapYear :: proc(time_value: union {
		time.Time,
		int,
	}) -> bool {

	year: int

	switch _ in time_value {
	case time.Time:
		year = time.year(time_value.(time.Time))
	case int:
		year = time_value.(int)
	}

	return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

isDST :: proc(tm: time.Time) -> bool {

	year := time.year(tm)
	month := int(time.month(tm))
	day := time.day(tm)

	if (month < 3 || month > 10) {return false}
	if (month > 3 && month < 10) {return true}

	dow := dow(newTime(year, month, 31))
	last_day := (dow == 7) ? 31 : 31 - dow

	return (month == 3) ? (day >= last_day) ? true : false : (day < last_day) ? true : false
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

	if isLeapYear(tm) {
		return safeArrayValue(LEAP_YEAR_DAY_NUMBERS, month) + time.day(tm) - 1
	} else {
		return safeArrayValue(DAY_NUMBERS, month) + time.day(tm) - 1
	}
}

dow :: proc(time_value: union {
		time.Time,
		time.Weekday,
		int,
	}) -> (dow: int) {

	switch _ in time_value {
	case time.Time:
		dow = int(time.weekday(time_value.(time.Time)))
	case time.Weekday:
		dow = int(time_value.(time.Weekday))
	case int:
		dow = time_value.(int)
	}

	return (dow <= 0 || dow > 7) ? 7 : dow
}

dowD :: proc(time_value: union {
		time.Time,
		time.Weekday,
		int,
	}) -> string {

	return safeArrayValue(days, dow(time_value))
}

dowDD :: proc(time_value: union {
		time.Time,
		time.Weekday,
		int,
	}) -> string {

	return safeArrayValue(DAYS, dow(time_value))
}

monthM :: proc(time_value: union {
		time.Time,
		time.Month,
		int,
	}) -> string {

	month: int

	switch _ in time_value {
	case time.Time:
		month = int(time.month(time_value.(time.Time)))
	case time.Month:
		month = int(time_value.(time.Month))
	case int:
		month = time_value.(int)
	}

	return safeArrayValue(months, month)
}

monthMM :: proc(time_value: union {
		time.Time,
		time.Month,
		int,
	}) -> string {

	month: int

	switch _ in time_value {
	case time.Time:
		month = int(time.month(time_value.(time.Time)))
	case time.Month:
		month = int(time_value.(time.Month))
	case int:
		month = time_value.(int)
	}

	return safeArrayValue(MONTHS, month)
}

//------------------------------------------------------------

isoYear :: proc(tm: time.Time) -> int {
	return int(cywk(tm) / 1_00)
}

cywk :: proc(tm: time.Time) -> int {

	year := time.year(tm)
	week_number := wk(tm)
	day_number := ddd(tm)

	if (day_number < 10 && week_number > 51) {
		year -= 1
	} else if (day_number > 350 && week_number < 2) {
		year += 1
	}

	return year * 100 + week_number
}

wk :: proc(tm: time.Time) -> int {

	year := time.year(tm)
	week_number := 0

	day_of_year := ddd(tm)
	jan1_weekday := dow(newTime(year))
	week_day := dow(tm)
	year_number := year

	if (day_of_year <= (8 - jan1_weekday) && jan1_weekday > 4) {

		year_number = year - 1
		tm_previous := newTime(year_number)

		if (jan1_weekday == 5 || (jan1_weekday == 6 && isLeapYear(tm_previous))) {
			week_number = 53
		} else {
			week_number = 52
		}

	} else {

		days_in_year := isLeapYear(tm) ? 366 : 365

		if ((days_in_year - day_of_year) < (4 - week_day)) {

			year_number = year + 1
			week_number = 1

		} else {

			iso_adjusted_days := day_of_year + (7 - week_day) + (jan1_weekday - 1)
			week_number = int(iso_adjusted_days / 7)

			if (jan1_weekday > 4) {week_number -= 1}

		}
	}

	return week_number
}

q :: proc(time_value: union {
		time.Time,
		time.Month,
		int,
	}) -> (month: int) {

	switch _ in time_value {
	case time.Time:
		month = int(time.month(time_value.(time.Time)))
	case time.Month:
		month = int(time_value.(time.Month))
	case int:
		month = time_value.(int)
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

hhmmss_to_seconds :: proc(hhmmss: int) -> int {
	hour := int(hhmmss / 1_00_00)
	minute := int((hhmmss - hour * 1_00_00) / 1_00)
	return hour * 3600 + minute * 60 + hhmmss - hour * 1_00_00 - minute * 1_00
}

seconds_to_hhmmss :: proc(seconds: int) -> int {
	hour := int(seconds / 3600)
	minute := int((seconds % 3600) / 60)
	return hour * 1_00_00 + minute * 1_00 + int(seconds % 3600) % 60
}

//------------------------------------------------------------

hhmm_to_mins :: proc(hhmm: int) -> int {
	hour := int(hhmm / 1_00)
	minute := hhmm - hour * 1_00
	return hour * 60 + minute
}

mins_to_hhmm :: proc(mins: int) -> int {
	hour := int(mins / 60)
	return hour * 1_00 + int(mins % 60)
}

//------------------------------------------------------------

excelDateTime :: proc(tm: time.Time) -> f64 {
	return f64(time.time_to_unix(tm)) / 86400 + 25569
}

excelDate :: proc(tm: time.Time) -> f64 {
	date_only, _ := componentsToTime(time.year(tm), int(time.month(tm)), time.day(tm))
	return f64(time.time_to_unix(date_only)) / 86400 + 25569
}

excelDate_to_cymd :: proc(excel_datetime: f64) -> int {
	excel_date := math.trunc_f64(excel_datetime)
	tm := time.from_nanoseconds(excelDateTime_to_unixtime(excel_date) * 1_000_000_000)
	return time.year(tm) * 1_00_00 + int(time.month(tm)) * 1_00 + time.day(tm)
}

cymd_to_excelDate :: proc(cymd: int) -> f64 {

	year := int(cymd / 1_00_00)
	month := int((cymd - year * 1_00_00) / 1_00)
	day := cymd - year * 1_00_00 - month * 1_00

	tm, ok := componentsToTime(year, month, day)
	if ok == false {return 0}

	return f64(time.time_to_unix(tm)) / 86400 + 25569
}

//------------------------------------------------------------

excelTime :: proc(tm: time.Time) -> f64 {
	hour, minute, second := time.clock_from_time(tm)
	return f64(hour * 3600 + minute * 60 + second) / 86400
}

excelTime_to_hhmmss :: proc(excel_datetime: f64) -> int {

	excelTime := excel_datetime - math.trunc_f64(excel_datetime)

	seconds := int(math.round(excelTime * 86400))
	hour := seconds / 3600
	minute := (seconds % 3600) / 60

	return hour * 10_000 + minute * 1_00 + int(seconds % 3600) % 60
}

hhmmss_to_excelTime :: proc(hhmmss: int) -> f64 {

	hour := int(hhmmss / 1_00_00)
	minute := int((hhmmss - hour * 1_00_00) / 1_00)
	second := hhmmss - hour * 1_00_00 - minute * 1_00

	return f64(hour * 3600 + minute * 60 + second) / 86400
}

//------------------------------------------------------------

excelDateTime_to_unixtime :: proc(excel_datetime: f64) -> i64 {
	return i64(math.round((excel_datetime - 25569) * 86400))
}

unixtime_to_excelDateTime :: proc(ut: i64) -> f64 {
	return f64(ut) / 86400 + 25569
}

//------------------------------------------------------------

format :: proc(
	tm: time.Time,
	template: string,
	allocator: mem.Allocator = context.allocator,
) -> string {

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
	output, _ = strings.replace_all(output, "DST", isDST(tm) ? "@1" : "", allocator)
	output, _ = strings.replace_all(output, "cywk", fmt.tprintf("%06d", cywk(tm)), allocator)
	output, _ = strings.replace_all(output, "wk", fmt.tprintf("%02d", wk(tm)), allocator)
	output, _ = strings.replace_all(output, "CY", fmt.tprintf("%04d", isoYear(tm)), allocator)
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

safeArrayValue :: proc(array: [$N]$T, index := int(0)) -> T {
	return index >= 0 && index < N ? array[index] : T{}
}

//------------------------------------------------------------

main :: proc() {
	fmt.printfln("%s: main function", filepath.base(os.args[0]))
}

//------------------------------------------------------------
