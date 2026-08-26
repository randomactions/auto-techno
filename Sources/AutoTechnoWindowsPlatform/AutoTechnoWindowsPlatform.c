#include "AutoTechnoWindowsPlatform.h"

#ifdef _WIN32

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <mmsystem.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define AT_WINDOW_CLASS L"AutoTechnoWindowClass"
#define AT_WINDOW_TITLE L"Auto Techno"
#define AT_TIMER_ID 130
#define AT_TIMER_MS 66
#define AT_WAVEFORM_CAPACITY 64
#define AT_WM_STATE (WM_APP + 1)
#define AT_WM_POSITION (WM_APP + 2)
#define AT_WM_WAVEFORM (WM_APP + 3)
#define AT_WM_PLAYHEAD (WM_APP + 4)
#define AT_WM_RECOVER_AUDIO (WM_APP + 5)
#define AT_TRANSPORT_ID 1001

typedef struct ATAudioBufferNode {
    WAVEHDR header;
    void *samples;
    uint32_t frame_count;
    volatile LONG completed;
    struct ATAudioBufferNode *next;
} ATAudioBufferNode;

typedef struct ATWaveformPayload {
    uint32_t count;
    float samples[AT_WAVEFORM_CAPACITY];
} ATWaveformPayload;

static HWND g_window = NULL;
static HWND g_status = NULL;
static HWND g_position = NULL;
static HWND g_transport = NULL;
static HFONT g_title_font = NULL;
static HFONT g_status_font = NULL;
static HFONT g_button_font = NULL;
static HBRUSH g_background_brush = NULL;

static void *g_context = NULL;
static ATWindowsStartedCallback g_started_callback = NULL;
static ATWindowsTransportCallback g_transport_callback = NULL;
static ATWindowsTickCallback g_tick_callback = NULL;

static HWAVEOUT g_wave_out = NULL;
static WAVEFORMATEX g_wave_format;
static int g_float_output = 0;
static CRITICAL_SECTION g_audio_lock;
static int g_audio_lock_initialized = 0;
static ATAudioBufferNode *g_audio_buffers = NULL;
static volatile LONG g_queued_buffer_count = 0;
static volatile LONG64 g_completed_frames = 0;
static uint32_t g_last_device_position = 0;
static uint64_t g_device_position_wrap_base = 0;

static float g_waveform[AT_WAVEFORM_CAPACITY];
static uint32_t g_waveform_count = AT_WAVEFORM_CAPACITY;
static volatile LONG64 g_playhead_bits = 0;
static int32_t g_playback_state = AT_WINDOWS_PREPARING;

static void at_collect_completed_buffers(void);

static uint64_t at_double_bits(double value) {
    uint64_t bits = 0;
    memcpy(&bits, &value, sizeof(bits));
    return bits;
}

static double at_bits_double(uint64_t bits) {
    double value = 0;
    memcpy(&value, &bits, sizeof(value));
    return value;
}

static void CALLBACK at_wave_out_callback(
    HWAVEOUT output,
    UINT message,
    DWORD_PTR instance,
    DWORD_PTR parameter1,
    DWORD_PTR parameter2
) {
    (void)output;
    (void)instance;
    (void)parameter2;
    if (message != WOM_DONE || parameter1 == 0) {
        return;
    }

    // This is the only app-owned function that can execute on the waveOut
    // completion thread. It performs two fixed-size atomic updates and no
    // allocation, lock, wait, analysis, logging, I/O, UI, or scheduling work.
    ATAudioBufferNode *node = (ATAudioBufferNode *)parameter1;
    if (InterlockedExchange(&node->completed, 1) == 0) {
        InterlockedAdd64(&g_completed_frames, (LONG64)node->frame_count);
        InterlockedDecrement(&g_queued_buffer_count);
    }
}

static void at_remove_audio_node(ATAudioBufferNode *node) {
    ATAudioBufferNode **cursor = &g_audio_buffers;
    while (*cursor != NULL) {
        if (*cursor == node) {
            *cursor = node->next;
            return;
        }
        cursor = &(*cursor)->next;
    }
}

