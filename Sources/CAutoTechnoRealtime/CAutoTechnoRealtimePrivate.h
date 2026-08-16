#ifndef C_AUTO_TECHNO_REALTIME_PRIVATE_H
#define C_AUTO_TECHNO_REALTIME_PRIVATE_H

#include "CAutoTechnoRealtime.h"

#include <limits.h>
#include <stdatomic.h>

_Static_assert(ATOMIC_LLONG_LOCK_FREE == 2,
               "live PCM sequence atomics must be lock-free");
_Static_assert(sizeof(uint64_t) == sizeof(unsigned long long),
               "live PCM sequence atomics require 64-bit unsigned long long");
_Static_assert(ULLONG_MAX == UINT64_MAX,
               "live PCM atomic words must represent every uint64_t value");

typedef struct {
    ATLivePCMPacketMetadata metadata;
    float left[AT_LIVE_PCM_MAX_FRAMES];
    float right[AT_LIVE_PCM_MAX_FRAMES];
} ATLivePCMSlot;

struct ATLivePCMQueue {
    _Alignas(AT_LIVE_PCM_QUEUE_ALIGNMENT) _Atomic unsigned long long writeSequence;
    _Alignas(AT_LIVE_PCM_QUEUE_ALIGNMENT) _Atomic unsigned long long readSequence;
    _Alignas(AT_LIVE_PCM_QUEUE_ALIGNMENT) _Atomic unsigned long long droppedPacketCount;
    _Atomic unsigned long long rejectedPacketCount;
    _Atomic unsigned long long generationWord;
    _Alignas(AT_LIVE_PCM_QUEUE_ALIGNMENT) ATLivePCMSlot slots[AT_LIVE_PCM_CAPACITY];
};

_Static_assert(_Alignof(ATLivePCMQueue) == AT_LIVE_PCM_QUEUE_ALIGNMENT,
               "live PCM queue alignment must match its public allocation contract");

static inline unsigned long long ATLivePCMGenerationWord(
    uint32_t routeGeneration,
    uint32_t controllerRevision
) {
    return ((unsigned long long)routeGeneration << 32) |
        (unsigned long long)controllerRevision;
}

#endif
