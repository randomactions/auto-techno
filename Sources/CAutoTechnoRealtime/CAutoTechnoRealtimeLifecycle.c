#if !defined(_WIN32)
#define _POSIX_C_SOURCE 200112L
#endif

#include "CAutoTechnoRealtimePrivate.h"

#include <stdlib.h>
#include <string.h>
#if defined(_WIN32)
#include <malloc.h>
#endif

ATLivePCMQueue *ATLivePCMQueueCreate(void) {
#if defined(_WIN32)
    void *storage = _aligned_malloc(sizeof(ATLivePCMQueue), _Alignof(ATLivePCMQueue));
    if (storage == NULL) {
        return NULL;
    }
#else
    void *storage = NULL;
    const int allocationResult = posix_memalign(
        &storage,
        _Alignof(ATLivePCMQueue),
        sizeof(ATLivePCMQueue)
    );
    if (allocationResult != 0) {
        return NULL;
    }
#endif

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
#if defined(_WIN32)
    _aligned_free(queue);
#else
    free(queue);
#endif
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
