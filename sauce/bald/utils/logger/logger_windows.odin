package logger

import "core:strings"

// need to put this in a specific _windows file so this doesn't get imported on other platforms
import win32 "core:sys/windows"

windows_print_to_debug_console :: proc(output: string) {
	win32.OutputDebugStringA(strings.clone_to_cstring(output, allocator=context.temp_allocator))
}