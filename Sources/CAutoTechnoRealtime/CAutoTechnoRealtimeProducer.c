#include "CAutoTechnoRealtimePrivate.h"

#include <stddef.h>
#include <string.h>

bool ATLivePCMQueueProduceNativeStereo(
    ATLivePCMQueue *queue,
    int64_t firstMixerSample,
    const float *left,
    const float *right,
    uint32_t frameCount
) {
    if (queue == NULL) {
        return false;
    }
    if (left == NULL || right == NULL || frameCount == 0 ||
        frameCount > AT_LIVE_PCM_MAX_FRAMES) {
        atomic_fetch_add_explicit(
            &queue->rejectedPacketCount,
            1ULL,
            memory_order_relaxed
        );
        return false;
    }

    const unsigned long long writeSequence = atomic_load_explicit(
        &queue->writeSequence,
        memory_order_relaxed
    );
    const unsigned long long readSequence = atomic_load_explicit(
        &queue->readSequence,
        memory_order_acquire
    );
    if (writeSequence - readSequence >= AT_LIVE_PCM_CAPACITY) {
        atomic_fetch_add_explicit(
            &queue->droppedPacketCount,
            1ULL,
            memory_order_relaxed
        );
        return false;
    }

    ATLivePCMSlot *slot = &queue->slots[writeSequence % AT_LIVE_PCM_CAPACITY];
    const unsigned long long generationWord = atomic_load_explicit(
        &queue->generationWord,
        memory_order_acquire
    );
    const size_t byteCount = (size_t)frameCount * sizeof(float);

    slot->metadata.packetSequence = writeSequence;
    slot->metadata.firstMixerSample = firstMixerSample;
    slot->metadata.frameCount = frameCount;
    slot->metadata.routeGeneration = (uint32_t)(generationWord >> 32);
    slot->metadata.controllerRevision = (uint32_t)generationWord;
    memcpy(slot->left, left, byteCount);
    memcpy(slot->right, right, byteCount);

    atomic_store_explicit(
        &queue->writeSequence,
        writeSequence + 1ULL,
        memory_order_release
    );
    return true;
}
