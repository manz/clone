/// Symphonia-based audio decoder. Internal — not UniFFI-exported.

use std::fs::File;

use symphonia::core::audio::SampleBuffer;
use symphonia::core::codecs::{DecoderOptions, CODEC_TYPE_NULL};
use symphonia::core::formats::{FormatOptions, FormatReader, SeekMode, SeekTo};
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;
use symphonia::core::probe::Hint;
use symphonia::core::units::Time;

use crate::ffi::{AudioError, TrackMetadata};

pub struct AudioDecoder {
    reader: Box<dyn FormatReader>,
    decoder: Box<dyn symphonia::core::codecs::Decoder>,
    track_id: u32,
    sample_rate: u32,
    channels: u16,
    duration_seconds: Option<f64>,
    metadata: TrackMetadata,
}

impl AudioDecoder {
    pub fn open(path: &str) -> Result<Self, AudioError> {
        let file = File::open(path).map_err(|_| AudioError::FileNotFound {
            path: path.to_string(),
        })?;

        let source = MediaSourceStream::new(Box::new(file), Default::default());

        let mut hint = Hint::new();
        if let Some(ext) = std::path::Path::new(path).extension().and_then(|e| e.to_str()) {
            hint.with_extension(ext);
        }

        let probed = symphonia::default::get_probe()
            .format(
                &hint,
                source,
                &FormatOptions::default(),
                &MetadataOptions::default(),
            )
            .map_err(|_| AudioError::UnsupportedFormat)?;

        let mut reader = probed.format;

        let track = reader
            .tracks()
            .iter()
            .find(|t| t.codec_params.codec != CODEC_TYPE_NULL)
            .ok_or(AudioError::UnsupportedFormat)?;

        let track_id = track.id;
        let codec_params = &track.codec_params;

        let sample_rate = codec_params.sample_rate.unwrap_or(44100);
        let channels = codec_params
            .channels
            .map(|c| c.count() as u16)
            .unwrap_or(2);

        let duration_seconds = codec_params.n_frames.map(|frames| {
            frames as f64 / sample_rate as f64
        });

        let decoder = symphonia::default::get_codecs()
            .make(codec_params, &DecoderOptions::default())
            .map_err(|e| AudioError::DecodingFailed {
                reason: e.to_string(),
            })?;

        // Extract metadata from tags
        let metadata = Self::extract_metadata(&mut reader, duration_seconds.unwrap_or(0.0));

        Ok(Self {
            reader,
            decoder,
            track_id,
            sample_rate,
            channels,
            duration_seconds,
            metadata,
        })
    }

    fn extract_metadata(reader: &mut Box<dyn FormatReader>, duration: f64) -> TrackMetadata {
        let mut title = None;
        let mut artist = None;
        let mut album = None;

        if let Some(metadata) = reader.metadata().current() {
            for tag in metadata.tags() {
                match tag.std_key {
                    Some(symphonia::core::meta::StandardTagKey::TrackTitle) => {
                        title = Some(tag.value.to_string());
                    }
                    Some(symphonia::core::meta::StandardTagKey::Artist) => {
                        artist = Some(tag.value.to_string());
                    }
                    Some(symphonia::core::meta::StandardTagKey::Album) => {
                        album = Some(tag.value.to_string());
                    }
                    _ => {}
                }
            }
        }

        TrackMetadata {
            title,
            artist,
            album,
            duration_seconds: duration,
        }
    }

    /// Decode the next packet into interleaved f32 samples. Returns None at EOF.
    pub fn decode_next(&mut self) -> Option<Vec<f32>> {
        loop {
            let packet = match self.reader.next_packet() {
                Ok(p) => p,
                Err(_) => return None,
            };

            if packet.track_id() != self.track_id {
                continue;
            }

            match self.decoder.decode(&packet) {
                Ok(decoded) => {
                    let spec = *decoded.spec();
                    let num_frames = decoded.capacity();
                    let mut sample_buf = SampleBuffer::<f32>::new(num_frames as u64, spec);
                    sample_buf.copy_interleaved_ref(decoded);
                    return Some(sample_buf.samples().to_vec());
                }
                Err(symphonia::core::errors::Error::DecodeError(_)) => {
                    // Skip corrupt packets
                    continue;
                }
                Err(_) => return None,
            }
        }
    }

    pub fn seek(&mut self, seconds: f64) {
        let _ = self.reader.seek(
            SeekMode::Accurate,
            SeekTo::Time {
                time: Time::from(seconds),
                track_id: Some(self.track_id),
            },
        );
        self.decoder.reset();
    }

    pub fn duration(&self) -> Option<f64> {
        self.duration_seconds
    }

    pub fn sample_rate(&self) -> u32 {
        self.sample_rate
    }

    pub fn channels(&self) -> u16 {
        self.channels
    }

    pub fn metadata(&self) -> TrackMetadata {
        self.metadata.clone()
    }
}
