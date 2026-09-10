const std = @import("std");
const windows = std.os.windows;

const Window = @import("../window.zig").Window;
const WindowConfig = @import("../window.zig").WindowConfig;
const Surface = @import("../surface.zig").Surface;

pub const Win32 = struct {
    hinstance: windows.HINSTANCE,
    hwnd: windows.HWND,
    bmi: BITMAPINFO,
    window: *Window,

    pub fn init(window: *Window, comptime config: WindowConfig) !Win32 {
        const window_title = std.unicode.utf8ToUtf16LeStringLiteral(config.title);

        const window_width: i32 = @bitCast(config.width);
        const window_height: i32 = @bitCast(config.height);

        const hinstance = GetModuleHandleW(null);

        var wc = WNDCLASSEXW{
            .lpfnWndProc = wndProc,
            .hInstance = hinstance,
            .lpszClassName = window_title,
        };

        if (RegisterClassExW(&wc) == 0) {
            return error.RegisterClassFailed;
        }

        const window_style: u32 = 0x10CF0000;
        const window_ex_style: u32 = 0;

        var rect = RECT{
            .left = 0,
            .top = 0,
            .right = window_width,
            .bottom = window_height,
        };

        if (AdjustWindowRectEx(&rect, window_style, 0, window_ex_style) == 0) {
            return error.AdjustWindowRectFailed;
        }

        const adjusted_width = rect.right - rect.left;
        const adjusted_height = rect.bottom - rect.top;

        const hwnd = CreateWindowExW(
            window_ex_style,
            window_title,
            window_title,
            window_style,
            0,
            0,
            adjusted_width,
            adjusted_height,
            null,
            null,
            hinstance,
            null,
        ) orelse return error.CreateWindowFailed;

        _ = SetWindowLongPtrW(hwnd, -21, @intCast(@intFromPtr(window)));
        _ = UpdateWindow(hwnd);

        const bmi = BITMAPINFO{ .bmiHeader = .{
            .biWidth = window_width,
            .biHeight = -window_height,
            .biPlanes = 1,
            .biBitCount = 32,
            .biCompression = 0,
        } };

        return .{
            .hinstance = hinstance,
            .hwnd = hwnd,
            .bmi = bmi,
            .window = window,
        };
    }

    pub fn blit(w: *Win32, surface: *Surface) void {
        var ps: PAINTSTRUCT = undefined;
        const hdc = BeginPaint(w.hwnd, &ps).?;

        const SRCCOPY = 0x00CC0020;

        const width: i32 = @intCast(w.window.config.width);
        const height: i32 = @intCast(w.window.config.height);

        _ = StretchDIBits(hdc, 0, 0, width, height, 0, 0, @intCast(surface.width), @intCast(surface.height), surface.pixels.ptr, &w.bmi, 0, SRCCOPY);
        _ = EndPaint(w.hwnd, &ps);
    }

    pub fn pollEvents(w: *Win32) void {
        _ = w;

        var msg: MSG = undefined;
        while (PeekMessageW(&msg, null, 0, 0, 0x0001) != 0) {
            _ = TranslateMessage(&msg);
            _ = DispatchMessageW(&msg);
        }
    }
};

fn wndProc(hwnd: windows.HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) callconv(.winapi) LRESULT {
    const ptr = GetWindowLongPtrW(hwnd, -21);
    if (ptr == 0) {
        return DefWindowProcW(hwnd, msg, wparam, lparam);
    }

    const window: *Window = @ptrFromInt(@as(usize, @intCast(ptr)));

    const WM_DESTROY = 0x0002;
    const WM_PAINT = 0x000F;

    const WM_KEYDOWN = 0x0100;
    const WM_KEYUP = 0x0101;
    const WM_SIZE = 0x0005;

    switch (msg) {
        WM_SIZE => {
            const w: u32 = @intCast(lparam & 0xFFFF);
            const h: u32 = @intCast((lparam >> 16) & 0xFFFF);
            window.event_queue.push(.{ .resize = .{ .width = w, .height = h } });
            return 0;
        },
        WM_KEYDOWN => {
            window.event_queue.push(.{ .key_down = @intCast(wparam) });
            return 0;
        },
        WM_KEYUP => {
            window.event_queue.push(.{ .key_up = @intCast(wparam) });
            return 0;
        },
        WM_PAINT => {
            return 0;
        },
        WM_DESTROY => {
            PostQuitMessage(0);
            window.should_close = true;
            return 0;
        },
        else => return DefWindowProcW(hwnd, msg, wparam, lparam),
    }
}

