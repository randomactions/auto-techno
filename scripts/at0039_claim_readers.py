"""Strict readers of existing algorithmic reports; parsing grants no execution authority.

Oracles and fault recipes come from the existing native test owners. This module
never renders, fits a cutoff, installs a profile or qualifies an item. Historical
reports keep their original source; caller authentication is a separate duty.
"""
import math
import re

from hosted_macos_verification import require

RATES = (44100, 48000)
ROOTS = {1: 'development', 6011: 'held-out-root'}
ENERGY = 'autotechno-collision-source-energy.v1'
KICK = 'autotechno-score-kick-fault-component.v1'
BASS = 'autotechno-foundation-bass-fault-component.v2'
COMPANION = 'autotechno-foundation-companion-fault-component.v1'
RELEASE = 'autotechno-foundation-release-fault-component.v2'
FULL_BASS = 'autotechno-full-phrase-bass-faults.v2'
FULL_COMPANION = 'autotechno-full-phrase-companion-faults.v1'
FULL_BEHAVIOR = 'autotechno-full-phrase-bass-behavior-faults.v1'
OUTPUT = 'autotechno-full-phrase-output-frame-faults.v1'
MODAL = 'autotechno-modal-continuation-fault-component.v1'
RUMBLE = 'autotechno-rumble-duration-fault-component.v1'
PREPARED = 'autotechno-native-prepared-admission-faults.v1'
SUCCESSOR = 'autotechno-native-successor-binding-faults.v1'


def fields(row, required, optional=()):
    require(type(row) is dict and set(required) <= set(row) <= set(required) | set(optional), 'closed report fields')


def finite_tree(value):
    if type(value) is float:
        require(math.isfinite(value), 'nonfinite report value')
    elif type(value) is dict:
        for child in value.values(): finite_tree(child)
    elif type(value) is list:
        for child in value: finite_tree(child)


def integer(value, minimum=0, maximum=None):
    require(type(value) is int and value >= minimum and (maximum is None or value <= maximum), 'bounded integer')
    return value


def number(value, minimum=0):
    require(type(value) in (int, float) and math.isfinite(value) and value >= minimum, 'finite nonnegative number')
    return value


def exact(value, expected):
    require(type(value) is type(expected) and value == expected, 'exact typed invariant')
    if type(expected) is list:
        for a,b in zip(value,expected): exact(a,b)
    elif type(expected) is dict:
        for key in expected: exact(value[key],expected[key])


def fingerprint(value):
    require(type(value) is str and re.fullmatch('[0-9a-f]{16}', value), 'native fingerprint')


def header(report, schema, scope, unavailable, extra=()):
    fields(report, ['schema', 'scope', 'unavailable', 'rows', *extra])
    exact(report['schema'], schema); exact(report['scope'], scope)
    exact(report['unavailable'], unavailable)
    require(type(report['rows']) is list and 0 < len(report['rows']) <= 1000, 'bounded actual report rows')
    finite_tree(report)
    return report['rows']


def population(rows, dimensions, expected):
    identities = [tuple(row[k] for k in dimensions) for row in rows]
    # Lists/bools must not alias integers in population identities.
    for row in rows:
        for key in dimensions:
            if key in ('rootSeed', 'sampleRate', 'rate', 'phase', 'seed', 'step'): integer(row[key])
            else: require(type(row[key]) is str, 'string population identity')
    require(len(identities) == len(expected) and len(set(identities)) == len(identities)
            and set(identities) == set(expected), 'complete unique frozen population')


def score_identity(row, roots=ROOTS):
    integer(row['rootSeed']); integer(row['sampleRate'])
    require(row['rootSeed'] in roots and row['sampleRate'] in RATES, 'fixed root and paired native rate')
    exact(row['split'], roots[row['rootSeed']])
    fingerprint(row['referencePlanFingerprint']); integer(row['scoreBar'])


