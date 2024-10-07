#![no_std]
#![no_main]
mod entry;
mod uart;
use core::fmt::Write;

#[no_mangle]
fn main() -> ! {
    let mut uart = uart::Uart::new(0xc0ffee00usize as _);
    loop {
        write!(uart, "Hello world!\r\n").unwrap();
    }
}