static void at_collect_completed_buffers(void) {
    if (!g_audio_lock_initialized || g_wave_out == NULL) {
        return;
    }

    EnterCriticalSection(&g_audio_lock);
    ATAudioBufferNode **cursor = &g_audio_buffers;
    while (*cursor != NULL) {
        ATAudioBufferNode *node = *cursor;
        if (InterlockedCompareExchange(&node->completed, 0, 0) == 0) {
            cursor = &node->next;
            continue;
        }
        if (waveOutUnprepareHeader(g_wave_out, &node->header, sizeof(WAVEHDR)) != MMSYSERR_NOERROR) {
            cursor = &node->next;
            continue;
        }
        *cursor = node->next;
        free(node->samples);
        free(node);
    }
    LeaveCriticalSection(&g_audio_lock);
}

static MMRESULT at_try_open_audio(uint32_t sample_rate, int float_output) {
    memset(&g_wave_format, 0, sizeof(g_wave_format));
    g_wave_format.wFormatTag = float_output ? WAVE_FORMAT_IEEE_FLOAT : WAVE_FORMAT_PCM;
    g_wave_format.nChannels = 2;
    g_wave_format.nSamplesPerSec = sample_rate;
    g_wave_format.wBitsPerSample = float_output ? 32 : 16;
    g_wave_format.nBlockAlign = (WORD)(g_wave_format.nChannels * g_wave_format.wBitsPerSample / 8);
    g_wave_format.nAvgBytesPerSec = g_wave_format.nSamplesPerSec * g_wave_format.nBlockAlign;
    g_wave_format.cbSize = 0;

    MMRESULT result = waveOutOpen(
        &g_wave_out,
        WAVE_MAPPER,
        &g_wave_format,
        (DWORD_PTR)at_wave_out_callback,
        0,
        CALLBACK_FUNCTION
    );
    if (result == MMSYSERR_NOERROR) {
        g_float_output = float_output;
        // The queue is prepared before playback so the device starts with
        // deterministic lookahead rather than an empty callback.
        waveOutPause(g_wave_out);
    }
    return result;
}

static uint32_t at_open_audio(void) {
    InterlockedExchange64(&g_completed_frames, 0);
    InterlockedExchange(&g_queued_buffer_count, 0);
    g_last_device_position = 0;
    g_device_position_wrap_base = 0;
    const uint32_t sample_rates[] = {48000, 44100};
    for (size_t index = 0; index < sizeof(sample_rates) / sizeof(sample_rates[0]); ++index) {
        if (at_try_open_audio(sample_rates[index], 1) == MMSYSERR_NOERROR) {
            return sample_rates[index];
        }
        g_wave_out = NULL;
        if (at_try_open_audio(sample_rates[index], 0) == MMSYSERR_NOERROR) {
            return sample_rates[index];
        }
        g_wave_out = NULL;
    }
    return 0;
}

static void at_shutdown_audio(void) {
    if (g_wave_out == NULL) {
        return;
    }

    waveOutReset(g_wave_out);
    for (int attempt = 0; attempt < 20; ++attempt) {
        at_collect_completed_buffers();
        if (g_audio_buffers == NULL) {
            break;
        }
        Sleep(5);
    }

    EnterCriticalSection(&g_audio_lock);
    ATAudioBufferNode *node = g_audio_buffers;
    while (node != NULL) {
        ATAudioBufferNode *next = node->next;
        waveOutUnprepareHeader(g_wave_out, &node->header, sizeof(WAVEHDR));
        free(node->samples);
        free(node);
        node = next;
    }
    g_audio_buffers = NULL;
    LeaveCriticalSection(&g_audio_lock);

    waveOutClose(g_wave_out);
    g_wave_out = NULL;
    InterlockedExchange(&g_queued_buffer_count, 0);
    InterlockedExchange64(&g_completed_frames, 0);
    g_last_device_position = 0;
    g_device_position_wrap_base = 0;
}

static uint64_t at_played_frames(void) {
    if (g_wave_out == NULL) {
        return 0;
    }
    MMTIME position;
    memset(&position, 0, sizeof(position));
    position.wType = TIME_SAMPLES;
    if (waveOutGetPosition(g_wave_out, &position, sizeof(position)) == MMSYSERR_NOERROR &&
        position.wType == TIME_SAMPLES) {
        uint32_t current = position.u.sample;
        if (current < g_last_device_position &&
            g_last_device_position - current > UINT32_MAX / 2) {
            g_device_position_wrap_base += (UINT64_C(1) << 32);
        }
        g_last_device_position = current;
        return g_device_position_wrap_base + current;
    }
    return (uint64_t)InterlockedCompareExchange64(&g_completed_frames, 0, 0);
}