def energy(report):
    fields(report, ['schema', 'unavailable', 'rows', 'summaries', 'failures'])
    exact(report['schema'], ENERGY); exact(report['failures'], [])
    exact(report['unavailable'], ['perceptual-masking-harm', 'band-filter-calibration',
          'score-to-foundation-render-binding', 'nonlinear-full-mix-quality',
          'population-uncertainty-fixed-construction-families'])
    finite_tree(report)
    families = ('bipolar-square', 'bipolar-ramp', 'sparse-bipolar-pulse')
    recipes = {'intentional-overlap': (1, False, True), 'half-amplitude': (.5, False, True),
               'double-amplitude': (2, False, True), 'unauthorized-truncation': (1, True, True),
               'deleted-required-companion': (0, False, True), 'intentional-absence': (0, False, False)}
    rows = report['rows']
    require(type(rows) is list, 'energy rows')
    population(rows, ('family', 'rate', 'scenario'), [(f,r,s) for f in families for r in RATES for s in recipes])
    # Independent sample-equation integration, rather than trusting the report's
    # expected columns or copying the producer's polynomial prefix oracle.
    def units(index, family):
        if family == families[0]: return 64 if index % 64 < 32 else -64
        if family == families[1]: return index % 32 - 16
        return 64 if index % 97 == 0 else -64 if index % 97 == 1 else 0
    for row in rows:
        fields(row, ['family','split','rate','scenario','requiredCompanion','missingRequiredCompanion',
                     'intendedFoundationEnergy','observedFoundationEnergy','expectedTemporalWindows','observedTemporalWindows','windows'])
        family, rate, scenario = row['family'], row['rate'], row['scenario']
        gain, truncated, required = recipes[scenario]
        exact(row['split'], 'development' if family == families[0] else 'held-out-construction-family')
        exact(row['requiredCompanion'], required)
        frames = (48 * rate + 13) // 26
        span = (frames + 4) // 8
        support = span // 2 if truncated else span
        prefix = [0]
        for i in range(span): prefix.append(prefix[-1] + units(i, family) ** 2)
        require(type(row['windows']) is list and len(row['windows']) == 16, 'sixteen causal cells')
        total, active = 0.0, 0
        for index, window in enumerate(row['windows']):
            fields(window, ['start','count','expectedKick','observedKick','expectedFoundation','observedFoundation'])
            start, end = (index * span + 15) // 16, ((index + 1) * span + 15) // 16
            exact(window['start'], start); exact(window['count'], end-start)
            kick = (prefix[end]-prefix[start]) / 1048576 / (end-start)
            foundation = (prefix[min(end,support)]-prefix[min(start,support)]) * gain * gain / 1048576 / (end-start)
            for key, wanted in [('expectedKick',kick),('observedKick',kick),('expectedFoundation',foundation),('observedFoundation',foundation)]:
                require(number(window[key]) == wanted, 'independently integrated source energy')
            active += foundation > 0
            total += foundation * (end-start)
        require(number(row['intendedFoundationEnergy']) == (prefix[-1]/1048576 if required else 0)
                and number(row['observedFoundationEnergy']) == total, 'independent total energy')
        exact(row['expectedTemporalWindows'], active); exact(row['observedTemporalWindows'], active)
        exact(row['missingRequiredCompanion'], scenario == 'deleted-required-companion')
    summaries = report['summaries']
    require(type(summaries) is list, 'family/rate errors required')
    population(summaries, ('family','rate'), [(f,r) for f in families for r in RATES])
    for row in summaries:
        fields(row, ['family','rate','measurements','meanAbsoluteError','rootMeanSquareError','signedError'])
        exact(row['measurements'], 192)
        for key in ['meanAbsoluteError','rootMeanSquareError','signedError']: require(number(row[key]) == 0, 'recomputed zero errors')
    return dict(rows=36, sourceFamilies=3, pairedRates=list(RATES), summaries=6)


def kick(report):
    rows = header(report, KICK, 'native-canonical-bar-render-and-kick-syntax-contract-only',
        ['full-prepared-transaction','foundation-companion-fidelity','nonlinear-full-mix-quality','perceptual-quality'])
    roots = {1:'development',42:'development',6011:'held-out-root',7011:'held-out-root'}
    scenarios = ['unaltered','deleted-kicks','shifted-kicks','wrong-voice','zero-intensity','intentional-absence']
    population(rows, ('rootSeed','sampleRate','scenario'), [(s,r,c) for s in roots for r in RATES for c in scenarios])
    baselines = {(row['rootSeed'],row['sampleRate']):row for row in rows if row['scenario']=='unaltered'}
    for row in rows:
        fields(row, ['rootSeed','split','referencePlanFingerprint','sampleRate','scenario','scoreRole','scoreBar','scoreEventCount','renderedEventCount','scoreStepMask','renderedStepMask','detectorSampleHash','audibleSampleHash','audibleNonzeroSamples','expectedComplete','observedComplete','protectedAndFullMatch'])
        score_identity(row, roots); fingerprint(row['detectorSampleHash']); fingerprint(row['audibleSampleHash'])
        scenario = row['scenario']; valid = scenario in ('unaltered','intentional-absence')
        exact(row['expectedComplete'], valid); exact(row['observedComplete'], valid); exact(row['protectedAndFullMatch'], True)
        for key in ['scoreEventCount','renderedEventCount','audibleNonzeroSamples']: integer(row[key])
        for key in ['scoreStepMask','renderedStepMask']: integer(row[key], maximum=65535)
        base = baselines[row['rootSeed'],row['sampleRate']]
        for key in ['referencePlanFingerprint','scoreBar']: exact(row[key], base[key])
        if scenario == 'intentional-absence':
            exact(row['scoreRole'],'withheld'); exact(row['scoreEventCount'],0); exact(row['scoreStepMask'],0)
        else:
            exact(row['scoreRole'],'grounded'); exact(row['scoreEventCount'],base['scoreEventCount']); exact(row['scoreStepMask'],base['scoreStepMask'])
            integer(row['scoreEventCount'],1); integer(row['scoreStepMask'],1)
        if scenario in ('deleted-kicks','wrong-voice','intentional-absence'):
            exact(row['renderedEventCount'],0); exact(row['renderedStepMask'],0)
        elif scenario in ('unaltered','shifted-kicks','zero-intensity'):
            exact(row['renderedEventCount'],row['scoreEventCount'])
            exact(row['renderedStepMask'],row['scoreStepMask'] if scenario!='shifted-kicks' else (row['scoreStepMask']<<1)&65535)
        if scenario in ('deleted-kicks','wrong-voice','zero-intensity','intentional-absence'): exact(row['audibleNonzeroSamples'],0)
        else: integer(row['audibleNonzeroSamples'],1)
        if scenario != 'unaltered': require(row['detectorSampleHash'] != base['detectorSampleHash'], 'actual changed kick PCM')
    return dict(rows=48, rootFamilies=4, pairedRates=list(RATES))


