const std = @import("std");
const builtin = @import("builtin");

const win32 = switch (builtin.target.cpu.arch) {
    .x86 => @import("win32_32_api.zig"),
    else => @import("win32_64_api.zig"),
};

const Window = @import("../window.zig").Window;
const WindowConfig = @import("../window.zig").WindowConfig;
const Surface = @import("../surface.zig").Surface;
const Key = @import("../window.zig").Key;

pub const Win32 = struct {
    window: *Window,

    //internal state
    hinstance: win32.HINSTANCE,
    hwnd: win32.HWND,
    bmi: win32.BITMAPINFO,
    hbm: win32.HBITMAP,
    hdc: win32.HDC,

    pub fn init(window: *Window, title: [:0]const u8) !Win32 {
        var surface = &window.*.surface;

        const window_width: i32 = @bitCast(surface.width);
        const window_height: i32 = @bitCast(surface.height);

        const hinstance = win32.GetModuleHandleA(null);
        const IDC_ARROW = @as(c_int, 32512);

        var wc = win32.WNDCLASSEXA{
            .cbSize = @sizeOf(win32.WNDCLASSEXA),
            .hCursor = win32.LoadCursorA(null, IDC_ARROW),
            .lpfnWndProc = wndProc,
            .hInstance = hinstance,
            .lpszClassName = title,
        };

        if (win32.RegisterClassExA(&wc) == 0) {
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

        const hwnd = win32.CreateWindowExA(
            window_ex_style,
            title,
            title,
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

        const hdc = win32.CreateCompatibleDC(0);
        const bmi = win32.BITMAPINFO{ .bmiHeader = .{
            .biSize = @sizeOf(win32.BITMAPINFOHEADER),
            .biWidth = window_width,
            .biHeight = -window_height,
            .biPlanes = 1,
            .biBitCount = 32,
            .biCompression = win32.BI_RGB,
        } };

        _ = win32.SetWindowLongPtrA(hwnd, win32.GWLP_USERDATA, @intCast(@intFromPtr(window)));
        _ = win32.UpdateWindow(hwnd);

        var bits: ?*anyopaque = null;
        const hbm = win32.CreateDIBSection(0, &bmi, win32.DIB_RGB_COLORS, &bits, null, 0);
        _ = win32.SelectObject(hdc, hbm);

        const pixels: [*]u32 = @ptrCast(@alignCast(bits.?));
        surface.pixels = pixels[0 .. surface.width * surface.height];

        return .{
            .hinstance = hinstance,
            .hwnd = hwnd,
            .bmi = bmi,
            .hdc = hdc,
            .hbm = hbm,
            .window = window,
        };
    }

    pub fn deinit(w: *Win32) void {
        _ = win32.DestroyWindow(w.hwnd);
    }

    pub fn blit(w: *Win32) void {
        _ = win32.InvalidateRect(w.hwnd, null, win32.FALSE);
        _ = win32.UpdateWindow(w.hwnd);
    }

    pub fn pollEvents(w: *Win32) void {
        _ = w;

        var msg: win32.MSG = undefined;
        while (win32.PeekMessageA(&msg, null, 0, 0, win32.PM_REMOVE) != 0) {
            _ = win32.TranslateMessage(&msg);
            _ = win32.DispatchMessageA(&msg);
        }
    }
};

fn wndProc(hwnd: win32.HWND, msg: u32, wparam: win32.WPARAM, lparam: win32.LPARAM) callconv(.winapi) win32.LRESULT {
    const ptr = win32.GetWindowLongPtrA(hwnd, win32.GWLP_USERDATA);
    if (ptr == 0) {
        return win32.DefWindowProcA(hwnd, msg, wparam, lparam);
    }

    var window: *Window = @ptrFromInt(@as(usize, @intCast(ptr)));
    var w32 = &window.platform;
    var surface = &window.surface;

    switch (msg) {
        win32.WM_DESTROY, win32.WM_QUIT => {
            window.should_close = true;
            win32.PostQuitMessage(0);
        },
        win32.WM_PAINT => {
            var paint: win32.PAINTSTRUCT = undefined;
            var hdc: win32.HDC = undefined;
            hdc = win32.BeginPaint(hwnd, &paint);
            _ = win32.BitBlt(
                hdc,
                paint.rcPaint.left,
                paint.rcPaint.top,
                paint.rcPaint.right - paint.rcPaint.left,
                paint.rcPaint.bottom - paint.rcPaint.top,
                w32.hdc,
                paint.rcPaint.left,
                paint.rcPaint.top,
                win32.SRCCOPY,
            );
            _ = win32.EndPaint(hwnd, &paint);
        },
        win32.WM_SIZE => {
            const width: i32 = @intCast(win32.LOWORD(lparam));
            const height: i32 = @intCast(win32.HIWORD(lparam));

            w32.bmi.bmiHeader.biWidth = width;
            w32.bmi.bmiHeader.biHeight = -height;

            if (w32.hbm != null) _ = win32.DeleteObject(w32.hbm);

            var bits: ?*anyopaque = null;
            w32.hbm = win32.CreateDIBSection(0, &w32.bmi, win32.DIB_RGB_COLORS, &bits, null, 0);
            _ = win32.SelectObject(w32.hdc, w32.hbm);

            const pixels: [*]u32 = @ptrCast(@alignCast(bits.?));
            surface.width = @intCast(width);
            surface.height = @intCast(height);
            surface.pixels = pixels[0 .. surface.width * surface.height];
            //const w: u32 = @intCast(lparam & 0xFFFF);
            //const h: u32 = @intCast((lparam >> 16) & 0xFFFF);
            //window.events.push(.{ .resize = .{ .width = w, .height = h } });
        },
        win32.WM_CHAR => {
            const ch: u32 = @truncate(wparam);
            window.events.push(.{ .char = ch });
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
                'I' => .i,
                'K' => .k,
                'J' => .j,
                'L' => .l,
                else => .unknown,
            };
            window.events.push(.{ .key_down = key });
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
                'I' => .i,
                'K' => .k,
                'J' => .j,
                'L' => .l,
                else => .unknown,
            };
            window.events.push(.{ .key_up = key });
        },
        else => return win32.DefWindowProcA(hwnd, msg, wparam, lparam),
    }

    return 0;
}
