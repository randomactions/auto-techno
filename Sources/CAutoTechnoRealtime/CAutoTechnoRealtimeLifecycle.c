#define _POSIX_C_SOURCE 200112L

#include "CAutoTechnoRealtimePrivate.h"

#include <stdlib.h>
#include <string.h>

ATLivePCMQueue *ATLivePCMQueueCreate(void) {
    void *storage = NULL;
    const int allocationResult = posix_memalign(
        &storage,
        _Alignof(ATLivePCMQueue),
        sizeof(ATLivePCMQueue)
    );
    if (allocationResult != 0) {
        return NULL;
    }

    memset(storage, 0, sizeof(ATLivePCMQueue));
    ATLivePCMQueue *queue = storage;
    atomic_init(&queue->writeSequence, 0ULL);
    atomic_init(&queue->readSequence, 0ULL);
    atomic_init(&queue->droppedPacketCount, 0ULL);
    atomic_init(&queue->rejectedPacketCount, 0ULL);
    atomic_init(&queue->generationWord, 0ULL);
    return queue;
}

void ATLivePCMQueueDestroy(ATLivePCMQueue *queue) {
    free(queue);
}

size_t ATLivePCMQueueStorageByteCount(void) {
    return sizeof(ATLivePCMQueue);
}

void ATLivePCMQueueSetGeneration(
    ATLivePCMQueue *queue,
    uint32_t routeGeneration,
    uint32_t controllerRevision
) {
    if (queue == NULL) {
        return;
    }

    atomic_store_explicit(
        &queue->generationWord,
        ATLivePCMGenerationWord(routeGeneration, controllerRevision),
        memory_order_release
    );
}

uint64_t ATLivePCMQueueDroppedPacketCount(const ATLivePCMQueue *queue) {
    if (queue == NULL) {
        return 0;
    }
    return atomic_load_explicit(&queue->droppedPacketCount, memory_order_acquire);
}

uint64_t ATLivePCMQueueRejectedPacketCount(const ATLivePCMQueue *queue) {
    if (queue == NULL) {
        return 0;
    }
    return atomic_load_explicit(&queue->rejectedPacketCount, memory_order_acquire);
}
