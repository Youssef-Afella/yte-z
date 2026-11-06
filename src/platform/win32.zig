const std = @import("std");
const win32 = @import("win32");

const Window = @import("../window.zig").Window;
const WindowConfig = @import("../window.zig").WindowConfig;
const Surface = @import("../surface.zig").Surface;
const Key = @import("../window.zig").Key;

pub const Win32 = struct {
    hinstance: win32.HINSTANCE,
    hwnd: win32.HWND,
    bmi: win32.BITMAPINFO,
    window: *Window,

    pub fn init(window: *Window, comptime config: WindowConfig) !Win32 {
        const window_title = std.unicode.utf8ToUtf16LeStringLiteral(config.title);

        const window_width: i32 = @bitCast(config.width);
        const window_height: i32 = @bitCast(config.height);

        const hinstance = win32.GetModuleHandleW(null);
        const IDC_ARROW = win32.MAKEINTRESOURCEW(@as(c_int, 32512));

        var wc = win32.WNDCLASSEXW{
            .cbSize = @sizeOf(win32.WNDCLASSEXW),
            .hCursor = win32.LoadCursorW(null, IDC_ARROW),
            .lpfnWndProc = wndProc,
            .hInstance = hinstance,
            .lpszClassName = window_title,
        };

        if (win32.RegisterClassExW(&wc) == 0) {
            return error.RegisterClassFailed;
        }

        const window_style: u32 = win32.WS_VISIBLE | win32.WS_OVERLAPPEDWINDOW;
        const window_ex_style: u32 = 0;

        var rect = win32.RECT{
            .left = 0,
            .top = 0,
            .right = window_width,
            .bottom = window_height,
        };

        if (win32.AdjustWindowRectEx(&rect, window_style, 0, window_ex_style) == 0) {
            return error.AdjustWindowRectFailed;
        }

        const adjusted_width = rect.right - rect.left;
        const adjusted_height = rect.bottom - rect.top;

        const hwnd = win32.CreateWindowExW(
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

        _ = win32.SetWindowLongPtrW(hwnd, win32.GWLP_USERDATA, @intCast(@intFromPtr(window)));
        _ = win32.UpdateWindow(hwnd);

        const bmi = win32.BITMAPINFO{ .bmiHeader = .{
            .biSize = @sizeOf(win32.BITMAPINFOHEADER),
            .biWidth = window_width,
            .biHeight = -window_height,
            .biPlanes = 1,
            .biBitCount = 32,
            .biCompression = win32.BI_RGB,
        } };

        return .{
            .hinstance = hinstance,
            .hwnd = hwnd,
            .bmi = bmi,
            .window = window,
        };
    }

    pub fn deinit(w: *Win32) void {
        _ = win32.DestroyWindow(w.hwnd);
    }

    pub fn blit(w: *Win32, surface: *Surface) void {
        const hdc = win32.GetDC(w.hwnd) orelse return;
        defer _ = win32.ReleaseDC(w.hwnd, hdc);

        _ = win32.SetStretchBltMode(hdc, win32.COLORONCOLOR);

        const width: c_int = @intCast(w.window.config.width);
        const height: c_int = @intCast(w.window.config.height);
        _ = win32.StretchDIBits(
            hdc,
            0,
            0,
            width,
            height,
            0,
            0,
            @intCast(surface.width),
            @intCast(surface.height),
            surface.pixels.ptr,
            &w.bmi,
            win32.DIB_RGB_COLORS,
            win32.SRCCOPY,
        );
    }

    pub fn pollEvents(w: *Win32) void {
        _ = w;

        var msg: win32.MSG = undefined;
        while (win32.PeekMessageW(&msg, null, 0, 0, win32.PM_REMOVE) != 0) {
            _ = win32.TranslateMessage(&msg);
            _ = win32.DispatchMessageW(&msg);
        }
    }
};

fn wndProc(hwnd: win32.HWND, msg: u32, wparam: win32.WPARAM, lparam: win32.LPARAM) callconv(.winapi) win32.LRESULT {
    const ptr = win32.GetWindowLongPtrW(hwnd, win32.GWLP_USERDATA);
    if (ptr == 0) {
        return win32.DefWindowProcW(hwnd, msg, wparam, lparam);
    }

    const window: *Window = @ptrFromInt(@as(usize, @intCast(ptr)));

    switch (msg) {
        win32.WM_SIZE => {
            const w: u32 = @intCast(lparam & 0xFFFF);
            const h: u32 = @intCast((lparam >> 16) & 0xFFFF);
            window.event_queue.push(.{ .resize = .{ .width = w, .height = h } });
            return 0;
        },
        win32.WM_CHAR => {
            const ch: u32 = @truncate(wparam);
            window.event_queue.push(.{ .char = ch });
            return 0;
        },
        win32.WM_KEYDOWN => {
            const key: Key = switch (wparam) {
                win32.VK_RIGHT => .right,
                win32.VK_LEFT => .left,
                win32.VK_UP => .up,
                win32.VK_DOWN => .down,
                win32.VK_CONTROL => .ctrl,
                win32.VK_ADD => .plus,
                win32.VK_SUBTRACT => .minus,
                'S' => .s,
                else => .unknown,
            };
            window.event_queue.push(.{ .key_down = key });
            return 0;
        },
        win32.WM_KEYUP => {
            const key: Key = switch (wparam) {
                win32.VK_RIGHT => .right,
                win32.VK_LEFT => .left,
                win32.VK_UP => .up,
                win32.VK_DOWN => .down,
                win32.VK_CONTROL => .ctrl,
                win32.VK_ADD => .plus,
                win32.VK_SUBTRACT => .minus,
                'S' => .s,
                else => .unknown,
            };
            window.event_queue.push(.{ .key_up = key });
            return 0;
        },
        win32.WM_DESTROY => {
            win32.PostQuitMessage(0);
            window.should_close = true;
            return 0;
        },
        else => return win32.DefWindowProcW(hwnd, msg, wparam, lparam),
    }
}