const WPARAM = usize;
const LPARAM = isize;
const LRESULT = isize;

const POINT = extern struct { x: i32, y: i32 };
const RECT = extern struct { left: i32, top: i32, right: i32, bottom: i32 };

const BITMAPINFOHEADER = extern struct { biSize: u32 = @sizeOf(BITMAPINFOHEADER), biWidth: i32, biHeight: i32, biPlanes: u16 = 1, biBitCount: u16 = 32, biCompression: u32 = 0, biSizeImage: u32 = 0, biXPelsPerMeter: i32 = 0, biYPelsPerMeter: i32 = 0, biClrUsed: u32 = 0, biClrImportant: u32 = 0 };
const BITMAPINFO = extern struct { bmiHeader: BITMAPINFOHEADER };
const PAINTSTRUCT = extern struct { hdc: windows.HDC, fErase: windows.BOOL, rcPaint: RECT, fRestore: windows.BOOL, fIncUpdate: windows.BOOL, rgbReserved: [32]u8 };
const WNDCLASSEXW = extern struct { cbSize: u32 = @sizeOf(WNDCLASSEXW), style: u32 = 0, lpfnWndProc: WNDPROC, cbClsExtra: i32 = 0, cbWndExtra: i32 = 0, hInstance: windows.HINSTANCE, hIcon: ?windows.HICON = null, hCursor: ?windows.HCURSOR = null, hbrBackground: ?windows.HBRUSH = null, lpszMenuName: ?[*:0]const u16 = null, lpszClassName: [*:0]const u16, hIconSm: ?windows.HICON = null };
const MSG = extern struct { hwnd: ?windows.HWND, message: u32, wParam: WPARAM, lParam: LPARAM, time: u32, pt: POINT, lPrivate: u32 = 0 };

const WNDPROC = *const fn (hwnd: windows.HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) callconv(.winapi) LRESULT;

extern "kernel32" fn GetModuleHandleW(?[*:0]const u16) callconv(.winapi) windows.HINSTANCE;
extern "gdi32" fn StretchDIBits(hdc: windows.HDC, xDest: i32, yDest: i32, destWidth: i32, destHeight: i32, xSrc: i32, ySrc: i32, srcWidth: i32, srcHeight: i32, lpBits: ?*const anyopaque, lpBmi: *const BITMAPINFO, usage: u32, rop: u32) callconv(.winapi) i32;

extern "user32" fn RegisterClassExW(*const WNDCLASSEXW) callconv(.winapi) windows.ATOM;
extern "user32" fn CreateWindowExW(dwExStyle: u32, lpClassName: [*:0]const u16, lpWindowName: [*:0]const u16, dwStyle: u32, x: i32, y: i32, nWidth: i32, nHeight: i32, hWndParent: ?windows.HWND, hMenu: ?windows.HMENU, hInstance: windows.HINSTANCE, lpParam: ?*anyopaque) callconv(.winapi) ?windows.HWND;
extern "user32" fn DefWindowProcW(windows.HWND, u32, WPARAM, LPARAM) callconv(.winapi) LRESULT;
extern "user32" fn ShowWindow(windows.HWND, i32) callconv(.winapi) windows.BOOL;
extern "user32" fn UpdateWindow(windows.HWND) callconv(.winapi) windows.BOOL;
extern "user32" fn SetWindowLongPtrW(windows.HWND, i32, windows.LONG_PTR) callconv(.winapi) windows.LONG_PTR;
extern "user32" fn GetWindowLongPtrW(windows.HWND, i32) callconv(.winapi) windows.LONG_PTR;
extern "user32" fn PeekMessageW(*MSG, ?windows.HWND, u32, u32, u32) callconv(.winapi) i32;
extern "user32" fn GetMessageW(*MSG, ?windows.HWND, u32, u32) callconv(.winapi) i32;
extern "user32" fn TranslateMessage(*const MSG) callconv(.winapi) windows.BOOL;
extern "user32" fn DispatchMessageW(*const MSG) callconv(.winapi) LRESULT;
extern "user32" fn PostQuitMessage(i32) callconv(.winapi) void;
extern "user32" fn BeginPaint(hwnd: windows.HWND, lpPaint: *PAINTSTRUCT) callconv(.winapi) ?windows.HDC;
extern "user32" fn EndPaint(hwnd: windows.HWND, lpPaint: *const PAINTSTRUCT) callconv(.winapi) windows.BOOL;
extern "user32" fn AdjustWindowRectEx(lpRect: *RECT, dwStyle: u32, bMenu: i32, dwExStyle: u32) callconv(.winapi) i32;
