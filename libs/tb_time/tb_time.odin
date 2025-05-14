package tb_time

//------------------------------------------------------------
// Copyright 2025, Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//------------------------------------------------------------

import "core:bytes"
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

//------------------------------------------------------------

excelDateTime_to_unixtime :: proc(excel_datetime: f64) -> i64 {
	return i64(math.round((excel_datetime - 25569) * 86400))
}

unixtime_to_excelDateTime :: proc(ut: i64) -> f64 {
	return f64(ut) / 86400 + 25569
}

//------------------------------------------------------------

excelDateTime_to_time :: proc(excel_datetime: f64) -> time.Time {
	return time.from_nanoseconds(excelDateTime_to_unixtime(excel_datetime) * 1_000_000_000)
}

time_to_excelDateTime :: proc(tm: time.Time) -> f64 {
	return f64(time.time_to_unix(tm)) / 86400 + 25569
}

//------------------------------------------------------------

excelDate_to_time :: proc(excel_datetime: f64) -> time.Time {
	excel_date := math.floor(excel_datetime)
	return time.from_nanoseconds(excelDateTime_to_unixtime(excel_date) * 1_000_000_000)
}

time_to_excelDate :: proc(tm: time.Time) -> f64 {
	date_only, _ := componentsToTime(time.year(tm), int(time.month(tm)), time.day(tm))
	return f64(time.time_to_unix(date_only)) / 86400 + 25569
}

//------------------------------------------------------------

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

time_to_excelTime :: proc(tm: time.Time) -> f64 {
	hour, minute, second := time.clock_from_time(tm)
	return f64(hour * 3600 + minute * 60 + second) / 86400
}

//------------------------------------------------------------

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
	last_sunday := (dow == 7) ? 31 : 31 - dow

	if (month == 3) {
		return day >= last_sunday
	} else {
		return day < last_sunday
	}
}

//------------------------------------------------------------

utns :: proc(tm: time.Time) -> int {return int(time.time_to_unix_nano(tm))}

utms :: proc(tm: time.Time) -> int {return int(time.time_to_unix_nano(tm) / 1_000_000)}

ut :: proc(tm: time.Time) -> int {return int(time.time_to_unix(tm))}

//------------------------------------------------------------

cymd :: proc(tm: time.Time) -> int {
	return time.year(tm) * 1_00_00 + int(time.month(tm)) * 1_00 + time.day(tm)
}

ymd :: proc(tm: time.Time) -> int {
	return (time.year(tm) % 1_00 * 1_00_00) + int(time.month(tm)) * 1_00 + time.day(tm)
}

cy :: proc(tm: time.Time) -> int {return time.year(tm)}

c :: proc(tm: time.Time) -> int {return time.year(tm) / 1_00}

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
	//---------------------------------------
	month := int(time.month(tm))
	//---------------------------------------
	day_number: int
	//---------------------------------------
	switch month {
	case 1:
		day_number = 1
	case 2:
		day_number = 32
	case 3:
		day_number = 60
	case 4:
		day_number = 91
	case 5:
		day_number = 121
	case 6:
		day_number = 152
	case 7:
		day_number = 182
	case 8:
		day_number = 213
	case 9:
		day_number = 244
	case 10:
		day_number = 274
	case 11:
		day_number = 305
	case 12:
		day_number = 335
	case:
		day_number = 0
	}
	//---------------------------------------
	if isLeapYear(tm) && month >= 3 {
		return day_number + time.day(tm)
	} else {
		return day_number + time.day(tm) - 1
	}
	//---------------------------------------
}

dow :: proc(time_value: union {
		time.Time,
		time.Weekday,
		int,
	}) -> (dow: int) {
	//---------------------------------------
	switch _ in time_value {
	case time.Time:
		dow = int(time.weekday(time_value.(time.Time)))
	case time.Weekday:
		dow = int(time_value.(time.Weekday))
	case int:
		dow = time_value.(int)
	}
	//---------------------------------------
	return (dow <= 0 || dow > 7) ? 7 : dow
	//---------------------------------------
}

dowD :: proc(time_value: union {
		time.Time,
		time.Weekday,
		int,
	}) -> string {
	//---------------------------------------
	switch dow(time_value) {
	case 1:
		return "Mon"
	case 2:
		return "Tue"
	case 3:
		return "Wed"
	case 4:
		return "Thu"
	case 5:
		return "Fri"
	case 6:
		return "Sat"
	case 7:
		return "Sun"
	case:
		return ""
	}
	//---------------------------------------
}

