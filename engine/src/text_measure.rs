use std::sync::Mutex;

use cosmic_text::{Attrs, Buffer, Family, FontSystem, Metrics, Shaping, Weight};

use crate::commands::FontWeight;

/// Lazy-initialized FontSystem shared across all measurement calls.
/// Loaded with the same bundled fonts as the renderer.
static FONT_SYSTEM: Mutex<Option<FontSystem>> = Mutex::new(None);

fn with_font_system<R>(f: impl FnOnce(&mut FontSystem) -> R) -> R {
    let mut guard = FONT_SYSTEM.lock().unwrap();
    if guard.is_none() {
        // Empty font DB — only bundled Inter (static per-weight), no system font fallback
        let mut db = cosmic_text::fontdb::Database::new();
        db.load_font_data(include_bytes!("../assets/Inter-Regular.ttf").to_vec());
        db.load_font_data(include_bytes!("../assets/Inter-Medium.ttf").to_vec());
        db.load_font_data(include_bytes!("../assets/Inter-SemiBold.ttf").to_vec());
        db.load_font_data(include_bytes!("../assets/Inter-Bold.ttf").to_vec());
        let fs = FontSystem::new_with_locale_and_db("en-US".to_string(), db);
        *guard = Some(fs);
    }
    f(guard.as_mut().unwrap())
}

/// Result of measuring text: width and height in logical pixels.
#[derive(Clone, Debug, uniffi::Record)]
pub struct TextSize {
    pub width: f32,
    pub height: f32,
}

/// Measure text using cosmic-text — the same shaping engine used for rendering.
/// Returns the exact bounding size of the shaped text.
#[uniffi::export]
pub fn measure_text(
    content: String,
    font_size: f32,
    weight: FontWeight,
) -> TextSize {
    if content.is_empty() {
        return TextSize {
            width: 0.0,
            height: font_size * 1.2,
        };
    }

    with_font_system(|font_system| {
        let metrics = Metrics::new(font_size, font_size * 1.2);
        let mut buffer = Buffer::new(font_system, metrics);

        let cosmic_weight = match weight {
            FontWeight::Regular => Weight::NORMAL,
            FontWeight::Medium => Weight(500),
            FontWeight::Semibold => Weight::SEMIBOLD,
            FontWeight::Bold => Weight::BOLD,
        };
        let family = Family::Name("Inter");
        let attrs = Attrs::new().family(family).weight(cosmic_weight);
        buffer.set_text(font_system, &content, attrs, Shaping::Advanced);
        buffer.shape_until_scroll(font_system, false);

        let mut total_width: f32 = 0.0;
        let mut total_height: f32 = 0.0;

        for run in buffer.layout_runs() {
            // Width: rightmost glyph edge
            let run_width = run.glyphs.last().map_or(0.0, |g| g.x + g.w);
            total_width = total_width.max(run_width);
            total_height += run.line_height;
        }

        // Fallback if no runs (shouldn't happen for non-empty text)
        if total_height == 0.0 {
            total_height = font_size * 1.2;
        }

        TextSize {
            width: total_width.ceil(),
            height: total_height.ceil(),
        }
    })
}