static void at_set_control_font(HWND control, HFONT font) {
    if (control != NULL && font != NULL) {
        SendMessageW(control, WM_SETFONT, (WPARAM)font, TRUE);
    }
}

static void at_layout_controls(HWND window) {
    RECT client;
    GetClientRect(window, &client);
    int width = client.right - client.left;
    int height = client.bottom - client.top;
    int center_x = width / 2;

    MoveWindow(g_status, center_x - 190, 54, 380, 46, TRUE);
    MoveWindow(g_position, center_x - 220, height - 88, 440, 28, TRUE);
    MoveWindow(g_transport, center_x - 64, height / 2 - 18, 128, 72, TRUE);
}

static void at_apply_state(int32_t state) {
    g_playback_state = state;
    const wchar_t *status = L"BUILDING THE PERFORMANCE";
    const wchar_t *button = L"PLAY";
    BOOL enabled = TRUE;
    switch (state) {
        case AT_WINDOWS_READY:
            status = L"READY";
            break;
        case AT_WINDOWS_PLAYING:
            status = L"LIVE";
            button = L"PAUSE";
            break;
        case AT_WINDOWS_PAUSED:
            status = L"PAUSED";
            break;
        case AT_WINDOWS_RECOVERING:
            status = L"RECOVERING AUDIO";
            enabled = FALSE;
            break;
        case AT_WINDOWS_UNAVAILABLE:
            status = L"AUDIO UNAVAILABLE";
            button = L"RETRY";
            break;
        case AT_WINDOWS_PREPARING:
        default:
            status = L"BUILDING THE PERFORMANCE";
            button = L"PREPARING";
            enabled = FALSE;
            break;
    }
    SetWindowTextW(g_status, status);
    SetWindowTextW(g_transport, button);
    EnableWindow(g_transport, enabled);
    InvalidateRect(g_window, NULL, FALSE);
}

static void at_draw_waveform(HDC device, const RECT *client) {
    int width = client->right - client->left;
    int height = client->bottom - client->top;
    int left = max(44, width / 2 - 260);
    int right = min(width - 44, width / 2 + 260);
    int top = max(118, height / 2 - 118);
    int bottom = min(height - 126, top + 116);
    int center = (top + bottom) / 2;
    int available = max(1, right - left);
    double playhead = at_bits_double((uint64_t)InterlockedCompareExchange64(&g_playhead_bits, 0, 0));
    int progress_x = left + (int)(available * max(0.0, min(1.0, playhead)));

    HBRUSH inactive = CreateSolidBrush(RGB(61, 62, 72));
    HBRUSH active = CreateSolidBrush(RGB(151, 71, 255));
    for (uint32_t index = 0; index < g_waveform_count; ++index) {
        float sample = g_waveform[index];
        if (!isfinite(sample)) sample = 0.04f;
        sample = max(0.04f, min(1.0f, sample));
        int x0 = left + (int)((double)index * available / g_waveform_count);
        int x1 = left + (int)((double)(index + 1) * available / g_waveform_count);
        int half = max(2, (int)(sample * (bottom - top) * 0.43));
        RECT bar = {x0 + 1, center - half, max(x0 + 3, x1 - 2), center + half};
        FillRect(device, &bar, (x0 <= progress_x && g_playback_state == AT_WINDOWS_PLAYING) ? active : inactive);
    }
    DeleteObject(inactive);
    DeleteObject(active);
}