def full_phrase(report):
    schema = report['schema']
    require(schema in (FULL_BASS,FULL_COMPANION,FULL_BEHAVIOR), 'full phrase schema')
    companion = schema == FULL_COMPANION
    behavior = report['rows'][0].get('selectedFoundationBehavior') if schema == FULL_BEHAVIOR else None
    require(schema != FULL_BEHAVIOR or behavior in ('absent','monotone','point','pump','subPulse'), 'declared behavior')
    rows = header(report, schema, 'canonical-full-phrase-render-and-candidate-transaction-binding',
        ['all-foundation-behaviors', 'unauthorized-truncation' if companion else 'companion-and-truncation-faults',
         'accepted-continuous-journey','production-calibration','perceptual-quality','full-prepared-commit-fault-matrix','population-error-intervals'])
    noun = 'companion' if companion else 'bass'
    scenarios = ['unaltered','undeclared-bass'] if behavior == 'absent' else ['unaltered','deleted-'+noun,'shifted-'+noun,'wrong-voice','zero-intensity']
    population(rows, ('rootSeed','sampleRate','scenario'), [(s,r,c) for s in ROOTS for r in RATES for c in scenarios])
    baselines = {(r['rootSeed'],r['sampleRate']):r for r in rows if r['scenario']=='unaltered'}
    base_fields = ['rootSeed','split','sampleRate','scenario','originalPlanFingerprint','renderedPlanFingerprint','originalSampleHash','renderedSampleHash','frameCount','differenceRMS','foundationComplete','vectorComplete','transactionComplete','exactReplay']
    variant_fields = ['originalCompanionEvents','renderedCompanionEvents','companionVoice','companionMatchesOriginal'] if companion else ['originalBassEvents','renderedBassEvents']
    if behavior is not None: variant_fields += ['selectedFoundationBehavior','targetedScoreBars','targetedBassEvents']
    for row in rows:
        fields(row, base_fields+variant_fields)
        integer(row['rootSeed']); integer(row['sampleRate']); exact(row['split'], ROOTS[row['rootSeed']])
        base = baselines[row['rootSeed'],row['sampleRate']]
        for key in ['originalPlanFingerprint','renderedPlanFingerprint','originalSampleHash','renderedSampleHash']: fingerprint(row[key])
        for key in ['originalPlanFingerprint','originalSampleHash','frameCount']: exact(row[key],base[key])
        integer(row['frameCount'],1); exact(row['exactReplay'],True)
        valid = row['scenario']=='unaltered'
        for key in ['vectorComplete','transactionComplete']: exact(row[key],valid)
        if not companion: exact(row['foundationComplete'],valid)
        else:
            require(type(row['foundationComplete']) is bool, 'foundation status')
            require(row['companionVoice'] in ('rumble','tunedTom'), 'declared companion voice')
            exact(row['companionVoice'],base['companionVoice']); exact(row['companionMatchesOriginal'],valid)
        require((row['renderedPlanFingerprint']==row['originalPlanFingerprint']) == valid and
                (row['renderedSampleHash']==row['originalSampleHash']) == valid and
                (number(row['differenceRMS'])==0) == valid, 'canonical nonlinear damage witnesses')
        old, new = ('originalCompanionEvents','renderedCompanionEvents') if companion else ('originalBassEvents','renderedBassEvents')
        integer(row[old]); integer(row[new]); exact(row[old],base[old])
        if behavior is not None:
            exact(row['selectedFoundationBehavior'],behavior)
            require(type(row['targetedScoreBars']) is list and row['targetedScoreBars'], 'targeted score bars')
            for bar in row['targetedScoreBars']: integer(bar)
            require(len(set(row['targetedScoreBars'])) == len(row['targetedScoreBars']), 'unique targeted bars')
            for key in ['targetedScoreBars','targetedBassEvents']: exact(row[key],base[key])
            targeted = integer(row['targetedBassEvents'])
            if behavior == 'absent': exact(targeted,0)
            else: integer(targeted,1)
            expected = row[old] + len(row['targetedScoreBars']) if row['scenario']=='undeclared-bass' else row[old] if valid or row['scenario'] in ('shifted-bass','zero-intensity') else row[old]-targeted
            exact(row[new],expected)
        elif valid or row['scenario']=='shifted-'+noun or (not companion and row['scenario']=='zero-intensity'):
            # The canonical native bass control retains scheduled events when
            # intensity becomes zero. A deleted event is a different fault.
            exact(row[new],row[old])
        elif row['scenario'] in ('deleted-'+noun,'wrong-voice'): exact(row[new],0)
    return dict(rows=len(rows), pairedRates=list(RATES), behavior=behavior, canonicalDamageReportsChecked=True,
                rawPCMIndependentlyRendered=False)


