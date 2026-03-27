use clone_render::commands::{RenderCommand, RgbaColor};
use clone_render::headless::HeadlessDevice;

#[test]
fn headless_renders_to_pixels() {
    let mut device = HeadlessDevice::new().expect("Failed to create headless device");

    let commands = vec![RenderCommand::Rect {
        x: 0.0,
        y: 0.0,
        w: 100.0,
        h: 100.0,
        color: RgbaColor {
            r: 1.0,
            g: 0.0,
            b: 0.0,
            a: 1.0,
        },
    }];

    let pixels = device.render_to_pixels(&commands, 100, 100, 1.0);

    // 100x100 at scale 1.0 = 100x100 pixels, 4 bytes each
    assert_eq!(pixels.len(), 100 * 100 * 4);

    // Pixels should not be all zero (we drew a red rect)
    assert!(pixels.iter().any(|&b| b != 0));
}

#[test]
fn headless_scales_output() {
    let mut device = HeadlessDevice::new().expect("Failed to create headless device");

    let commands = vec![RenderCommand::Rect {
        x: 0.0,
        y: 0.0,
        w: 50.0,
        h: 50.0,
        color: RgbaColor {
            r: 0.0,
            g: 1.0,
            b: 0.0,
            a: 1.0,
        },
    }];

    // At 2x scale, 50x50 logical = 100x100 physical
    let pixels = device.render_to_pixels(&commands, 50, 50, 2.0);
    assert_eq!(pixels.len(), 100 * 100 * 4);
}

#[test]
fn headless_empty_commands() {
    let mut device = HeadlessDevice::new().expect("Failed to create headless device");
    let pixels = device.render_to_pixels(&[], 10, 10, 1.0);
    assert_eq!(pixels.len(), 10 * 10 * 4);
}

#[test]
fn headless_renders_to_png() {
    let mut device = HeadlessDevice::new().expect("Failed to create headless device");

    let commands = vec![
        RenderCommand::Rect {
            x: 0.0,
            y: 0.0,
            w: 200.0,
            h: 200.0,
            color: RgbaColor {
                r: 0.2,
                g: 0.2,
                b: 0.3,
                a: 1.0,
            },
        },
        RenderCommand::RoundedRect {
            x: 20.0,
            y: 20.0,
            w: 160.0,
            h: 60.0,
            radius: 8.0,
            color: RgbaColor {
                r: 1.0,
                g: 1.0,
                b: 1.0,
                a: 1.0,
            },
        },
    ];

    let path = "/tmp/clone-headless-test.png";
    device
        .render_to_png(&commands, 200, 200, 2.0, path)
        .expect("Failed to render PNG");

    assert!(std::path::Path::new(path).exists());
    let metadata = std::fs::metadata(path).unwrap();
    assert!(metadata.len() > 0);

    std::fs::remove_file(path).ok();
}
