#ifndef AUTO_TECHNO_WINDOWS_PLATFORM_H
#define AUTO_TECHNO_WINDOWS_PLATFORM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*ATWindowsStartedCallback)(void *context, uint32_t sample_rate);
typedef void (*ATWindowsTransportCallback)(void *context);
typedef void (*ATWindowsTickCallback)(void *context, uint64_t played_frames);

enum ATWindowsPlaybackState {
    AT_WINDOWS_PREPARING = 0,
    AT_WINDOWS_READY = 1,
    AT_WINDOWS_PLAYING = 2,
    AT_WINDOWS_PAUSED = 3,
    AT_WINDOWS_RECOVERING = 4,
    AT_WINDOWS_UNAVAILABLE = 5,
};

/// Creates the one-button window, opens the default output device, calls
/// `started`, and runs the UI message loop until the window closes. A zero
/// sample rate means that no supported output format could be opened.
int32_t at_windows_run(
    void *context,
    ATWindowsStartedCallback started,
    ATWindowsTransportCallback transport,
    ATWindowsTickCallback tick
);

/// Copies immutable stereo PCM into a platform-owned buffer and queues it for
/// sequential playback. Allocation and conversion happen on the caller's
/// scheduling queue, never in the waveOut completion callback.
int32_t at_windows_audio_submit(
    const float *left,
    const float *right,
    uint32_t frame_count
);

int32_t at_windows_audio_start(void);
int32_t at_windows_audio_pause(void);
int32_t at_windows_audio_resume(void);
uint32_t at_windows_audio_queued_buffer_count(void);
void at_windows_audio_request_recovery(void);

void at_windows_ui_set_state(int32_t state);
void at_windows_ui_set_position(int32_t phrase, int32_t bar, int32_t bpm);
void at_windows_ui_set_waveform(const float *samples, uint32_t sample_count);
void at_windows_ui_set_playhead(double playhead);

#ifdef __cplusplus
}
#endif

#endif
