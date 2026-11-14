const std = @import("std");
const x11 = @import("x11_api.zig");

const Window = @import("../window.zig").Window;
const WindowConfig = @import("../window.zig").WindowConfig;
const Surface = @import("../surface.zig").Surface;
const Key = @import("../window.zig").Key;

pub const X11 = struct {
    window: *Window,
    display: *x11.Display,
    context: *x11.struct__XGC,
    visual: *x11.Visual,
    win: x11.Window,
    //TODO: Cleaner handling of this
    WM_DELETE_WINDOW: x11.Atom,

    pub fn init(window: *Window, pixels: [*]u8, comptime config: WindowConfig) !X11 {
        const display = x11.XOpenDisplay(0).?;
        const root = x11.XDefaultRootWindow(display);

        const screen = x11.DefaultScreen(display);
        const context = x11.XDefaultGC(display, screen).?;

        const visual = x11.DefaultVisual(display, screen);

        const attribute_value_mask = x11.CWEventMask;
        var attributes: x11.XSetWindowAttributes = .{
            .event_mask = x11.StructureNotifyMask | x11.KeyPressMask | x11.KeyReleaseMask | x11.ExposureMask,
        };

        const win = x11.XCreateWindow(
            display,
            root,
            0,
            0,
            config.width,
            config.height,
            0,
            x11.CopyFromParent,
            x11.CopyFromParent,
            visual,
            attribute_value_mask,
            &attributes,
        );

        _ = x11.XStoreName(display, win, "My window !!");

        var WM_DELETE_WINDOW: x11.Atom = x11.XInternAtom(display, "WM_DELETE_WINDOW", 0);
        if (x11.XSetWMProtocols(display, win, &WM_DELETE_WINDOW, 1) == 0) {
            std.debug.print("Couldn't register WM_DELETE_WINDOW property \n", .{});
        }

        _ = x11.XMapWindow(display, win);
        _ = x11.XFlush(display);

        const img = x11.XCreateImage(display, visual, 0, x11.ZPixmap, 0, @ptrCast(pixels), config.width, config.height, 32, 0);
        _ = x11.XPutImage(display, win, context, img, 0, 0, 0, 0, config.width, config.height);
        _ = x11.XFlush(display);

        return .{
            .window = window,
            .display = display,
            .context = context,
            .WM_DELETE_WINDOW = WM_DELETE_WINDOW,
            .win = win,
            .visual = visual,
        };
    }

    pub fn deinit(x: *X11) void {
        _ = x11.XFreeGC(x.display, x.context);
        _ = x11.XDestroyWindow(x.display, x.win);
        _ = x11.XCloseDisplay(x.display);
    }

    pub fn blit(x: *X11, surface: *Surface) void {
        _ = x;
        _ = surface;
        //const img = x11.XCreateImage(x.display, x.visual, 0, x11.ZPixmap, 0, @ptrCast(surface.pixels), surface.width, surface.height, 32, 0);
        //_ = x11.XPutImage(x.display, x.win, x.context, img, 0, 0, 0, 0, surface.width, surface.height);
        //_ = x11.XFlush(x.display);
        //_ = x11.XDestroyImage(img);
    }

    pub fn pollEvents(x: *X11) void {
        var GeneralEvent: x11.XEvent = undefined;
        _ = x11.XNextEvent(x.display, &GeneralEvent);

        switch (GeneralEvent.type) {
            x11.KeyPress, x11.KeyRelease => {
                //XKeyPressedEvent *Event = (XKeyPressedEvent *)&GeneralEvent;
                //if(Event->keycode == XKeysymToKeycode(MainDisplay, XK_Escape))
                //{
                //    IsWindowOpen = 0;
                //}
                //
                //if(Event->keycode == XKeysymToKeycode(MainDisplay, XK_Down))
                //{
                //    Box.Y += StepSize;
                //}
                //else if(Event->keycode == XKeysymToKeycode(MainDisplay, XK_Up))
                //{
                //    Box.Y -= StepSize;
                //}
                //else if(Event->keycode == XKeysymToKeycode(MainDisplay, XK_Right))
                //{
                //    Box.X += StepSize;
                //}
                //else if(Event->keycode == XKeysymToKeycode(MainDisplay, XK_Left))
                //{
                //    Box.X -= StepSize;
                //}
            },
            x11.ClientMessage => {
                const Event: *x11.XClientMessageEvent = @ptrCast(&GeneralEvent);
                if (@as(x11.Atom, @intCast(Event.data.l[0])) == x.WM_DELETE_WINDOW) {
                    _ = x11.XDestroyWindow(x.display, x.win);
                    x.window.should_close = true;
                }
            },
            else => {},
        }
    }
};
