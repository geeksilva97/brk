use std::ffi::OsStr;

fn main() {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    let status = if args.first().is_some_and(|arg| arg == OsStr::new("state")) {
        brk::state::main(&args[1..])
    } else if args.first().is_some_and(|arg| arg == OsStr::new("hook")) {
        brk::hooks::main(&args[1..])
    } else {
        brk::cli::main(&args)
    };
    std::process::exit(status);
}
