use core::*;

pub struct Alloc {
    ptr: cell::Cell<*mut u8>,
}

impl Alloc {
    pub const fn new(ptr: *mut u8) -> Self {
        Alloc {
            ptr: cell::Cell::new(ptr),
        }
    }
}

unsafe impl Sync for Alloc {}

unsafe impl alloc::GlobalAlloc for Alloc {
    unsafe fn alloc(&self, layout: alloc::Layout) -> *mut u8 {
        let mask = layout.align() - 1;
        let aligned = (self.ptr.get() as usize + mask) & !mask;
        self.ptr.set((aligned + layout.size()) as *mut u8);
        aligned as *mut u8
    }

    unsafe fn dealloc(&self, _: *mut u8, _: alloc::Layout) {}
}