dowDD :: proc(time_value: union {
		time.Time,
		time.Weekday,
		int,
	}) -> string {
	//---------------------------------------
	switch dow(time_value) {
	case 1:
		return "Monday"
	case 2:
		return "Tuesday"
	case 3:
		return "Wednesday"
	case 4:
		return "Thursday"
	case 5:
		return "Friday"
	case 6:
		return "Saturday"
	case 7:
		return "Sunday"
	case:
		return ""
	}
	//---------------------------------------
}

monthM :: proc(time_value: union {
		time.Time,
		time.Month,
		int,
	}) -> string {
	//---------------------------------------
	month: int
	//---------------------------------------
	switch _ in time_value {
	case time.Time:
		month = int(time.month(time_value.(time.Time)))
	case time.Month:
		month = int(time_value.(time.Month))
	case int:
		month = time_value.(int)
	}
	//---------------------------------------
	switch month {
	case 1:
		return "Jan"
	case 2:
		return "Feb"
	case 3:
		return "Mar"
	case 4:
		return "Apr"
	case 5:
		return "May"
	case 6:
		return "Jun"
	case 7:
		return "Jul"
	case 8:
		return "Aug"
	case 9:
		return "Sep"
	case 10:
		return "Oct"
	case 11:
		return "Nov"
	case 12:
		return "Dec"
	case:
		return ""
	}
	//---------------------------------------
}

monthMM :: proc(time_value: union {
		time.Time,
		time.Month,
		int,
	}) -> string {
	//---------------------------------------
	month: int
	//---------------------------------------
	switch _ in time_value {
	case time.Time:
		month = int(time.month(time_value.(time.Time)))
	case time.Month:
		month = int(time_value.(time.Month))
	case int:
		month = time_value.(int)
	}
	//---------------------------------------
	switch month {
	case 1:
		return "January"
	case 2:
		return "February"
	case 3:
		return "March"
	case 4:
		return "April"
	case 5:
		return "May"
	case 6:
		return "June"
	case 7:
		return "July"
	case 8:
		return "August"
	case 9:
		return "September"
	case 10:
		return "October"
	case 11:
		return "November"
	case 12:
		return "December"
	case:
		return ""
	}
	//---------------------------------------
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
	//---------------------------------------
	year := time.year(tm)
	week_number := 0
	//---------------------------------------
	day_of_year := ddd(tm)
	jan1_weekday := dow(newTime(year, 1, 1))
	week_day := dow(tm)
	year_number := year
	//---------------------------------------
	if (day_of_year <= (8 - jan1_weekday) && jan1_weekday > 4) {
		//---------------------------------------
		year_number = year - 1
		tm_previous := newTime(year_number, 1, 1)
		//---------------------------------------
		if (jan1_weekday == 5 || (jan1_weekday == 6 && isLeapYear(tm_previous))) {
			week_number = 53
		} else {
			week_number = 52
		}
		//---------------------------------------
	} else {
		//---------------------------------------
		days_in_year := isLeapYear(tm) ? 366 : 365
		//---------------------------------------
		if ((days_in_year - day_of_year) < (4 - week_day)) {
			//---------------------------------------
			year_number = year + 1
			week_number = 1
			//---------------------------------------
		} else {
			//---------------------------------------
			iso_adjusted_days := day_of_year + (7 - week_day) + (jan1_weekday - 1)
			week_number = int(iso_adjusted_days / 7)
			//---------------------------------------
			if (jan1_weekday > 4) {week_number -= 1}
			//---------------------------------------
		}
		//---------------------------------------
	}
	//---------------------------------------
	return week_number
	//---------------------------------------
}

