#ifndef C_AUTO_TECHNO_REALTIME_H
#define C_AUTO_TECHNO_REALTIME_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define AT_LIVE_PCM_MAX_FRAMES 1024u
#define AT_LIVE_PCM_CAPACITY 256u
#define AT_LIVE_PCM_QUEUE_ALIGNMENT 64u

typedef struct ATLivePCMQueue ATLivePCMQueue;

typedef struct {
    uint64_t packetSequence;
    int64_t firstMixerSample;
    uint32_t frameCount;
    uint32_t routeGeneration;
    uint32_t controllerRevision;
} ATLivePCMPacketMetadata;

/*
 Queue ownership and lifecycle preconditions:

 - Creation, generation updates, and destruction are control-thread work, not
   producer-callback work.
 - Exactly one producer may call ATLivePCMQueueProduceNativeStereo, and exactly
   one consumer may call ATLivePCMQueueConsume.
 - Exactly one lifecycle owner may call ATLivePCMQueueSetGeneration while the
   queue is alive. It may update concurrently with the producer; each published
   packet captures either the complete old or complete new generation pair.
 - The producer, consumer, and generation writer must all be stopped before
   ATLivePCMQueueDestroy is called.
 */
ATLivePCMQueue *ATLivePCMQueueCreate(void);
void ATLivePCMQueueDestroy(ATLivePCMQueue *queue);

void ATLivePCMQueueSetGeneration(
    ATLivePCMQueue *queue,
    uint32_t routeGeneration,
    uint32_t controllerRevision
);

bool ATLivePCMQueueProduceNativeStereo(
    ATLivePCMQueue *queue,
    int64_t firstMixerSample,
    const float *left,
    const float *right,
    uint32_t frameCount
);

bool ATLivePCMQueueConsume(
    ATLivePCMQueue *queue,
    ATLivePCMPacketMetadata *metadata,
    float *left,
    float *right,
    uint32_t outputCapacity
);

uint64_t ATLivePCMQueueDroppedPacketCount(const ATLivePCMQueue *queue);
uint64_t ATLivePCMQueueRejectedPacketCount(const ATLivePCMQueue *queue);

#ifdef __cplusplus
}
#endif

#endif
