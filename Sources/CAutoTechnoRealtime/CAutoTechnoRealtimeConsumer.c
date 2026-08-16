#include "CAutoTechnoRealtimePrivate.h"

#include <stddef.h>
#include <string.h>

bool ATLivePCMQueueConsume(
    ATLivePCMQueue *queue,
    ATLivePCMPacketMetadata *metadata,
    float *left,
    float *right,
    uint32_t outputCapacity
) {
    if (queue == NULL || metadata == NULL || left == NULL || right == NULL) {
        return false;
    }

    const unsigned long long readSequence = atomic_load_explicit(
        &queue->readSequence,
        memory_order_relaxed
    );
    const unsigned long long writeSequence = atomic_load_explicit(
        &queue->writeSequence,
        memory_order_acquire
    );
    if (readSequence == writeSequence) {
        return false;
    }

    const ATLivePCMSlot *slot = &queue->slots[readSequence % AT_LIVE_PCM_CAPACITY];
    if (outputCapacity < slot->metadata.frameCount) {
        return false;
    }

    const size_t byteCount = (size_t)slot->metadata.frameCount * sizeof(float);
    *metadata = slot->metadata;
    memcpy(left, slot->left, byteCount);
    memcpy(right, slot->right, byteCount);

    atomic_store_explicit(
        &queue->readSequence,
        readSequence + 1ULL,
        memory_order_release
    );
    return true;
}
