use std::sync::Arc;

use clone_engine::commands::{FontWeight, RenderCommand, RgbaColor, SurfaceFrame, SurfaceDesc};
use clone_engine::ffi::DesktopDelegate;

/// Demo delegate that returns hardcoded render commands.
struct DemoDelegate;

impl DesktopDelegate for DemoDelegate {
    fn on_frame(&self, _surface_id: u64, width: u32, height: u32) -> Vec<RenderCommand> {
        let w = width as f32;
        let h = height as f32;

        vec![
            // Desktop background (Rose Pine base)
            RenderCommand::Rect {
                x: 0.0,
                y: 0.0,
                w,
                h,
                color: RgbaColor {
                    r: 0.14,
                    g: 0.13,
                    b: 0.19,
                    a: 1.0,
                },
            },
            // Centered card
            RenderCommand::RoundedRect {
                x: w / 2.0 - 200.0,
                y: h / 2.0 - 150.0,
                w: 400.0,
                h: 300.0,
                radius: 16.0,
                color: RgbaColor {
                    r: 0.18,
                    g: 0.16,
                    b: 0.24,
                    a: 1.0,
                },
            },
            // Title text
            RenderCommand::Text {
                x: w / 2.0 - 80.0,
                y: h / 2.0 - 20.0,
                content: "Clone Desktop".into(),
                font_size: 24.0,
                color: RgbaColor {
                    r: 0.88,
                    g: 0.85,
                    b: 0.91,
                    a: 1.0,
                },
                weight: FontWeight::Regular,
            },
            // Dock background
            RenderCommand::RoundedRect {
                x: w / 2.0 - 200.0,
                y: h - 80.0,
                w: 400.0,
                h: 64.0,
                radius: 16.0,
                color: RgbaColor {
                    r: 0.2,
                    g: 0.2,
                    b: 0.2,
                    a: 0.6,
                },
            },
            // Dock icons
            dock_icon(w / 2.0 - 168.0, h - 72.0, 48.0, 0.19, 0.55, 0.91), // blue
            dock_icon(w / 2.0 - 112.0, h - 72.0, 48.0, 0.19, 0.55, 0.91),
            dock_icon(w / 2.0 - 56.0, h - 72.0, 48.0, 0.92, 0.29, 0.35),  // red
            dock_icon(w / 2.0, h - 72.0, 48.0, 0.18, 0.75, 0.49),          // green
            dock_icon(w / 2.0 + 56.0, h - 72.0, 48.0, 0.96, 0.76, 0.29),   // yellow
            dock_icon(w / 2.0 + 112.0, h - 72.0, 48.0, 0.0, 0.0, 0.0),     // black
        ]
    }

    fn on_composite_frame(&self, width: u32, height: u32) -> Vec<SurfaceFrame> {
        let commands = self.on_frame(0, width, height);
        vec![SurfaceFrame {
            desc: SurfaceDesc {
                surface_id: 0,
                x: 0.0, y: 0.0,
                width: width as f32, height: height as f32,
                corner_radius: 0.0, opacity: 1.0,
            },
            commands,
        }]
    }

    fn on_pointer_move(&self, _surface_id: u64, _x: f64, _y: f64) {}
    fn on_pointer_button(&self, _surface_id: u64, _button: u32, _pressed: bool) {}
    fn on_key(&self, _surface_id: u64, _keycode: u32, _pressed: bool) {}
}

fn dock_icon(x: f32, y: f32, size: f32, r: f32, g: f32, b: f32) -> RenderCommand {
    RenderCommand::RoundedRect {
        x,
        y,
        w: size,
        h: size,
        radius: size * 0.22,
        color: RgbaColor { r, g, b, a: 1.0 },
    }
}

fn main() {
    clone_engine::ffi::run_desktop(Box::new(DemoDelegate)).expect("desktop engine failed");
}
