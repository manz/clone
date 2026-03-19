/// Flat render commands — Swift builds these, Rust draws them at absolute coordinates.

#[derive(Clone, Debug, PartialEq, uniffi::Record)]
pub struct RgbaColor {
    pub r: f32,
    pub g: f32,
    pub b: f32,
    pub a: f32,
}

#[derive(Clone, Debug, PartialEq, uniffi::Enum)]
pub enum RenderCommand {
    Rect {
        x: f32,
        y: f32,
        w: f32,
        h: f32,
        color: RgbaColor,
    },
    RoundedRect {
        x: f32,
        y: f32,
        w: f32,
        h: f32,
        radius: f32,
        color: RgbaColor,
    },
    Text {
        x: f32,
        y: f32,
        content: String,
        font_size: f32,
        color: RgbaColor,
    },
    Shadow {
        x: f32,
        y: f32,
        w: f32,
        h: f32,
        radius: f32,
        blur: f32,
        color: RgbaColor,
        ox: f32,
        oy: f32,
    },
    BlurRect {
        x: f32,
        y: f32,
        w: f32,
        h: f32,
        radius: f32,
        blur: f32,
        tint: RgbaColor,
    },
    PushClip {
        x: f32,
        y: f32,
        w: f32,
        h: f32,
        radius: f32,
    },
    PopClip,
    SetOpacity {
        value: f32,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rgba_color_fields() {
        let c = RgbaColor {
            r: 0.1,
            g: 0.2,
            b: 0.3,
            a: 1.0,
        };
        assert_eq!(c.r, 0.1);
        assert_eq!(c.a, 1.0);
    }

    #[test]
    fn render_command_rect_equality() {
        let white = RgbaColor {
            r: 1.0,
            g: 1.0,
            b: 1.0,
            a: 1.0,
        };
        let cmd1 = RenderCommand::Rect {
            x: 0.0,
            y: 0.0,
            w: 100.0,
            h: 50.0,
            color: white.clone(),
        };
        let cmd2 = RenderCommand::Rect {
            x: 0.0,
            y: 0.0,
            w: 100.0,
            h: 50.0,
            color: white,
        };
        assert_eq!(cmd1, cmd2);
    }

    #[test]
    fn render_command_variants() {
        let color = RgbaColor {
            r: 0.0,
            g: 0.0,
            b: 0.0,
            a: 1.0,
        };
        let commands: Vec<RenderCommand> = vec![
            RenderCommand::Rect {
                x: 0.0,
                y: 0.0,
                w: 10.0,
                h: 10.0,
                color: color.clone(),
            },
            RenderCommand::RoundedRect {
                x: 0.0,
                y: 0.0,
                w: 10.0,
                h: 10.0,
                radius: 5.0,
                color: color.clone(),
            },
            RenderCommand::Text {
                x: 0.0,
                y: 0.0,
                content: "hello".into(),
                font_size: 14.0,
                color: color.clone(),
            },
            RenderCommand::PushClip {
                x: 0.0,
                y: 0.0,
                w: 100.0,
                h: 100.0,
                radius: 0.0,
            },
            RenderCommand::PopClip,
            RenderCommand::SetOpacity { value: 0.5 },
        ];
        assert_eq!(commands.len(), 6);
    }
}
