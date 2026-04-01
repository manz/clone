/// CPAL audio output stream. Internal — not UniFFI-exported.

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::Stream;
use ringbuf::traits::{Consumer, Split};
use ringbuf::HeapRb;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use crate::ffi::AudioError;

/// Producer half — the decode thread writes samples here.
pub type RingProducer = ringbuf::HeapProd<f32>;

/// Consumer half — CPAL callback reads from here.
type RingConsumer = ringbuf::HeapCons<f32>;

pub struct AudioOutput {
    stream: SendStream,
    playing: Arc<AtomicBool>,
}

/// CPAL's Stream is !Send on some platforms (CoreAudio property listener uses
/// a raw pointer). We only ever access it behind a Mutex from the thread that
/// created it or to call play/pause/drop, which is safe.
struct SendStream(Stream);

// SAFETY: CPAL's Stream is !Send on macOS because CoreAudio's property listener
// contains a raw pointer. We only access the stream through play/pause/drop
// behind a Mutex, and these operations are thread-safe in CoreAudio.
unsafe impl Send for SendStream {}
unsafe impl Sync for SendStream {}

impl AudioOutput {
    /// Create a new output stream. Returns (AudioOutput, RingProducer) so the
    /// caller can feed decoded samples into the ring buffer.
    pub fn new(
        sample_rate: u32,
        channels: u16,
        volume: Arc<parking_lot::Mutex<f32>>,
    ) -> Result<(Self, RingProducer), AudioError> {
        let host = cpal::default_host();
        let device = host.default_output_device().ok_or(AudioError::OutputDeviceFailed {
            reason: "no output device available".into(),
        })?;

        let config = cpal::StreamConfig {
            channels,
            sample_rate: sample_rate,
            buffer_size: cpal::BufferSize::Default,
        };

        // Ring buffer sized for ~200ms of audio at the given sample rate
        let buf_size = (sample_rate as usize) * (channels as usize) / 5;
        let rb = HeapRb::<f32>::new(buf_size.max(4096));
        let (producer, consumer) = rb.split();

        let playing = Arc::new(AtomicBool::new(false));
        let playing_flag = playing.clone();

        let stream = build_stream(device, config, consumer, volume, playing_flag)?;

        Ok((Self { stream: SendStream(stream), playing }, producer))
    }

    pub fn play(&self) {
        self.playing.store(true, Ordering::Relaxed);
        let _ = self.stream.0.play();
    }

    pub fn pause(&self) {
        self.playing.store(false, Ordering::Relaxed);
        let _ = self.stream.0.pause();
    }

    pub fn stop(&self) {
        self.playing.store(false, Ordering::Relaxed);
        let _ = self.stream.0.pause();
    }
}

fn build_stream(
    device: cpal::Device,
    config: cpal::StreamConfig,
    mut consumer: RingConsumer,
    volume: Arc<parking_lot::Mutex<f32>>,
    playing: Arc<AtomicBool>,
) -> Result<Stream, AudioError> {
    let stream = device
        .build_output_stream(
            &config,
            move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                if !playing.load(Ordering::Relaxed) {
                    data.fill(0.0);
                    return;
                }
                let vol = *volume.lock();
                let read = consumer.pop_slice(data);
                // Apply volume
                for sample in &mut data[..read] {
                    *sample *= vol;
                }
                // Fill remainder with silence
                data[read..].fill(0.0);
            },
            move |err| {
                log::error!("CPAL stream error: {err}");
            },
            None,
        )
        .map_err(|e| AudioError::OutputDeviceFailed {
            reason: e.to_string(),
        })?;

    Ok(stream)
}
