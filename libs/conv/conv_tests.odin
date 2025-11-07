#+feature global-context

package conv

//------------------------------------------------------------
/*

	Example Package / Test

*/
//------------------------------------------------------------

import "core:mem/virtual"
import "core:testing"

//------------------------------------------------------------

arena: virtual.Arena
allocator := virtual.arena_allocator(&arena)

//------------------------------------------------------------

@(fini)
deinit_test :: proc() {virtual.arena_destroy(&arena)}

//------------------------------------------------------------

@(test)
test_base_encode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:           string,
		expected:       string,
		expected_error: Error,
	} {
		{data = "", expected = "", expected_error = Error(nil)},
		{data = "A", expected = "8q", expected_error = Error(nil)},
		{data = "AA", expected = "8x]", expected_error = Error(nil)},
		{data = "AAA", expected = "8x_i", expected_error = Error(nil)},
		{data = "AAAA", expected = "8x_j)", expected_error = Error(nil)},
		{data = "ABC\U0001F427", expected = "8xix1W</w", expected_error = Error(nil)},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := base_encode(data = test_case.data, allocator = allocator)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, test_case.expected_error)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_base_decode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:           string,
		expected:       string,
		expected_error: Error,
	} {
		{data = "", expected = "", expected_error = Error(nil)},
		{data = "8q", expected = "A", expected_error = Error(nil)},
		{data = "8x]", expected = "AA", expected_error = Error(nil)},
		{data = "8x_i", expected = "AAA", expected_error = Error(nil)},
		{data = "8x_j)", expected = "AAAA", expected_error = Error(nil)},
		{data = "8xix1W</w", expected = "ABC\U0001F427", expected_error = Error(nil)},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := base_decode(data = test_case.data, allocator = allocator)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_base64_encode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:     string,
		expected: string,
	} {
		{data = "", expected = ""},
		{data = "A", expected = "QQ=="},
		{data = "AA", expected = "QUE="},
		{data = "AAA", expected = "QUFB"},
		{data = "AAAA", expected = "QUFBQQ=="},
		{data = "ABC\U0001F427", expected = "QUJD8J+Qpw=="},
		{data = "\U0001F427\U0001F427", expected = "8J+Qp/CfkKc="},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := base64_encode(data = test_case.data, allocator = allocator)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_base64_decode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:     string,
		expected: string,
	} {
		{data = "", expected = ""},
		{data = "QQ==", expected = "A"},
		{data = "QUE=", expected = "AA"},
		{data = "QUFB", expected = "AAA"},
		{data = "QUFBQQ==", expected = "AAAA"},
		{data = "QUJD8J+Qpw==", expected = "ABC\U0001F427"},
		{data = "8J+Qp/CfkKc=", expected = "\U0001F427\U0001F427"},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := base64_decode(data = test_case.data, allocator = allocator)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_base64url_encode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:     string,
		expected: string,
	} {
		{data = "", expected = ""},
		{data = "A", expected = "QQ"},
		{data = "AA", expected = "QUE"},
		{data = "AAA", expected = "QUFB"},
		{data = "AAAA", expected = "QUFBQQ"},
		{data = "ABC\U0001F427", expected = "QUJD8J-Qpw"},
		{data = "\U0001F427\U0001F427", expected = "8J-Qp_CfkKc"},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := base64url_encode(data = test_case.data, allocator = allocator)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_base64url_decode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:     string,
		expected: string,
	} {
		{data = "", expected = ""},
		{data = "QQ", expected = "A"},
		{data = "QUE", expected = "AA"},
		{data = "QUFB", expected = "AAA"},
		{data = "QUFBQQ", expected = "AAAA"},
		{data = "QUJD8J-Qpw", expected = "ABC\U0001F427"},
		{data = "8J-Qp_CfkKc", expected = "\U0001F427\U0001F427"},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := base64url_decode(data = test_case.data, allocator = allocator)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, nil)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_base91_encode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:           string,
		escape:         bool,
		expected:       string,
		expected_error: Error,
	} {
		{data = "", escape = false, expected = "", expected_error = Error(nil)},
		{data = "A", escape = false, expected = "%A", expected_error = Error(nil)},
		{data = "AA", escape = false, expected = "wDC", expected_error = Error(nil)},
		{data = "AAA", escape = false, expected = "wD(F", expected_error = Error(nil)},
		{data = "AAAA", escape = false, expected = "wDWcQ", expected_error = Error(nil)},
		{
			data = "ABC\U0001F427",
			escape = false,
			expected = "fG^FqWzqK",
			expected_error = Error(nil),
		},
		{
			data = "\U0001F427\U0001F427",
			escape = false,
			expected = "=~U@U?uDqd",
			expected_error = Error(nil),
		},
		{
			data = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#\x24%&()*+,./:;<=>?@[]^_\x60{|}~\x22",
			escape = false,
			expected = "fG^F%w_o%5qOdwQbFrzd[5eYAP;gMP+f#G(Ic,5ph#77&xrmlrjgs@DZ7UB>xQGrgw_,\x24k_i\x24Js@Tj\x24MaRDa7dq)L1<[3vwV[|O/7%q{{9G\x60C/LM",
			expected_error = Error(nil),
		},
		{
			data = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#\x24%&()*+,./:;<=>?@[]^_\x60{|}~\x22",
			escape = true,
			expected = "fG^F%w_o%5qOdwQbFrzd[5eYAP;gMP+f#G(Ic,5ph#77&xrmlrjgs@DZ7UB>xQGrgw_,-dk_i-dJs@Tj-dMaRDa7dq)L1<[3vwV[|O/7%q{{9G-gC/LM",
			expected_error = Error(nil),
		},
		{
			data = "\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2A\x2B\x2C\x2D\x2E\x2F\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3A\x3B\x3C\x3D\x3E\x3F\x40\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4A\x4B\x4C\x4D\x4E\x4F\x50\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5A\x5B\x5C\x5D\x5E\x5F\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x6D\x6E\x6F\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7A\x7B\x7C\x7D\x7E\x7F\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8A\x8B\x8C\x8D\x8E\x8F\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9A\x9B\x9C\x9D\x9E\x9F\xA0\xA1\xA2\xA3\xA4\xA5\xA6\xA7\xA8\xA9\xAA\xAB\xAC\xAD\xAE\xAF\xB0\xB1\xB2\xB3\xB4\xB5\xB6\xB7\xB8\xB9\xBA\xBB\xBC\xBD\xBE\xBF\xC0\xC1\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD7\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xDF\xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF7\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xFF",
			escape = true,
			expected = ":C#(:C?hVB-dMSiVEwndBAMZRxwFfBB;IW<}YQV!A_v-dY_c%zr4cYQPFl0,@heMAJ<:N[*T+/SFGr*-gb4PD}vgYqU>cW0P*1NwV,O{cQ5u0m900[8@n4,wh?DP<2+~jQSW6nmLm1o.J,?jTs%2<WF%qb=oh|}.C+W-gEI!bv-qXJ5KIV<G+aX]c[z-d8)@aR67gb7p(-gr4kHjOraEr8:A8y0G9KsDm7jpa{fh>hT8%;@!9;s>JX?#GT<W+vbf-gA2a^wkFZCr<:V-d}SR##&<^lr<Jn?_K5qh.JyLp+99&B_6vZ&x[uhn}L@sh3}g__~#",
			expected_error = Error(nil),
		},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := base91_encode(
			data = test_case.data,
			escape = test_case.escape,
			allocator = allocator,
		)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, test_case.expected_error)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_base91_decode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:           string,
		unescape:       bool,
		expected:       string,
		expected_error: Error,
	} {
		{data = "", unescape = false, expected = "", expected_error = Error(nil)},
		{data = "%A", unescape = false, expected = "A", expected_error = Error(nil)},
		{data = "wDC", unescape = false, expected = "AA", expected_error = Error(nil)},
		{data = "wD(F", unescape = false, expected = "AAA", expected_error = Error(nil)},
		{data = "wDWcQ", unescape = false, expected = "AAAA", expected_error = Error(nil)},
		{
			data = "fG^FqWzqK",
			unescape = false,
			expected = "ABC\U0001F427",
			expected_error = Error(nil),
		},
		{
			data = "=~U@U?uDqd",
			unescape = false,
			expected = "\U0001F427\U0001F427",
			expected_error = Error(nil),
		},
		{
			data = "fG^F%w_o%5qOdwQbFrzd[5eYAP;gMP+f#G(Ic,5ph#77&xrmlrjgs@DZ7UB>xQGrgw_,\x24k_i\x24Js@Tj\x24MaRDa7dq)L1<[3vwV[|O/7%q{{9G\x60C/LM",
			unescape = false,
			expected = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#\x24%&()*+,./:;<=>?@[]^_\x60{|}~\x22",
			expected_error = Error(nil),
		},
		{
			data = "fG^F%w_o%5qOdwQbFrzd[5eYAP;gMP+f#G(Ic,5ph#77&xrmlrjgs@DZ7UB>xQGrgw_,-dk_i-dJs@Tj-dMaRDa7dq)L1<[3vwV[|O/7%q{{9G-gC/LM",
			unescape = true,
			expected = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#\x24%&()*+,./:;<=>?@[]^_\x60{|}~\x22",
			expected_error = Error(nil),
		},
		{
			data = ":C#(:C?hVB-dMSiVEwndBAMZRxwFfBB;IW<}YQV!A_v-dY_c%zr4cYQPFl0,@heMAJ<:N[*T+/SFGr*-gb4PD}vgYqU>cW0P*1NwV,O{cQ5u0m900[8@n4,wh?DP<2+~jQSW6nmLm1o.J,?jTs%2<WF%qb=oh|}.C+W-gEI!bv-qXJ5KIV<G+aX]c[z-d8)@aR67gb7p(-gr4kHjOraEr8:A8y0G9KsDm7jpa{fh>hT8%;@!9;s>JX?#GT<W+vbf-gA2a^wkFZCr<:V-d}SR##&<^lr<Jn?_K5qh.JyLp+99&B_6vZ&x[uhn}L@sh3}g__~#",
			unescape = true,
			expected = "\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2A\x2B\x2C\x2D\x2E\x2F\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3A\x3B\x3C\x3D\x3E\x3F\x40\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4A\x4B\x4C\x4D\x4E\x4F\x50\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5A\x5B\x5C\x5D\x5E\x5F\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x6D\x6E\x6F\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7A\x7B\x7C\x7D\x7E\x7F\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8A\x8B\x8C\x8D\x8E\x8F\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9A\x9B\x9C\x9D\x9E\x9F\xA0\xA1\xA2\xA3\xA4\xA5\xA6\xA7\xA8\xA9\xAA\xAB\xAC\xAD\xAE\xAF\xB0\xB1\xB2\xB3\xB4\xB5\xB6\xB7\xB8\xB9\xBA\xBB\xBC\xBD\xBE\xBF\xC0\xC1\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD7\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xDF\xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF7\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xFF",
			expected_error = Error(nil),
		},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := base91_decode(
			data = test_case.data,
			unescape = test_case.unescape,
			allocator = allocator,
		)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, test_case.expected_error)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_hex_encode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:           string,
		expected:       string,
		expected_error: Error,
	} {
		{data = "", expected = "", expected_error = Error(nil)},
		{data = "ABC", expected = "414243", expected_error = Error(nil)},
		{data = "ABC\U0001F427", expected = "414243F09F90A7", expected_error = Error(nil)},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := hex_encode(data = test_case.data, allocator = allocator)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, test_case.expected_error)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_hex_decode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:           string,
		expected:       string,
		expected_error: Error,
	} {
		{data = "", expected = "", expected_error = Error(nil)},
		{data = "#", expected = "", expected_error = .InvalidHexStringLength},
		{data = "##", expected = "", expected_error = .InvalidEncodedHexCharacter},
		{data = "414243", expected = "ABC", expected_error = Error(nil)},
		{data = "414243F09F90A7", expected = "ABC\U0001F427", expected_error = Error(nil)},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := hex_decode(data = test_case.data, allocator = allocator)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, test_case.expected_error)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_hexValueEncode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:           u8,
		expected:       u8,
		expected_error: Error,
	} {
		{data = 0, expected = '0', expected_error = Error(nil)},
		{data = 1, expected = '1', expected_error = Error(nil)},
		{data = 2, expected = '2', expected_error = Error(nil)},
		{data = 3, expected = '3', expected_error = Error(nil)},
		{data = 4, expected = '4', expected_error = Error(nil)},
		{data = 5, expected = '5', expected_error = Error(nil)},
		{data = 6, expected = '6', expected_error = Error(nil)},
		{data = 7, expected = '7', expected_error = Error(nil)},
		{data = 8, expected = '8', expected_error = Error(nil)},
		{data = 9, expected = '9', expected_error = Error(nil)},
		{data = 10, expected = 'A', expected_error = Error(nil)},
		{data = 11, expected = 'B', expected_error = Error(nil)},
		{data = 12, expected = 'C', expected_error = Error(nil)},
		{data = 13, expected = 'D', expected_error = Error(nil)},
		{data = 14, expected = 'E', expected_error = Error(nil)},
		{data = 15, expected = 'F', expected_error = Error(nil)},
		{data = 16, expected = 0, expected_error = .InvalidHexValue},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := hexValueEncode(test_case.data)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, test_case.expected_error)
	}
	//----------------------------------------
}