def bass(report):
    behaviors = ['subPulse','monotone','point','pump','absent']
    rows = header(report, BASS, 'native-established-bass-score-binding-with-independent-onset-equation',
        ['dotted-authorized-release','unauthorized-truncation','full-prepared-transaction','nonlinear-full-mix-quality','perceptual-quality','population-error-intervals'],
        ['behaviors','unavailableBehaviors'])
    exact(report['behaviors'],behaviors)
    exact(report['unavailableBehaviors'],['kickTail:requires-rumble-event-evidence','tunedPercussive:requires-modal-event-evidence'])
    scenarios = ['unaltered','deleted-bass','shifted-bass','wrong-voice','zero-intensity']
    population(rows, ('rootSeed','behavior','sampleRate','scenario'),
        [(s,b,r,c) for s in ROOTS for b in behaviors for r in RATES for c in (['declared-absence'] if b=='absent' else scenarios)])
    baselines = {(r['rootSeed'],r['behavior'],r['sampleRate']):r for r in rows if r['scenario'] in ('unaltered','declared-absence')}
    for row in rows:
        fields(row, ['rootSeed','split','behavior','referencePlanFingerprint','sampleRate','scenario','scoreBar',
          'scoreEventCount','scoreStepMask','renderedEventCount','renderedStepMask','expectedStartFrames','renderedStartFrames',
          'scoreSteps','barFrameCount','scoreSwingPercent','independentTimingOracle','drySampleHash','peak','rms',
          'expectedComplete','observedComplete','renderPassesMatch'])
        score_identity(row); fingerprint(row['drySampleHash'])
        exact(row['barFrameCount'],(48*row['sampleRate']+13)//26)
        exact(row['independentTimingOracle'],'floor((step + (odd ? clamp(2*swing-1,0,6/25) : 0))*frames/16+1/2)')
        swing = number(row['scoreSwingPercent']); require(swing <= 1, 'score swing fraction')
        require(type(row['scoreSteps']) is list, 'score steps')
        mask, starts = 0, []
        for step in row['scoreSteps']:
            integer(step,maximum=15); mask |= 1 << step
            shift = min(6/25,max(0,2*swing-1)) if step%2 else 0
            starts.append(math.floor((step+shift)*row['barFrameCount']/16+.5))
        exact(row['scoreEventCount'],len(starts)); exact(row['scoreStepMask'],mask); exact(row['expectedStartFrames'],starts)
        require(type(row['renderedStartFrames']) is list, 'rendered starts')
        for start in row['renderedStartFrames']: integer(start,maximum=row['barFrameCount']-1)
        integer(row['renderedEventCount']); integer(row['renderedStepMask'],maximum=65535)
        exact(len(row['renderedStartFrames']),row['renderedEventCount'])
        valid = row['scenario'] in ('unaltered','declared-absence')
        exact(row['expectedComplete'],valid); exact(row['observedComplete'],valid); exact(row['renderPassesMatch'],True)
        base = baselines[row['rootSeed'],row['behavior'],row['sampleRate']]
        for key in ['referencePlanFingerprint','scoreBar','scoreSteps','scoreSwingPercent','scoreEventCount','scoreStepMask','expectedStartFrames']:
            exact(row[key],base[key])
        if row['behavior']=='absent': exact(starts,[])
        else: require(starts, 'positive declared bass events')
        if valid or row['scenario']=='zero-intensity':
            exact(row['renderedEventCount'],len(starts)); exact(row['renderedStepMask'],mask); exact(row['renderedStartFrames'],starts)
        elif row['scenario']=='shifted-bass':
            shifted=[(step+1)%16 for step in row['scoreSteps']]
            shifted_mask=0
            for step in shifted: shifted_mask |= 1<<step
            shifted_starts=[math.floor((step+(min(6/25,max(0,2*swing-1)) if step%2 else 0))*row['barFrameCount']/16+.5) for step in shifted]
            exact(row['renderedEventCount'],len(starts)); exact(row['renderedStepMask'],shifted_mask); exact(row['renderedStartFrames'],shifted_starts)
            require(shifted_starts != starts, 'actual onset displacement')
        else:
            exact(row['renderedEventCount'],0); exact(row['renderedStepMask'],0); exact(row['renderedStartFrames'],[])
        for key in ['peak','rms']:
            value=number(row[key]); require((value>0)==(row['scenario'] in ('unaltered','shifted-bass')), 'bass audibility control')
        if not valid: require(row['drySampleHash'] != base['drySampleHash'], 'actual changed bass PCM')
    return dict(rows=84, behaviors=behaviors, pairedRates=list(RATES), onsetEquationRecomputed=True)


def companion(report):
    rows = header(report, COMPANION, 'native-rumble-and-modal-source-score-binding',
        ['absolute-per-event-rumble-sample-starts','continuing-modal-tail-support','unauthorized-truncation','dotted-authorized-release',
         'full-prepared-transaction','nonlinear-full-mix-quality','perceptual-quality','population-error-intervals'], ['behaviors'])
    exact(report['behaviors'],['kickTail','tunedPercussive'])
    scenarios = ['unaltered','deleted-companion','shifted-companion','wrong-voice','zero-intensity']
    population(rows, ('rootSeed','behavior','sampleRate','scenario'), [(s,b,r,c) for s in ROOTS for b in report['behaviors'] for r in RATES for c in scenarios])
    baselines = {(r['rootSeed'],r['behavior'],r['sampleRate']):r for r in rows if r['scenario']=='unaltered'}
    for row in rows:
        fields(row, ['rootSeed','split','behavior','referencePlanFingerprint','sampleRate','scenario','scoreBar','scoreEventIndexes',
          'renderedEventIndexes','scoreSteps','renderedSteps','expectedStartFrames','drySampleHash','peak','rms','expectedBinding','observedBinding','renderPassesMatch'],
          ['renderedStartFrames','firstNonzeroFrame','expectedFirstOnsetShift','observedFirstOnsetShift'])
        score_identity(row); fingerprint(row['drySampleHash'])
        base = baselines[row['rootSeed'],row['behavior'],row['sampleRate']]
        for key in ['referencePlanFingerprint','scoreBar','scoreEventIndexes','scoreSteps','expectedStartFrames']: exact(row[key],base[key])
        for key in ['scoreEventIndexes','renderedEventIndexes','scoreSteps','renderedSteps']:
            require(type(row[key]) is list, 'companion event lists')
            for value in row[key]: integer(value,maximum=15 if key.endswith('Steps') else None)
        require(row['scoreSteps'] and len(row['scoreSteps'])==len(row['scoreEventIndexes']), 'nonempty declared companion')
        frames=(48*row['sampleRate']+13)//26
        starts=[math.floor(step*frames/16+.5) for step in row['scoreSteps']]
        exact(row['expectedStartFrames'],starts)
        valid=row['scenario']=='unaltered'; shifted=row['scenario']=='shifted-companion'
        exact(row['expectedBinding'],valid); exact(row['observedBinding'],valid); exact(row['renderPassesMatch'],True)
        if valid or shifted:
            exact(row['renderedEventIndexes'],row['scoreEventIndexes'])
            exact(row['renderedSteps'],[step+int(shifted) for step in row['scoreSteps']])
            integer(row.get('firstNonzeroFrame'),maximum=frames-1)
            if row['behavior']=='tunedPercussive':
                exact(row.get('renderedStartFrames'),[math.floor(step*frames/16+.5) for step in row['renderedSteps']])
            else: require('renderedStartFrames' not in row, 'rumble starts must remain unavailable')
            if shifted:
                first=min(row['scoreSteps']); shift=math.floor((first+1)*frames/16+.5)-math.floor(first*frames/16+.5)
                exact(row.get('expectedFirstOnsetShift'),shift); exact(row.get('observedFirstOnsetShift'),shift)
        else:
            require('firstNonzeroFrame' not in row, 'silent companion has no onset')
            if row['scenario'] in ('deleted-companion','wrong-voice'):
                exact(row['renderedEventIndexes'],[]); exact(row['renderedSteps'],[])
            else:
                exact(row['renderedEventIndexes'],row['scoreEventIndexes']); exact(row['renderedSteps'],row['scoreSteps'])
        for key in ['peak','rms']: require((number(row[key])>0)==(valid or shifted), 'companion audibility control')
        if not valid: require(row['drySampleHash']!=base['drySampleHash'], 'actual changed companion PCM')
    return dict(rows=40, behaviors=report['behaviors'], pairedRates=list(RATES), rumbleAbsoluteStartsAvailable=False)


def release(report):
    rows=header(report, RELEASE, 'score-derived-release-support-in-canonical-single-source-render',
        ['full-prepared-transaction','shared-nonlinear-full-mix-quality','continuing-source-state','other-foundation-behavior-truncation',
         'independent-bass-timing-offset-equations','perceptual-quality','population-error-intervals'], ['selection'])
    require(type(report['selection']) is list and len(report['selection'])==2, 'two disjoint score-only root domains')
    selected={}
    for selection,(first,last,split) in zip(report['selection'],[(1,48,'development'),(6001,6048,'held-out-root')]):
        fields(selection,['split','firstRoot','lastRoot','examined']); exact(selection['split'],split)
        exact(selection['firstRoot'],first); exact(selection['lastRoot'],last)
        examined=selection['examined']; require(type(examined) is list and 0<len(examined)<=48, 'bounded original selection')
        for offset,item in enumerate(examined):
            fields(item,['rootSeed','phases','scoreBars','planFingerprints']); exact(item['rootSeed'],first+offset)
            require(type(item['phases']) is list and item['phases'] in ([],[0],[1],[0,1]), 'score phase coverage')
            exact(len(item['scoreBars']),len(item['phases'])); exact(len(item['planFingerprints']),len(item['phases']))
            for phase,bar,fp in zip(item['phases'],item['scoreBars'],item['planFingerprints']):
                integer(bar); exact(bar%2,phase); fingerprint(fp)
            exact(item['phases']==[0,1],offset==len(examined)-1)
        chosen=examined[-1]; selected[chosen['rootSeed']]=(split,dict(zip(chosen['phases'],zip(chosen['scoreBars'],chosen['planFingerprints']))))
    scenarios=['authorized-release','early-release','omitted-release']
    population(rows,('rootSeed','phase','sampleRate','scenario'),[(s,p,r,c) for s in selected for p in (0,1) for r in RATES for c in scenarios])
    baselines={(r['rootSeed'],r['phase'],r['sampleRate']):r for r in rows if r['scenario']=='authorized-release'}
    for row in rows:
        fields(row,['rootSeed','split','referencePlanFingerprint','scoreBar','phase','sampleRate','scenario','eventStartFrame',
          'authorizedReleaseStartFrame','authorizedReleaseEndFrame','kickFrame','naturalFrameCount','appliedFrameCount',
          'prefixMatchesUngated','declaredSilenceIsZero','expectedBinding','observedBinding','drySampleHash','replayExact'],
          ['suppliedReleaseStartFrame','suppliedReleaseEndFrame'])
        split,phases=selected[row['rootSeed']]; exact(row['split'],split)
        bar,fp=phases[row['phase']]; exact(row['scoreBar'],bar); exact(row['referencePlanFingerprint'],fp); fingerprint(row['drySampleHash'])
        frames=(48*row['sampleRate']+13)//26; step=4 if row['phase']==0 else 12
        start,end,kick=(math.floor(x*frames/16+.5) for x in (step-3/16,step-1/16,step))
        for key,value in [('authorizedReleaseStartFrame',start),('authorizedReleaseEndFrame',end),('kickFrame',kick)]: exact(row[key],value)
        onset=integer(row['eventStartFrame']); natural=integer(row['naturalFrameCount'],1); integer(row['appliedFrameCount'],1)
        require(onset<start<end<kick<frames and onset+natural>kick, 'natural support crosses intended pocket')
        scenario=row['scenario']; valid=scenario=='authorized-release'
        exact(row['expectedBinding'],valid); exact(row['observedBinding'],valid); exact(row['replayExact'],True)
        exact(row['prefixMatchesUngated'],scenario!='early-release'); exact(row['declaredSilenceIsZero'],scenario!='omitted-release')
        base=baselines[row['rootSeed'],row['phase'],row['sampleRate']]
        for key in ['eventStartFrame','naturalFrameCount']: exact(row[key],base[key])
        if scenario=='omitted-release':
            require('suppliedReleaseStartFrame' not in row and 'suppliedReleaseEndFrame' not in row, 'omitted release remains absent')
        else:
            supplied_start,supplied_end=(math.floor((x-(.25 if scenario=='early-release' else 0))*frames/16+.5) for x in (step-3/16,step-1/16))
            exact(row.get('suppliedReleaseStartFrame'),supplied_start); exact(row.get('suppliedReleaseEndFrame'),supplied_end)
            exact(onset+row['appliedFrameCount'],supplied_end)
        if not valid: require(row['drySampleHash']!=base['drySampleHash'], 'release changes actual PCM')
    return dict(rows=24, pairedRates=list(RATES), selectionFromDisjointScoreDomains=True, independentBassOnsetOracleAvailable=False)


def output(report):
    rows=header(report, OUTPUT, 'post-render-output-loss-and-candidate-transaction-binding',
        ['source-local-truncation-counterfactual','full-prepared-commit-fault-matrix','production-calibration','perceptual-quality','runtime-resource-lifecycle-physical-qualification'])
    population(rows,('rootSeed','sampleRate','scenario'),[(s,r,c) for s in ROOTS for r in RATES for c in ('unaltered','one-frame-loss','half-bar-loss')])
    baselines={(r['rootSeed'],r['sampleRate']):r for r in rows if r['scenario']=='unaltered'}
    for row in rows:
        fields(row,['rootSeed','sampleRate','scenario','planFingerprint','originalFrames','observedFrames','removedFrames','originalSampleHash','observedSampleHash','retainedPrefixExact','exactReplay','vectorProduced','vectorComplete','transactionComplete'])
        fingerprint(row['planFingerprint']); fingerprint(row['originalSampleHash']); fingerprint(row['observedSampleHash'])
        original=integer(row['originalFrames'],1); observed=integer(row['observedFrames']); removed=integer(row['removedFrames'])
        exact(observed+removed,original); valid=row['scenario']=='unaltered'
        if row['scenario']=='one-frame-loss': exact(removed,1)
        elif row['scenario']=='half-bar-loss': exact(removed,((48*row['sampleRate']+13)//26)//2)
        else: exact(removed,0)
        for key in ['retainedPrefixExact','exactReplay']: exact(row[key],True)
        for key in ['vectorProduced','vectorComplete','transactionComplete']: exact(row[key],valid)
        base=baselines[row['rootSeed'],row['sampleRate']]
        for key in ['planFingerprint','originalFrames','originalSampleHash']: exact(row[key],base[key])
        require((row['observedSampleHash']==row['originalSampleHash'])==valid, 'output loss witness')
    return dict(rows=12, pairedRates=list(RATES), sourceLocalTruncationQualified=False)


def modal(report):
    rows=header(report,MODAL,'canonical-modal-source-chunk-continuation',
        ['full-prepared-transaction','rumble-truncation','shared-nonlinear-full-mix','perceptual-quality','population-error-intervals'], ['distinctMaterialCases','qualification'])
    exact(report['qualification'],'unavailable'); exact(report['distinctMaterialCases'],4)
    cases=[(1,'stretched-membrane'),(1,'hollow-wood'),(6011,'bronze-plate'),(6011,'ceramic-shell')]
    population(rows,('seed','material','sampleRate','scenario'),[(s,m,r,c) for s,m in cases for r in RATES for c in ('unaltered','lost-continuation','lost-voices','absent-companion')])
    bases={(r['seed'],r['material'],r['sampleRate']):r for r in rows if r['scenario']=='unaltered'}
    for row in rows:
        fields(row,['seed','split','material','sampleRate','scenario','openingFrames','closingFrames','expectedIncomingVoiceState','actualIncomingVoiceState','referenceSampleHash','actualSampleHash','sampleErrorRMS','expectedStateBinding','observedStateBinding','measurementLedgerAccepted','replayExact'])
        exact(row['split'],'development' if row['seed']==1 else 'held-out-material-and-seed')
        exact(row['openingFrames'],row['sampleRate']//20); exact(row['closingFrames'],row['sampleRate']*3//10)
        for key in ['expectedIncomingVoiceState','actualIncomingVoiceState','referenceSampleHash','actualSampleHash']: fingerprint(row[key])
        valid=row['scenario'] in ('unaltered','absent-companion')
        for key in ['expectedStateBinding','observedStateBinding']: exact(row[key],valid)
        exact(row['measurementLedgerAccepted'],row['scenario']!='lost-continuation'); exact(row['replayExact'],True)
        require((row['expectedIncomingVoiceState']==row['actualIncomingVoiceState'])==valid and
                (row['referenceSampleHash']==row['actualSampleHash'])==valid and
                (number(row['sampleErrorRMS'])==0)==valid, 'actual modal state/PCM mismatch witness')
        if row['scenario']!='absent-companion':
            base=bases[row['seed'],row['material'],row['sampleRate']]
            for key in ['expectedIncomingVoiceState','referenceSampleHash']: exact(row[key],base[key])
    return dict(rows=32, fixedMaterialSeedCases=4, pairedRates=list(RATES), measurementLedgerAloneSufficient=False)


def rumble(report):
    rows=header(report,RUMBLE,'canonical-rumble-source-support-with-original-destination-binding',
        ['full-prepared-transaction','nonlinear-full-mix','perceptual-quality','independent-constructor-holdout','population-error-intervals'], ['qualification'])
    exact(report['qualification'],'unavailable')
    population(rows,('rootSeed','step','sampleRate','scenario'),[(s,p,r,c) for s in ROOTS for r in RATES for p in (0,15) for c in ('original-support','unauthorized-shortening')])
    bases={(r['rootSeed'],r['step'],r['sampleRate']):r for r in rows if r['scenario']=='original-support'}
    for row in rows:
        fields(row,['rootSeed','split','step','sampleRate','scenario','originalBarFrames','suppliedBufferFrames','eventStartFrame','naturalFrames','expectedFrames','renderedFrames','referenceSampleHash','actualAlignedSampleHash','sampleErrorRMS','expectedSupportBinding','observedSupportBinding','declickComplete','replayExact'])
        exact(row['split'],ROOTS[row['rootSeed']]); rate=row['sampleRate']; frames=(48*rate+13)//26
        onset=math.floor(row['step']*frames/16+.5); natural=(rate*17+12)//25; expected=min(natural,frames-onset)
        for key,value in [('originalBarFrames',frames),('eventStartFrame',onset),('naturalFrames',natural),('expectedFrames',expected)]: exact(row[key],value)
        valid=row['scenario']=='original-support'
        exact(row['renderedFrames'],expected if valid else expected//2)
        exact(row['suppliedBufferFrames'],frames if valid else onset+expected//2)
        for key in ['expectedSupportBinding','observedSupportBinding']: exact(row[key],valid)
        for key in ['declickComplete','replayExact']: exact(row[key],True)
        for key in ['referenceSampleHash','actualAlignedSampleHash']: fingerprint(row[key])
        exact(row['referenceSampleHash'],bases[row['rootSeed'],row['step'],rate]['referenceSampleHash'])
        require((row['actualAlignedSampleHash']==row['referenceSampleHash'])==valid and (number(row['sampleErrorRMS'])==0)==valid, 'source support PCM witness')
    return dict(rows=16, pairedRates=list(RATES), independentConstructorHoldout=False)


def prepared(report):
    successor=report['schema']==SUCCESSOR
    fields(report,['schema','qualification','rootSeed','phraseIndex','sampleRate','sampleHash','exactControlReplay','rows'] + ([] if successor else ['sourceIdentity','unavailable']))
    finite_tree(report); exact(report['qualification'],'mechanical-only-not-installed')
    exact(report['rootSeed'],48300); exact(report['phraseIndex'],21); exact(report['exactControlReplay'],True)
    integer(report['sampleRate']); require(report['sampleRate'] in RATES,'paired native rate')
    fingerprint(report['sampleHash'])
    if not successor: fingerprint(report['sourceIdentity'])
    recipes = {'unaltered':[], 'wrong-successor-rate':['sample-rate'], 'wrong-successor-route':['route-generation'],
               'wrong-successor-quality':['quality-state'], 'lost-successor-modal-state':['render-dsp-state'], 'lost-successor-modal-voices':['render-dsp-state']} if successor else {
               'unaltered':[], 'missing-proof':['prepared-validation=missing'], 'missing-successor':['prepared-validation=required-windows-unavailable'],
               'unaccepted-successor':['prepared-validation=qualified-continuation-unavailable'], 'rejected-assessment':[],
               'changed-accepted-reason':['prepared-validation-source'], 'foreign-route-proof':['prepared-validation=source-mismatch'], 'cancelled-validation':[]}
    if not successor:
        exact(report.get('unavailable'),['full-supported-prepared-fault-matrix','production-calibration','perceptual-quality','runtime-resource-lifecycle-physical-qualification'])
    rows=report['rows']; require(type(rows) is list,'prepared rows'); population(rows,('scenario',),[(s,) for s in recipes])
    for row in rows:
        valid=row['scenario']=='unaltered'
        if successor:
            fields(row,['scenario','sourceProductPresent','sourceCommitEligible','sourcePCMUnchanged','successorRenders','validationCalls','assessmentCalls','callerStateUnchanged','successorPresent','successorCommitEligible','successorInputIdentityMatchesRequest','changedInputs','sourceActiveModalVoices','modalMeasurementPreserved'],['refusal'])
            for key in ['sourceProductPresent','sourcePCMUnchanged','callerStateUnchanged','successorPresent','successorCommitEligible','successorInputIdentityMatchesRequest']: exact(row[key],True)
            exact(row['sourceCommitEligible'],valid); exact(row['changedInputs'],recipes[row['scenario']])
            integer(row['sourceActiveModalVoices'],1); exact(row['modalMeasurementPreserved'],row['scenario']!='lost-successor-modal-state')
            exact(row['assessmentCalls'],int(valid)); exact(row['successorRenders'],1)
            if not valid: exact(row.get('refusal'),'inconsistentIdentity')
            else: require('refusal' not in row,'normal successor has no refusal')
        else:
            absent=row['scenario'] in ('changed-accepted-reason','cancelled-validation')
            fields(row,['scenario','preparedProductPresent','commitEligible','acceptedEvidenceUnchanged','diagnostics','successorRenders','validationCalls'],['sourcePCMUnchanged','failureCode'])
            exact(row['preparedProductPresent'],not absent); exact(row['commitEligible'],valid); exact(row['acceptedEvidenceUnchanged'],not valid)
            exact(row['diagnostics'],recipes[row['scenario']])
            if absent:
                require('sourcePCMUnchanged' not in row,'absent product has no PCM observation')
                exact(row.get('failureCode'),'cancelled' if row['scenario']=='cancelled-validation' else 'prepared-validation-mismatch')
            else: exact(row.get('sourcePCMUnchanged'),True); require('failureCode' not in row,'present product has no construction failure')
            exact(row['successorRenders'],int(row['scenario'] in ('unaltered','unaccepted-successor','rejected-assessment','changed-accepted-reason')))
        exact(row['validationCalls'],1)
    return dict(rows=len(rows), pairedRates=[report['sampleRate']], installedQualification=False)


READERS = {ENERGY:energy, KICK:kick, BASS:bass, COMPANION:companion, RELEASE:release,
           FULL_BASS:full_phrase, FULL_COMPANION:full_phrase, FULL_BEHAVIOR:full_phrase, OUTPUT:output,
           MODAL:modal, RUMBLE:rumble, PREPARED:prepared, SUCCESSOR:prepared}


def read(report):
    require(type(report) is dict and type(report.get('schema')) is str and report['schema'] in READERS, 'supported claim report')
    require(type(report.get('rows')) is list and 0<len(report['rows'])<=1000
            and all(type(row) is dict for row in report['rows']), 'bounded claim row objects')
    try:
        result = READERS[report['schema']](report)
    except (KeyError, IndexError, TypeError, OverflowError) as exc:
        raise ValueError('malformed claim report') from exc
    return dict(schema='autotechno-at0039-claim-read.v1', reportSchema=report['schema'], checks=result,
                originalUnavailable=report.get('unavailable',[]), nativeExecutionAuthenticated=False,
                limitations=['native-execution-and-compiled-build-authentication','current-source-applicability',
                             'full-supported-prepared-fault-matrix','perceptual-quality',
                             'runtime-resource-lifecycle-physical-qualification','complete-at0039-acceptance'],
                currentSourceApplicability=False, fullAlgorithmicAcceptanceVerified=False,
                runtimeQualification=False, item39Complete=False)
