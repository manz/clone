use crate::commands::FontWeight;

/// Result of measuring text: width and height in logical pixels.
#[derive(Clone, Debug, uniffi::Record)]
pub struct TextSize {
    pub width: f32,
    pub height: f32,
}

/// Measure text using the shared clone-text FontSystem.
#[uniffi::export]
pub fn measure_text(
    content: String,
    font_size: f32,
    weight: FontWeight,
) -> TextSize {
    let ct_weight = to_clone_text_weight(&weight);
    let result = clone_text::measure_text(content, font_size, ct_weight, None);
    TextSize {
        width: result.width,
        height: result.height,
    }
}

fn to_clone_text_weight(weight: &FontWeight) -> clone_text::FontWeight {
    match weight {
        FontWeight::Regular => clone_text::FontWeight::Regular,
        FontWeight::Medium => clone_text::FontWeight::Medium,
        FontWeight::Semibold => clone_text::FontWeight::Semibold,
        FontWeight::Bold => clone_text::FontWeight::Bold,
    }
}