static LRESULT CALLBACK at_window_proc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
    switch (message) {
        case WM_CREATE: {
            g_window = window;
            g_status = CreateWindowExW(
                0, L"STATIC", L"BUILDING THE PERFORMANCE",
                WS_CHILD | WS_VISIBLE | SS_CENTER,
                0, 0, 100, 30, window, NULL, GetModuleHandleW(NULL), NULL
            );
            g_position = CreateWindowExW(
                0, L"STATIC", L"130 BPM · PHRASE 1 · BAR 1",
                WS_CHILD | WS_VISIBLE | SS_CENTER,
                0, 0, 100, 24, window, NULL, GetModuleHandleW(NULL), NULL
            );
            g_transport = CreateWindowExW(
                0, L"BUTTON", L"PREPARING",
                WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
                0, 0, 100, 64, window, (HMENU)(INT_PTR)AT_TRANSPORT_ID,
                GetModuleHandleW(NULL), NULL
            );
            at_set_control_font(g_status, g_status_font);
            at_set_control_font(g_position, g_status_font);
            at_set_control_font(g_transport, g_button_font);
            at_apply_state(AT_WINDOWS_PREPARING);
            return 0;
        }
        case WM_SIZE:
            at_layout_controls(window);
            return 0;
        case WM_COMMAND:
            if (LOWORD(wparam) == AT_TRANSPORT_ID && HIWORD(wparam) == BN_CLICKED &&
                g_transport_callback != NULL) {
                g_transport_callback(g_context);
                return 0;
            }
            break;
        case WM_TIMER:
            if (wparam == AT_TIMER_ID) {
                at_collect_completed_buffers();
                if (g_tick_callback != NULL) {
                    g_tick_callback(g_context, at_played_frames());
                }
                return 0;
            }
            break;
        case AT_WM_STATE:
            at_apply_state((int32_t)wparam);
            return 0;
        case AT_WM_POSITION: {
            wchar_t text[96];
            int32_t phrase = (int32_t)wparam;
            int32_t bar = (int32_t)LOWORD(lparam);
            int32_t bpm = (int32_t)HIWORD(lparam);
            _snwprintf_s(text, sizeof(text) / sizeof(text[0]), _TRUNCATE,
                L"%d BPM · PHRASE %d · BAR %d", bpm, phrase, bar);
            SetWindowTextW(g_position, text);
            return 0;
        }
        case AT_WM_WAVEFORM: {
            ATWaveformPayload *payload = (ATWaveformPayload *)lparam;
            if (payload != NULL) {
                g_waveform_count = min(payload->count, (uint32_t)AT_WAVEFORM_CAPACITY);
                memcpy(g_waveform, payload->samples, g_waveform_count * sizeof(float));
                free(payload);
                InvalidateRect(window, NULL, FALSE);
            }
            return 0;
        }
        case AT_WM_PLAYHEAD:
            InvalidateRect(window, NULL, FALSE);
            return 0;
        case AT_WM_RECOVER_AUDIO: {
            at_shutdown_audio();
            uint32_t sample_rate = at_open_audio();
            if (g_started_callback != NULL) {
                g_started_callback(g_context, sample_rate);
            }
            return 0;
        }
        case WM_CTLCOLORSTATIC: {
            HDC device = (HDC)wparam;
            SetBkMode(device, TRANSPARENT);
            SetTextColor(device, (HWND)lparam == g_status ? RGB(161, 102, 255) : RGB(166, 166, 176));
            return (LRESULT)g_background_brush;
        }
        case WM_ERASEBKGND: {
            RECT client;
            GetClientRect(window, &client);
            FillRect((HDC)wparam, &client, g_background_brush);
            return 1;
        }
        case WM_PAINT: {
            PAINTSTRUCT paint;
            HDC device = BeginPaint(window, &paint);
            RECT client;
            GetClientRect(window, &client);
            SetBkMode(device, TRANSPARENT);
            SetTextColor(device, RGB(244, 244, 248));
            SelectObject(device, g_title_font);
            RECT title = {0, 20, client.right, 56};
            DrawTextW(device, L"AUTO TECHNO", -1, &title, DT_CENTER | DT_SINGLELINE);
            at_draw_waveform(device, &client);
            EndPaint(window, &paint);
            return 0;
        }
        case WM_CLOSE:
            DestroyWindow(window);
            return 0;
        case WM_DESTROY:
            KillTimer(window, AT_TIMER_ID);
            PostQuitMessage(0);
            return 0;
        default:
            break;
    }
    return DefWindowProcW(window, message, wparam, lparam);
}