//------------------------------------------------------------

@(test)
test_hexValueDecode :: proc(t: ^testing.T) {
	//----------------------------------------
	test_cases := []struct {
		data:           u8,
		expected:       u8,
		expected_error: Error,
	} {
		{data = '0', expected = 0, expected_error = Error(nil)},
		{data = '1', expected = 1, expected_error = Error(nil)},
		{data = '2', expected = 2, expected_error = Error(nil)},
		{data = '3', expected = 3, expected_error = Error(nil)},
		{data = '4', expected = 4, expected_error = Error(nil)},
		{data = '5', expected = 5, expected_error = Error(nil)},
		{data = '6', expected = 6, expected_error = Error(nil)},
		{data = '7', expected = 7, expected_error = Error(nil)},
		{data = '8', expected = 8, expected_error = Error(nil)},
		{data = '9', expected = 9, expected_error = Error(nil)},
		{data = 'A', expected = 10, expected_error = Error(nil)},
		{data = 'B', expected = 11, expected_error = Error(nil)},
		{data = 'C', expected = 12, expected_error = Error(nil)},
		{data = 'D', expected = 13, expected_error = Error(nil)},
		{data = 'E', expected = 14, expected_error = Error(nil)},
		{data = 'F', expected = 15, expected_error = Error(nil)},
		{data = 'G', expected = 0, expected_error = .InvalidEncodedHexCharacter},
		{data = '#', expected = 0, expected_error = .InvalidEncodedHexCharacter},
	}
	//----------------------------------------
	for test_case in test_cases {
		result, err := hexValueDecode(test_case.data)
		testing.expect_value(t, result, test_case.expected)
		testing.expect_value(t, err, test_case.expected_error)
	}
	//----------------------------------------
}

//------------------------------------------------------------
