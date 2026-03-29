/// AudioOutputStream — UniFFI-exported raw PCM output.
/// Accepts interleaved f32 samples from Swift (or any FFI caller) and plays
/// them through cpal. Used by Clone's CoreAudio SDK to provide audio output
/// for apps like the video player (libvlc amem → CoreAudio → this).

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use parking_lot::Mutex;
use ringbuf::traits::Producer;

use crate::ffi::AudioError;
use crate::output::{AudioOutput, RingProducer};

#[derive(uniffi::Object)]
pub struct AudioOutputStream {
    output: Mutex<Option<AudioOutput>>,
    producer: Mutex<Option<RingProducer>>,
    playing: AtomicBool,
    volume: Arc<Mutex<f32>>,
    sample_rate: u32,
    channels: u16,
}

#[uniffi::export]
impl AudioOutputStream {
    /// Create a new PCM output stream.
    /// Audio won't play until `play()` is called.
    #[uniffi::constructor]
    pub fn new(sample_rate: u32, channels: u16) -> Result<Arc<Self>, AudioError> {
        let volume = Arc::new(Mutex::new(1.0));
        let (output, producer) = AudioOutput::new(sample_rate, channels, volume.clone())?;

        Ok(Arc::new(Self {
            output: Mutex::new(Some(output)),
            producer: Mutex::new(Some(producer)),
            playing: AtomicBool::new(false),
            volume,
            sample_rate,
            channels,
        }))
    }

    /// Push interleaved f32 samples into the ring buffer.
    /// Returns the number of samples actually written (may be less than
    /// input length if the buffer is full — caller should retry).
    pub fn write(&self, samples: Vec<f32>) -> u32 {
        let mut guard = self.producer.lock();
        let Some(producer) = guard.as_mut() else {
            return 0;
        };
        producer.push_slice(&samples) as u32
    }

    pub fn play(&self) {
        if let Some(out) = self.output.lock().as_ref() {
            out.play();
        }
        self.playing.store(true, Ordering::Relaxed);
    }

    pub fn pause(&self) {
        if let Some(out) = self.output.lock().as_ref() {
            out.pause();
        }
        self.playing.store(false, Ordering::Relaxed);
    }

    pub fn stop(&self) {
        if let Some(out) = self.output.lock().as_ref() {
            out.stop();
        }
        self.playing.store(false, Ordering::Relaxed);
        // Drop the stream and producer
        *self.output.lock() = None;
        *self.producer.lock() = None;
    }

    pub fn set_volume(&self, volume: f32) {
        *self.volume.lock() = volume.clamp(0.0, 1.0);
    }

    pub fn volume(&self) -> f32 {
        *self.volume.lock()
    }

    pub fn is_playing(&self) -> bool {
        self.playing.load(Ordering::Relaxed)
    }

    pub fn sample_rate(&self) -> u32 {
        self.sample_rate
    }

    pub fn channels(&self) -> u16 {
        self.channels
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn write_returns_zero_after_stop() {
        let stream = AudioOutputStream::new(44100, 2).unwrap();
        stream.stop();
        let written = stream.write(vec![0.0; 100]);
        assert_eq!(written, 0);
    }
}