q :: proc(time_value: union {
		time.Time,
		time.Month,
		int,
	}) -> (month: int) {
	//---------------------------------------
	switch _ in time_value {
	case time.Time:
		month = int(time.month(time_value.(time.Time)))
	case time.Month:
		month = int(time_value.(time.Month))
	case int:
		month = time_value.(int)
	}
	//---------------------------------------
	if month >= 1 && month <= 3 {return 1}
	if month >= 4 && month <= 6 {return 2}
	if month >= 7 && month <= 9 {return 3}
	//---------------------------------------
	return 4
	//---------------------------------------
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

processToken :: proc(
	token: string,
	value: string,
	template: string,
	template_index: ^int,
	buffer: ^strings.Builder,
) -> bool {
	//---------------------------------------
	if len(token) == 0 {return false}
	if template_index^ >= len(template) {return false}
	if template_index^ + len(token) > len(template) {return false}
	//---------------------------------------
	substring, ok := strings.substring(template, template_index^, template_index^ + len(token))
	//---------------------------------------
	if ok && substring == token {
		//---------------------------------------
		strings.write_string(buffer, value)
		//---------------------------------------
		template_index^ += len(token)
		//---------------------------------------
		return true
		//---------------------------------------
	}
	//---------------------------------------
	return false
	//---------------------------------------
}

format :: proc(
	template: string,
	tm: time.Time,
	allocator: mem.Allocator = context.allocator,
) -> string {
	//---------------------------------------
	buffer := strings.builder_make(allocator)
	defer strings.builder_destroy(&buffer)
	//---------------------------------------
	template_index: int = 0
	for template_index < len(template) {
		//---------------------------------------
		if processToken(
			"utms",
			fmt.tprint(utms(tm)),
			template,
			&template_index,
			&buffer,
		) {continue}
		//---------------------------------------
		if processToken("ut", fmt.tprint(ut(tm)), template, &template_index, &buffer) {continue}
		//---------------------------------------
		if processToken(
			"ddd",
			fmt.tprintf("%03d", ddd(tm)),
			template,
			&template_index,
			&buffer,
		) {continue}
		//---------------------------------------
		if processToken(
			"hh",
			fmt.tprintf("%02d", hh(tm)),
			template,
			&template_index,
			&buffer,
		) {continue}
		//---------------------------------------
		if processToken(
			"mm",
			fmt.tprintf("%02d", mm(tm)),
			template,
			&template_index,
			&buffer,
		) {continue}
		//---------------------------------------
		if processToken(
			"ss",
			fmt.tprintf("%02d", ss(tm)),
			template,
			&template_index,
			&buffer,
		) {continue}
		//---------------------------------------
		if processToken(
			"zzz",
			fmt.tprintf("%03d", zzz(tm)),
			template,
			&template_index,
			&buffer,
		) {continue}
		//---------------------------------------
		if processToken(
			"DST",
			isDST(tm) ? "DST" : "",
			template,
			&template_index,
			&buffer,
		) {continue}
		//---------------------------------------
		if processToken(
			"cywk",
			fmt.tprintf("%06d", cywk(tm)),
			template,
			&template_index,
			&buffer,
		) {continue}
		//---------------------------------------
		if processToken(
			"wk",
			fmt.tprintf("%02d", wk(tm)),
			template,
			&template_index,
			&buffer,
		) {continue}
		//---------------------------------------
		if processToken(
			"CY",
			fmt.tprintf("%04d", isoYear(tm)),
			template,
			&template_index,
			&buffer,
		) {continue}
		//---------------------------------------
		if processToken(
			"cy",
			fmt.tprintf("%04d", cy(tm)),
			template,
			&template_index,
			&buffer,
		) {continue}
		//---------------------------------------
		if processToken(
			"c",
			fmt.tprintf("%02d", c(tm)),
			template,
			&template_index,
			&buffer,
		) {continue}
		//---------------------------------------
		if processToken(
			"y",
			fmt.tprintf("%02d", y(tm)),
			template,
			&template_index,
			&buffer,
		) {continue}
		//---------------------------------------
		if processToken(
			"m",
			fmt.tprintf("%02d", m(tm)),
			template,
			&template_index,
			&buffer,
		) {continue}
		//---------------------------------------
		if processToken(
			"d",
			fmt.tprintf("%02d", d(tm)),
			template,
			&template_index,
			&buffer,
		) {continue}
		//---------------------------------------
		if processToken(
			"q",
			fmt.tprintf("%d", q(tm)),
			template,
			&template_index,
			&buffer,
		) {continue}
		//---------------------------------------
		if processToken("MM", monthMM(tm), template, &template_index, &buffer) {continue}
		//---------------------------------------
		if processToken("M", monthM(tm), template, &template_index, &buffer) {continue}
		//---------------------------------------
		if processToken("DD", dowDD(tm), template, &template_index, &buffer) {continue}
		//---------------------------------------
		if processToken("D", dowD(tm), template, &template_index, &buffer) {continue}
		//---------------------------------------
		strings.write_byte(&buffer, template[template_index])
		//---------------------------------------
		template_index += 1
		//---------------------------------------
	}
	//---------------------------------------
	return strings.clone(strings.to_string(buffer), allocator)
	//---------------------------------------
}

main :: proc() {
	//---------------------------------------
	fmt.printfln("%s: main function", filepath.base(os.args[0]))
	//---------------------------------------
}

//------------------------------------------------------------
