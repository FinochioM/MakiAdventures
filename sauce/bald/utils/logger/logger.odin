package logger

//
// just some logging helpers that make use of the core:log
//

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:strings"

get_context_for_logging :: proc() -> runtime.Context {
	our_context := runtime.default_context()
	our_context.logger = logger()
	our_context.assertion_failure_proc = assertion_failure_proc
	return our_context
}

logger :: proc() -> log.Logger {
	return log.Logger{logger_proc, nil, log.Level.Debug, nil}
}

assertion_failure_proc :: proc(prefix, message: string, loc: runtime.Source_Code_Location) -> ! {

	b := strings.builder_make(context.temp_allocator)
  strings.write_string(&b, "[ASSERT]")
  do_location_header(&b, loc)
  fmt.sbprint(&b, message)
	fmt.sbprint(&b, "\n")

	output := strings.to_string(b)
  fmt.print(output)
	when ODIN_DEBUG && ODIN_OS == .Windows {
		windows_print_to_debug_console(output)
	}
	
	runtime.trap()
}


logger_proc :: proc(data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) {
	// todo, dump this into a file as well.

  b := strings.builder_make(context.temp_allocator)
  strings.write_string(&b, Level_Headers[level])
  do_location_header(&b, location)
  fmt.sbprint(&b, text)
	fmt.sbprint(&b, "\n")
  
	output := strings.to_string(b)
  fmt.print(output)

  when ODIN_DEBUG {

		// need this for printing to the debugger
		when ODIN_OS == .Windows {
			windows_print_to_debug_console(output)
		}

    if level >= log.Level.Error {
      runtime.trap()
    }
  }

	if level == .Fatal {
		runtime.panic(output, loc=location)
	}
}


@(private="file")
Level_Headers := [?]string {
	0 ..< 10 = "DEBUG ",
	10 ..< 20 = "INFO ",
	20 ..< 30 = "WARN ",
	30 ..< 40 = "ERROR ",
	40 ..< 50 = "FATAL ",
}

@(private="file")
do_location_header :: proc(buf: ^strings.Builder, location := #caller_location) {

	file := location.file_path
	{
		last := 0
		for r, i in location.file_path {
			if r == '/' {
				last = i + 1
			}
		}
		file = location.file_path[last:]
	}

	{
		fmt.sbprint(buf, file)
	}
	{
		{
			fmt.sbprint(buf, ":")
		}
		fmt.sbprint(buf, location.line)
	}
	
	fmt.sbprint(buf, ": ")
}
