package tb_time

import "core:log"
import "core:math"
import vmem "core:mem/virtual"
import "core:testing"
import "core:time"

//------------------------------------------------------------

CY :: 2001
M :: 2
D :: 3

Y :: CY % 100
YMD :: Y * 1_00_00 + M * 1_00 + D
CYMD :: CY * 1_00_00 + M * 1_00 + D

DDD :: 34

HH :: 4
MM :: 5
SS :: 6
ZZZ :: 808

HHMM :: HH * 1_00 + MM
HHMMSS :: HH * 1_00_00 + MM * 1_00 + SS
HHMMSSZZZ :: HH * 1_00_00_000 + MM * 1_00_000 + SS * 1_000 + MS

MS :: 808
NS :: 808000909

UT :: 981173106
UTMS :: 981173106_808
UTNS :: 981173106_808000909

DATE :: 36925
DATETIME :: 36925.1702083333
TIME :: 0.1702083333

//------------------------------------------------------------

test_now, test_time, test_time_nano: time.Time

arena: vmem.Arena
arenaAllocator := vmem.arena_allocator(&arena)

//------------------------------------------------------------

@(init)
init_test :: proc() {
	//----------------------------------------
	test_now = now()
	//----------------------------------------
	ok: bool
	//----------------------------------------
	test_time, ok = componentsToTime(CY, M, D, HH, MM, SS)
	if !ok {
		log.error("failed to convert components to test_time")
	}
	//----------------------------------------
	test_time_nano, ok = componentsToTime(CY, M, D, HH, MM, SS, NS)
	if !ok {
		log.error("failed to convert components to test_time_nano")
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(fini)
deinit_test :: proc() {vmem.arena_destroy(&arena)}

//------------------------------------------------------------

@(test)
now_test :: proc(t: ^testing.T) {
	//----------------------------------------
	testing.expect_value(t, typeid_of(type_of(test_now)), typeid_of(time.Time))
	//----------------------------------------
	testing.expect_value(t, time.year(test_now) > 0, true)
	//----------------------------------------
}

@(test)
unix_time_test :: proc(t: ^testing.T) {
	//----------------------------------------
	unix_time := time_to_unix(test_time)
	//----------------------------------------
	testing.expect_value(t, unix_time, UT)
	//----------------------------------------
	new_time := time_from_unix(unix_time)
	//----------------------------------------
	testing.expect_value(t, new_time, test_time)
	//----------------------------------------
}

@(test)
unix_time_nano_test :: proc(t: ^testing.T) {
	//----------------------------------------
	unix_time_nano := time_to_unix_nano(test_time_nano)
	//----------------------------------------
	testing.expect_value(t, unix_time_nano, UTNS)
	//----------------------------------------
	new_time_nano := time_from_unix_nano(unix_time_nano)
	//----------------------------------------
	testing.expect_value(t, new_time_nano, test_time_nano)
	//----------------------------------------
}

@(test)
time_from_unix_test :: proc(t: ^testing.T) {
	//----------------------------------------
	tm := time_from_unix(UT)
	//----------------------------------------
	hour, minute, second, _ := time.precise_clock_from_time(tm)
	//----------------------------------------
	testing.expect_value(t, typeid_of(type_of(tm)), typeid_of(time.Time))
	//----------------------------------------
	testing.expect_value(t, time.year(tm), CY)
	testing.expect_value(t, int(time.month(tm)), M)
	testing.expect_value(t, time.day(tm), D)
	testing.expect_value(t, hour, HH)
	testing.expect_value(t, minute, MM)
	testing.expect_value(t, second, SS)
	//----------------------------------------
}

@(test)
time_from_unix_nano_test :: proc(t: ^testing.T) {
	//----------------------------------------
	tm := time_from_unix_nano(UTNS)
	//----------------------------------------
	hour, minute, second, nanosecond := time.precise_clock_from_time(tm)
	//----------------------------------------
	testing.expect_value(t, typeid_of(type_of(tm)), typeid_of(time.Time))
	//----------------------------------------
	testing.expect_value(t, time.year(tm), CY)
	testing.expect_value(t, int(time.month(tm)), M)
	testing.expect_value(t, time.day(tm), D)
	testing.expect_value(t, hour, HH)
	testing.expect_value(t, minute, MM)
	testing.expect_value(t, second, SS)
	testing.expect_value(t, nanosecond, NS)
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
componentsToTime_test1 :: proc(t: ^testing.T) {
	//----------------------------------------
	tm, _ := componentsToTime(CY, M, D, HH, MM, SS)
	//----------------------------------------
	hour, minute, second, _ := time.precise_clock_from_time(tm)
	//----------------------------------------
	testing.expect_value(t, typeid_of(type_of(tm)), typeid_of(time.Time))
	//----------------------------------------
	testing.expect_value(t, time.year(tm), CY)
	testing.expect_value(t, int(time.month(tm)), M)
	testing.expect_value(t, time.day(tm), D)
	testing.expect_value(t, hour, HH)
	testing.expect_value(t, minute, MM)
	testing.expect_value(t, second, SS)
	//----------------------------------------
}

@(test)
componentsToTime_test2 :: proc(t: ^testing.T) {
	//----------------------------------------
	tm, _ := componentsToTime(CY, M, D, HH, MM, SS, NS)
	//----------------------------------------
	hour, minute, second, nanosecond := time.precise_clock_from_time(tm)
	//----------------------------------------
	testing.expect_value(t, typeid_of(type_of(tm)), typeid_of(time.Time))
	//----------------------------------------
	testing.expect_value(t, time.year(tm), CY)
	testing.expect_value(t, int(time.month(tm)), M)
	testing.expect_value(t, time.day(tm), D)
	testing.expect_value(t, hour, HH)
	testing.expect_value(t, minute, MM)
	testing.expect_value(t, second, SS)
	testing.expect_value(t, nanosecond, NS)
	//----------------------------------------
}

@(test)
newTime_test1 :: proc(t: ^testing.T) {
	//----------------------------------------
	tm := newTime()
	//----------------------------------------
	hour, minute, second, nanosecond := time.precise_clock_from_time(tm)
	//----------------------------------------
	testing.expect_value(t, typeid_of(type_of(tm)), typeid_of(time.Time))
	//----------------------------------------
	testing.expect_value(t, time.year(tm), 1970)
	testing.expect_value(t, int(time.month(tm)), 1)
	testing.expect_value(t, time.day(tm), 1)
	testing.expect_value(t, hour, 0)
	testing.expect_value(t, minute, 0)
	testing.expect_value(t, second, 0)
	testing.expect_value(t, nanosecond, 0)
	//----------------------------------------
}

@(test)
newTime_test2 :: proc(t: ^testing.T) {
	//----------------------------------------
	tm := newTime(CY)
	//----------------------------------------
	hour, minute, second, nanosecond := time.precise_clock_from_time(tm)
	//----------------------------------------
	testing.expect_value(t, typeid_of(type_of(tm)), typeid_of(time.Time))
	//----------------------------------------
	testing.expect_value(t, time.year(tm), CY)
	testing.expect_value(t, int(time.month(tm)), 1)
	testing.expect_value(t, time.day(tm), 1)
	testing.expect_value(t, hour, 0)
	testing.expect_value(t, minute, 0)
	testing.expect_value(t, second, 0)
	testing.expect_value(t, nanosecond, 0)
	//----------------------------------------
}

@(test)
newTime_test3 :: proc(t: ^testing.T) {
	//----------------------------------------
	tm := newTime(CY, M, D, HH, MM, SS, NS)
	//----------------------------------------
	hour, minute, second, nanosecond := time.precise_clock_from_time(tm)
	//----------------------------------------
	testing.expect_value(t, typeid_of(type_of(tm)), typeid_of(time.Time))
	//----------------------------------------
	testing.expect_value(t, time.year(tm), CY)
	testing.expect_value(t, int(time.month(tm)), M)
	testing.expect_value(t, time.day(tm), D)
	testing.expect_value(t, hour, HH)
	testing.expect_value(t, minute, MM)
	testing.expect_value(t, second, SS)
	testing.expect_value(t, nanosecond, NS)
	//----------------------------------------
}

@(test)
timeFromExcelDateTime_test :: proc(t: ^testing.T) {
	//----------------------------------------
	tm := timeFromExcelDateTime(DATETIME)
	//----------------------------------------
	hour, minute, second, _ := time.precise_clock_from_time(tm)
	//----------------------------------------
	testing.expect_value(t, typeid_of(type_of(tm)), typeid_of(time.Time))
	//----------------------------------------
	testing.expect_value(t, time.year(tm), CY)
	testing.expect_value(t, int(time.month(tm)), M)
	testing.expect_value(t, time.day(tm), D)
	testing.expect_value(t, hour, HH)
	testing.expect_value(t, minute, MM)
	testing.expect_value(t, second, SS)
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
isDST_test :: proc(t: ^testing.T) {
	testing.expect_value(t, isDST(newTime(2024, 3, 30)), false)
	testing.expect_value(t, isDST(newTime(2024, 3, 31)), true)
	testing.expect_value(t, isDST(newTime(2024, 10, 26)), true)
	testing.expect_value(t, isDST(newTime(2024, 10, 27)), false)
	testing.expect_value(t, isDST(newTime(2025, 3, 29)), false)
	testing.expect_value(t, isDST(newTime(2025, 3, 30)), true)
	testing.expect_value(t, isDST(newTime(2025, 10, 25)), true)
	testing.expect_value(t, isDST(newTime(2025, 10, 26)), false)
}

@(test)
isLeapYear_test :: proc(t: ^testing.T) {
	testing.expect_value(t, isLeapYear(newTime(2000)), true)
	testing.expect_value(t, isLeapYear(2000), true)
	testing.expect_value(t, isLeapYear(2001), false)
	testing.expect_value(t, isLeapYear(2002), false)
	testing.expect_value(t, isLeapYear(2003), false)
	testing.expect_value(t, isLeapYear(2004), true)
	testing.expect_value(t, isLeapYear(2005), false)
	testing.expect_value(t, isLeapYear(2006), false)
	testing.expect_value(t, isLeapYear(2007), false)
	testing.expect_value(t, isLeapYear(2008), true)
	testing.expect_value(t, isLeapYear(2009), false)
	testing.expect_value(t, isLeapYear(2010), false)
}

//------------------------------------------------------------

@(test)
cymd_test :: proc(t: ^testing.T) {testing.expect_value(t, cymd(test_time), CYMD)}

@(test)
ymd_test :: proc(t: ^testing.T) {testing.expect_value(t, ymd(test_time), YMD)}

@(test)
cy_test :: proc(t: ^testing.T) {testing.expect_value(t, cy(test_time), CY)}

@(test)
y_test :: proc(t: ^testing.T) {testing.expect_value(t, y(test_time), Y)}

@(test)
m_test :: proc(t: ^testing.T) {testing.expect_value(t, m(test_time), M)}

@(test)
d_test :: proc(t: ^testing.T) {testing.expect_value(t, d(test_time), D)}

@(test)
md_test :: proc(t: ^testing.T) {testing.expect_value(t, md(test_time), M * 1_00 + D)}

@(test)
dm_test :: proc(t: ^testing.T) {testing.expect_value(t, dm(test_time), D * 1_00 + M)}

//------------------------------------------------------------

@(test)
cyddd_test :: proc(t: ^testing.T) {testing.expect_value(t, cyddd(test_time), CY * 1_000 + DDD)}

@(test)
ddd_test :: proc(t: ^testing.T) {testing.expect_value(t, ddd(test_time), DDD)}

@(test)
dow_test :: proc(t: ^testing.T) {
	testing.expect_value(t, dow(newTime(2024, 7, 1)), 1)
	testing.expect_value(t, dow(newTime(2024, 7, 2)), 2)
	testing.expect_value(t, dow(newTime(2024, 7, 3)), 3)
	testing.expect_value(t, dow(newTime(2024, 7, 4)), 4)
	testing.expect_value(t, dow(newTime(2024, 7, 5)), 5)
	testing.expect_value(t, dow(newTime(2024, 7, 6)), 6)
	testing.expect_value(t, dow(newTime(2024, 7, 7)), 7)
	testing.expect_value(t, dow(time.Weekday.Monday), 1)
	testing.expect_value(t, dow(time.Weekday.Tuesday), 2)
	testing.expect_value(t, dow(time.Weekday.Wednesday), 3)
	testing.expect_value(t, dow(time.Weekday.Thursday), 4)
	testing.expect_value(t, dow(time.Weekday.Friday), 5)
	testing.expect_value(t, dow(time.Weekday.Saturday), 6)
	testing.expect_value(t, dow(time.Weekday.Sunday), 7)
}

@(test)
dowD_test :: proc(t: ^testing.T) {
	testing.expect_value(t, dowD(newTime(2024, 7, 1)), "Mon")
	testing.expect_value(t, dowD(time.Weekday.Monday), "Mon")
	testing.expect_value(t, dowD(1), "Mon")
	testing.expect_value(t, dowD(2), "Tue")
	testing.expect_value(t, dowD(3), "Wed")
	testing.expect_value(t, dowD(4), "Thu")
	testing.expect_value(t, dowD(5), "Fri")
	testing.expect_value(t, dowD(6), "Sat")
	testing.expect_value(t, dowD(7), "Sun")
	testing.expect_value(t, dowD(8), "Sun")
}

@(test)
dowDD_test :: proc(t: ^testing.T) {
	testing.expect_value(t, dowDD(newTime(2024, 7, 1)), "Monday")
	testing.expect_value(t, dowDD(time.Weekday.Monday), "Monday")
	testing.expect_value(t, dowDD(1), "Monday")
	testing.expect_value(t, dowDD(2), "Tuesday")
	testing.expect_value(t, dowDD(3), "Wednesday")
	testing.expect_value(t, dowDD(4), "Thursday")
	testing.expect_value(t, dowDD(5), "Friday")
	testing.expect_value(t, dowDD(6), "Saturday")
	testing.expect_value(t, dowDD(7), "Sunday")
	testing.expect_value(t, dowDD(8), "Sunday")
}

@(test)
monthM_test :: proc(t: ^testing.T) {
	testing.expect_value(t, monthM(newTime(2024, 1)), "Jan")
	testing.expect_value(t, monthM(time.Month.January), "Jan")
	testing.expect_value(t, monthM(1), "Jan")
	testing.expect_value(t, monthM(2), "Feb")
	testing.expect_value(t, monthM(3), "Mar")
	testing.expect_value(t, monthM(4), "Apr")
	testing.expect_value(t, monthM(5), "May")
	testing.expect_value(t, monthM(6), "Jun")
	testing.expect_value(t, monthM(7), "Jul")
	testing.expect_value(t, monthM(8), "Aug")
	testing.expect_value(t, monthM(9), "Sep")
	testing.expect_value(t, monthM(10), "Oct")
	testing.expect_value(t, monthM(11), "Nov")
	testing.expect_value(t, monthM(12), "Dec")
	testing.expect_value(t, monthM(13), "")
}

@(test)
monthMM_test :: proc(t: ^testing.T) {
	testing.expect_value(t, monthMM(newTime(2024, 1)), "January")
	testing.expect_value(t, monthMM(time.Month.January), "January")
	testing.expect_value(t, monthMM(1), "January")
	testing.expect_value(t, monthMM(2), "February")
	testing.expect_value(t, monthMM(3), "March")
	testing.expect_value(t, monthMM(4), "April")
	testing.expect_value(t, monthMM(5), "May")
	testing.expect_value(t, monthMM(6), "June")
	testing.expect_value(t, monthMM(7), "July")
	testing.expect_value(t, monthMM(8), "August")
	testing.expect_value(t, monthMM(9), "September")
	testing.expect_value(t, monthMM(10), "October")
	testing.expect_value(t, monthMM(11), "November")
	testing.expect_value(t, monthMM(12), "December")
	testing.expect_value(t, monthMM(13), "")
}

//------------------------------------------------------------

@(test)
isoYear_test :: proc(t: ^testing.T) {
	testing.expect_value(t, isoYear(newTime(2001, 1, 1)), 2001)
	testing.expect_value(t, isoYear(newTime(2001, 12, 31)), 2002)
	testing.expect_value(t, isoYear(newTime(2002, 1, 1)), 2002)
	testing.expect_value(t, isoYear(newTime(2002, 12, 31)), 2003)
	testing.expect_value(t, isoYear(newTime(2003, 1, 1)), 2003)
	testing.expect_value(t, isoYear(newTime(2003, 12, 31)), 2004)
	testing.expect_value(t, isoYear(newTime(2004, 1, 1)), 2004)
	testing.expect_value(t, isoYear(newTime(2004, 12, 31)), 2004)
	testing.expect_value(t, isoYear(newTime(2005, 1, 1)), 2004)
	testing.expect_value(t, isoYear(newTime(2005, 12, 31)), 2005)
}

@(test)
cywk_test :: proc(t: ^testing.T) {
	testing.expect_value(t, cywk(newTime(2001, 1, 1)), 200101)
	testing.expect_value(t, cywk(newTime(2001, 12, 31)), 200201)
	testing.expect_value(t, cywk(newTime(2002, 1, 1)), 200201)
	testing.expect_value(t, cywk(newTime(2002, 12, 31)), 200301)
	testing.expect_value(t, cywk(newTime(2003, 1, 1)), 200301)
	testing.expect_value(t, cywk(newTime(2003, 12, 31)), 200401)
	testing.expect_value(t, cywk(newTime(2004, 1, 1)), 200401)
	testing.expect_value(t, cywk(newTime(2004, 12, 31)), 200453)
	testing.expect_value(t, cywk(newTime(2005, 1, 1)), 200453)
	testing.expect_value(t, cywk(newTime(2005, 1, 2)), 200453)
	testing.expect_value(t, cywk(newTime(2005, 12, 31)), 200552)
	testing.expect_value(t, cywk(newTime(2006, 1, 1)), 200552)
	testing.expect_value(t, cywk(newTime(2006, 1, 2)), 200601)
	testing.expect_value(t, cywk(newTime(2006, 12, 31)), 200652)
	testing.expect_value(t, cywk(newTime(2007, 1, 1)), 200701)
	testing.expect_value(t, cywk(newTime(2007, 12, 30)), 200752)
	testing.expect_value(t, cywk(newTime(2007, 12, 31)), 200801)
	testing.expect_value(t, cywk(newTime(2008, 1, 1)), 200801)
	testing.expect_value(t, cywk(newTime(2008, 12, 28)), 200852)
	testing.expect_value(t, cywk(newTime(2008, 12, 29)), 200901)
	testing.expect_value(t, cywk(newTime(2008, 12, 30)), 200901)
	testing.expect_value(t, cywk(newTime(2008, 12, 31)), 200901)
	testing.expect_value(t, cywk(newTime(2009, 1, 1)), 200901)
	testing.expect_value(t, cywk(newTime(2009, 12, 31)), 200953)
	testing.expect_value(t, cywk(newTime(2010, 1, 1)), 200953)
	testing.expect_value(t, cywk(newTime(2010, 1, 2)), 200953)
	testing.expect_value(t, cywk(newTime(2010, 1, 3)), 200953)
	testing.expect_value(t, cywk(newTime(2010, 12, 31)), 201052)
	testing.expect_value(t, cywk(newTime(2011, 1, 1)), 201052)
	testing.expect_value(t, cywk(newTime(2011, 12, 31)), 201152)
	testing.expect_value(t, cywk(newTime(2012, 1, 1)), 201152)
	testing.expect_value(t, cywk(newTime(2012, 12, 31)), 201301)
	testing.expect_value(t, cywk(newTime(2013, 1, 1)), 201301)
	testing.expect_value(t, cywk(newTime(2013, 12, 31)), 201401)
	testing.expect_value(t, cywk(newTime(2014, 1, 1)), 201401)
	testing.expect_value(t, cywk(newTime(2014, 12, 31)), 201501)
	testing.expect_value(t, cywk(newTime(2015, 1, 1)), 201501)
	testing.expect_value(t, cywk(newTime(2015, 12, 31)), 201553)
	testing.expect_value(t, cywk(newTime(2016, 1, 1)), 201553)
	testing.expect_value(t, cywk(newTime(2016, 12, 31)), 201652)
	testing.expect_value(t, cywk(newTime(2017, 1, 1)), 201652)
	testing.expect_value(t, cywk(newTime(2017, 12, 31)), 201752)
	testing.expect_value(t, cywk(newTime(2018, 1, 1)), 201801)
	testing.expect_value(t, cywk(newTime(2018, 12, 31)), 201901)
	testing.expect_value(t, cywk(newTime(2019, 1, 1)), 201901)
	testing.expect_value(t, cywk(newTime(2019, 12, 31)), 202001)
	testing.expect_value(t, cywk(newTime(2020, 1, 1)), 202001)
	testing.expect_value(t, cywk(newTime(2020, 12, 31)), 202053)
}

@(test)
q_test :: proc(t: ^testing.T) {
	testing.expect_value(t, q(newTime(2001, 1, 1)), 1)
	testing.expect_value(t, q(newTime(2001, 1, 1)), 1)
	testing.expect_value(t, q(1), 1)
	testing.expect_value(t, q(2), 1)
	testing.expect_value(t, q(3), 1)
	testing.expect_value(t, q(4), 2)
	testing.expect_value(t, q(5), 2)
	testing.expect_value(t, q(6), 2)
	testing.expect_value(t, q(7), 3)
	testing.expect_value(t, q(8), 3)
	testing.expect_value(t, q(9), 3)
	testing.expect_value(t, q(10), 4)
	testing.expect_value(t, q(11), 4)
	testing.expect_value(t, q(12), 4)
}

//------------------------------------------------------------

@(test)
hhmmsszzz_test :: proc(t: ^testing.T) {
	testing.expect_value(t, hhmmsszzz(test_time_nano), HHMMSSZZZ)
}

@(test)
hhmmss_test :: proc(t: ^testing.T) {testing.expect_value(t, hhmmss(test_time), HHMMSS)}

@(test)
hhmm_test :: proc(t: ^testing.T) {testing.expect_value(t, hhmm(test_time), HHMM)}

@(test)
hh_test :: proc(t: ^testing.T) {testing.expect_value(t, hh(test_time), HH)}

@(test)
mm_test :: proc(t: ^testing.T) {testing.expect_value(t, mm(test_time), MM)}

@(test)
ss_test :: proc(t: ^testing.T) {testing.expect_value(t, ss(test_time), SS)}

@(test)
zzz_test :: proc(t: ^testing.T) {testing.expect_value(t, zzz(test_time_nano), ZZZ)}

//------------------------------------------------------------

@(test)
hhmmss_to_seconds_test :: proc(t: ^testing.T) {
	testing.expect_value(t, hhmmss_to_seconds(40506), 14706)
}

@(test)
seconds_to_hhmmss_test :: proc(t: ^testing.T) {
	testing.expect_value(t, seconds_to_hhmmss(14706), 40506)
}

//------------------------------------------------------------

@(test)
hhmm_to_mins_test :: proc(t: ^testing.T) {
	testing.expect_value(t, hhmm_to_mins(405), 245)
}

@(test)
mins_to_hhmm_test :: proc(t: ^testing.T) {
	testing.expect_value(t, mins_to_hhmm(245), 405)
}

//------------------------------------------------------------

@(test)
utns_test :: proc(t: ^testing.T) {testing.expect_value(t, utns(test_time_nano), UTNS)}

@(test)
utms_test :: proc(t: ^testing.T) {testing.expect_value(t, utms(test_time_nano), UTMS)}

@(test)
ut_test :: proc(t: ^testing.T) {testing.expect_value(t, ut(test_time), UT)}

//------------------------------------------------------------

@(test)
excelDateTime_test :: proc(t: ^testing.T) {
	testing.expect_value(t, int(excelDateTime(test_time) * 1e10), int(DATETIME * 1e10))
}

@(test)
excelDate_test :: proc(t: ^testing.T) {
	testing.expect_value(t, excelDate(test_time), DATE)
}

@(test)
excelDate_to_cymd_test :: proc(t: ^testing.T) {
	testing.expect_value(t, excelDate_to_cymd(DATE), CYMD)
}

@(test)
cymd_to_excelDate_test :: proc(t: ^testing.T) {
	testing.expect_value(t, cymd_to_excelDate(CYMD), DATE)
}

//------------------------------------------------------------

@(test)
excelTime_test :: proc(t: ^testing.T) {
	testing.expect_value(t, f32(excelTime(test_time)), f32(TIME))
}

@(test)
excelTime_to_hhmmss_test :: proc(t: ^testing.T) {
	testing.expect_value(t, excelTime_to_hhmmss(TIME), HHMMSS)
}

@(test)
hhmmss_to_excelTime_test :: proc(t: ^testing.T) {
	testing.expect_value(t, f32(hhmmss_to_excelTime(HHMMSS)), f32(TIME))
}

//------------------------------------------------------------

@(test)
excelDateTime_to_unixtime_test :: proc(t: ^testing.T) {
	testing.expect_value(t, excelDateTime_to_unixtime(DATETIME), UT)
}

@(test)
unixtime_to_excelDateTime_test :: proc(t: ^testing.T) {
	testing.expect_value(t, int(unixtime_to_excelDateTime(UT) * 1e10), int(DATETIME * 1e10))
}

//------------------------------------------------------------

@(test)
format_test :: proc(t: ^testing.T) {
	//----------------------------------------
	tm1 := newTime(2024, 1, 1, 2, 3, 4)
	tm2 := newTime(2024, 7, 1)
	//----------------------------------------
	result1 := format(tm1, "utms")
	testing.expect_value(t, result1, "1704074584000")

	result2 := format(tm1, "ut", context.allocator)
	testing.expect_value(t, result2, "1704074584")

	delete(result1)
	delete(result2)
	//----------------------------------------
	testing.expect_value(t, format(tm1, "utms", arenaAllocator), "1704074584000")
	testing.expect_value(t, format(tm1, "ut", arenaAllocator), "1704074584")
	testing.expect_value(t, format(tm1, "ddd", arenaAllocator), "001")
	testing.expect_value(t, format(tm1, "hh", arenaAllocator), "02")
	testing.expect_value(t, format(tm1, "mm", arenaAllocator), "03")
	testing.expect_value(t, format(tm1, "ss", arenaAllocator), "04")
	testing.expect_value(t, format(tm1, "zzz", arenaAllocator), "000")
	testing.expect_value(t, format(tm1, "DST", arenaAllocator), "")
	testing.expect_value(t, format(tm2, "DST", arenaAllocator), "DST")
	testing.expect_value(t, format(tm2, "cywk", arenaAllocator), "202427")
	testing.expect_value(t, format(tm2, "wk", arenaAllocator), "27")
	testing.expect_value(t, format(tm2, "CY", arenaAllocator), "2024")
	testing.expect_value(t, format(tm2, "cy", arenaAllocator), "2024")
	testing.expect_value(t, format(tm2, "y", arenaAllocator), "24")
	testing.expect_value(t, format(tm2, "m", arenaAllocator), "07")
	testing.expect_value(t, format(tm2, "d", arenaAllocator), "01")
	testing.expect_value(t, format(tm2, "MM", arenaAllocator), "July")
	testing.expect_value(t, format(tm2, "M", arenaAllocator), "Jul")
	testing.expect_value(t, format(tm2, "DD", arenaAllocator), "Monday")
	testing.expect_value(t, format(tm2, "D", arenaAllocator), "Mon")
	testing.expect_value(t, format(tm2, "q", arenaAllocator), "3")
	//----------------------------------------
	testing.expect_value(t, format(tm2, "cyddd", arenaAllocator), "2024183")
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
safeArrayValue_test :: proc(t: ^testing.T) {
	testing.expect_value(t, safeArrayValue(DAYS), "Invalid Index")
	testing.expect_value(t, safeArrayValue(DAYS, 0), "Invalid Index")
	testing.expect_value(t, safeArrayValue(DAYS, 1), "Monday")
	testing.expect_value(t, safeArrayValue(DAYS, 2), "Tuesday")
	testing.expect_value(t, safeArrayValue(DAYS, 3), "Wednesday")
	testing.expect_value(t, safeArrayValue(DAYS, 4), "Thursday")
	testing.expect_value(t, safeArrayValue(DAYS, 5), "Friday")
	testing.expect_value(t, safeArrayValue(DAYS, 6), "Saturday")
	testing.expect_value(t, safeArrayValue(DAYS, 7), "Sunday")
	testing.expect_value(t, safeArrayValue(DAYS, 8), "")
	testing.expect_value(t, safeArrayValue(DAYS, 9999), "")
}

//------------------------------------------------------------