int32_t at_windows_run(
    void *context,
    ATWindowsStartedCallback started,
    ATWindowsTransportCallback transport,
    ATWindowsTickCallback tick
) {
    SetProcessDPIAware();
    g_context = context;
    g_started_callback = started;
    g_transport_callback = transport;
    g_tick_callback = tick;
    for (uint32_t index = 0; index < AT_WAVEFORM_CAPACITY; ++index) {
        g_waveform[index] = 0.04f;
    }

    InitializeCriticalSection(&g_audio_lock);
    g_audio_lock_initialized = 1;
    g_background_brush = CreateSolidBrush(RGB(5, 5, 7));
    g_title_font = CreateFontW(30, 0, 0, 0, FW_HEAVY, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
        DEFAULT_PITCH | FF_SWISS, L"Segoe UI");
    g_status_font = CreateFontW(15, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
        DEFAULT_PITCH | FF_MODERN, L"Consolas");
    g_button_font = CreateFontW(18, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
        DEFAULT_PITCH | FF_SWISS, L"Segoe UI");

    HINSTANCE instance = GetModuleHandleW(NULL);
    WNDCLASSEXW window_class;
    memset(&window_class, 0, sizeof(window_class));
    window_class.cbSize = sizeof(window_class);
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.lpfnWndProc = at_window_proc;
    window_class.hInstance = instance;
    window_class.hCursor = LoadCursorW(NULL, IDC_ARROW);
    window_class.hbrBackground = g_background_brush;
    window_class.lpszClassName = AT_WINDOW_CLASS;
    if (RegisterClassExW(&window_class) == 0) {
        return 1;
    }

    g_window = CreateWindowExW(
        0, AT_WINDOW_CLASS, AT_WINDOW_TITLE,
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        CW_USEDEFAULT, CW_USEDEFAULT, 660, 500,
        NULL, NULL, instance, NULL
    );
    if (g_window == NULL) {
        return 2;
    }
    ShowWindow(g_window, SW_SHOWDEFAULT);
    UpdateWindow(g_window);
    SetTimer(g_window, AT_TIMER_ID, AT_TIMER_MS, NULL);

    uint32_t sample_rate = at_open_audio();
    if (sample_rate == 0) {
        at_apply_state(AT_WINDOWS_UNAVAILABLE);
    }
    if (started != NULL) {
        started(context, sample_rate);
    }

    MSG message;
    while (GetMessageW(&message, NULL, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }

    at_shutdown_audio();
    if (g_title_font != NULL) DeleteObject(g_title_font);
    if (g_status_font != NULL) DeleteObject(g_status_font);
    if (g_button_font != NULL) DeleteObject(g_button_font);
    if (g_background_brush != NULL) DeleteObject(g_background_brush);
    DeleteCriticalSection(&g_audio_lock);
    g_audio_lock_initialized = 0;
    g_window = NULL;
    return (int32_t)message.wParam;
}

int32_t at_windows_audio_submit(const float *left, const float *right, uint32_t frame_count) {
    if (g_wave_out == NULL || left == NULL || right == NULL || frame_count == 0) {
        return 0;
    }

    ATAudioBufferNode *node = (ATAudioBufferNode *)calloc(1, sizeof(ATAudioBufferNode));
    if (node == NULL) {
        return 0;
    }
    node->frame_count = frame_count;

    if (g_float_output) {
        float *samples = (float *)malloc((size_t)frame_count * 2 * sizeof(float));
        if (samples == NULL) {
            free(node);
            return 0;
        }
        for (uint32_t frame = 0; frame < frame_count; ++frame) {
            samples[frame * 2] = isfinite(left[frame]) ? left[frame] : 0.0f;
            samples[frame * 2 + 1] = isfinite(right[frame]) ? right[frame] : 0.0f;
        }
        node->samples = samples;
    } else {
        int16_t *samples = (int16_t *)malloc((size_t)frame_count * 2 * sizeof(int16_t));
        if (samples == NULL) {
            free(node);
            return 0;
        }
        for (uint32_t frame = 0; frame < frame_count; ++frame) {
            float l = isfinite(left[frame]) ? max(-1.0f, min(1.0f, left[frame])) : 0.0f;
            float r = isfinite(right[frame]) ? max(-1.0f, min(1.0f, right[frame])) : 0.0f;
            samples[frame * 2] = (int16_t)lrintf(l * 32767.0f);
            samples[frame * 2 + 1] = (int16_t)lrintf(r * 32767.0f);
        }
        node->samples = samples;
    }

    node->header.lpData = (LPSTR)node->samples;
    node->header.dwBufferLength = frame_count * g_wave_format.nBlockAlign;
    if (waveOutPrepareHeader(g_wave_out, &node->header, sizeof(WAVEHDR)) != MMSYSERR_NOERROR) {
        free(node->samples);
        free(node);
        return 0;
    }

    EnterCriticalSection(&g_audio_lock);
    node->next = g_audio_buffers;
    g_audio_buffers = node;
    LeaveCriticalSection(&g_audio_lock);
    InterlockedIncrement(&g_queued_buffer_count);

    if (waveOutWrite(g_wave_out, &node->header, sizeof(WAVEHDR)) != MMSYSERR_NOERROR) {
        InterlockedDecrement(&g_queued_buffer_count);
        EnterCriticalSection(&g_audio_lock);
        at_remove_audio_node(node);
        LeaveCriticalSection(&g_audio_lock);
        waveOutUnprepareHeader(g_wave_out, &node->header, sizeof(WAVEHDR));
        free(node->samples);
        free(node);
        return 0;
    }
    return 1;
}

int32_t at_windows_audio_start(void) {
    return g_wave_out != NULL && waveOutRestart(g_wave_out) == MMSYSERR_NOERROR;
}

int32_t at_windows_audio_pause(void) {
    return g_wave_out != NULL && waveOutPause(g_wave_out) == MMSYSERR_NOERROR;
}

int32_t at_windows_audio_resume(void) {
    return at_windows_audio_start();
}

uint32_t at_windows_audio_queued_buffer_count(void) {
    LONG count = InterlockedCompareExchange(&g_queued_buffer_count, 0, 0);
    return count > 0 ? (uint32_t)count : 0;
}

void at_windows_audio_request_recovery(void) {
    HWND window = g_window;
    if (window != NULL) {
        PostMessageW(window, AT_WM_RECOVER_AUDIO, 0, 0);
    }
}

void at_windows_ui_set_state(int32_t state) {
    HWND window = g_window;
    if (window != NULL) {
        PostMessageW(window, AT_WM_STATE, (WPARAM)state, 0);
    }
}

void at_windows_ui_set_position(int32_t phrase, int32_t bar, int32_t bpm) {
    HWND window = g_window;
    if (window != NULL) {
        LPARAM packed = MAKELPARAM((WORD)max(0, bar), (WORD)max(0, bpm));
        PostMessageW(window, AT_WM_POSITION, (WPARAM)max(0, phrase), packed);
    }
}

void at_windows_ui_set_waveform(const float *samples, uint32_t sample_count) {
    HWND window = g_window;
    if (window == NULL || samples == NULL || sample_count == 0) {
        return;
    }
    ATWaveformPayload *payload = (ATWaveformPayload *)calloc(1, sizeof(ATWaveformPayload));
    if (payload == NULL) {
        return;
    }
    payload->count = min(sample_count, (uint32_t)AT_WAVEFORM_CAPACITY);
    memcpy(payload->samples, samples, payload->count * sizeof(float));
    if (!PostMessageW(window, AT_WM_WAVEFORM, 0, (LPARAM)payload)) {
        free(payload);
    }
}

void at_windows_ui_set_playhead(double playhead) {
    double bounded = max(0.0, min(1.0, playhead));
    InterlockedExchange64(&g_playhead_bits, (LONG64)at_double_bits(bounded));
    HWND window = g_window;
    if (window != NULL) {
        PostMessageW(window, AT_WM_PLAYHEAD, 0, 0);
    }
}

#else

int32_t at_windows_run(
    void *context,
    ATWindowsStartedCallback started,
    ATWindowsTransportCallback transport,
    ATWindowsTickCallback tick
) {
    (void)transport;
    (void)tick;
    if (started != 0) {
        started(context, 0);
    }
    return 0;
}

int32_t at_windows_audio_submit(const float *left, const float *right, uint32_t frame_count) {
    (void)left;
    (void)right;
    (void)frame_count;
    return 0;
}

int32_t at_windows_audio_start(void) { return 0; }
int32_t at_windows_audio_pause(void) { return 0; }
int32_t at_windows_audio_resume(void) { return 0; }
uint32_t at_windows_audio_queued_buffer_count(void) { return 0; }
void at_windows_audio_request_recovery(void) {}
void at_windows_ui_set_state(int32_t state) { (void)state; }
void at_windows_ui_set_position(int32_t phrase, int32_t bar, int32_t bpm) {
    (void)phrase;
    (void)bar;
    (void)bpm;
}
void at_windows_ui_set_waveform(const float *samples, uint32_t sample_count) {
    (void)samples;
    (void)sample_count;
}
void at_windows_ui_set_playhead(double playhead) { (void)playhead; }

#endif
