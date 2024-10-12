use core::*;

pub struct Alloc {
    ptr: cell::Cell<usize>,
}

impl Alloc {
    pub const fn new(ptr: usize) -> Self {
        Alloc {
            ptr: cell::Cell::new(ptr),
        }
    }
}

unsafe impl Sync for Alloc {}

unsafe impl alloc::GlobalAlloc for Alloc {
    unsafe fn alloc(&self, layout: alloc::Layout) -> *mut u8 {
        let mask = layout.align() - 1;
        let aligned = (self.ptr.get() + mask) & !mask;
        self.ptr.set(aligned + layout.size());
        aligned as *mut u8
    }

    unsafe fn dealloc(&self, _: *mut u8, _: alloc::Layout) {}
}
