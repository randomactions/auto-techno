#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 CALIBRATION_CACHE_DIRECTORY" >&2
  exit 64
fi

cache_directory=$1
if [ ! -d "$cache_directory" ]; then
  echo "cache directory does not exist: $cache_directory" >&2
  exit 66
fi

set -- "$cache_directory"/journey-*.json
if [ ! -f "$1" ]; then
  echo "no journey-*.json files in: $cache_directory" >&2
  exit 66
fi

jq -s '
  def db:
    if . > 0 then 20 * ((log) / 2.302585092994046) else null end;
  def stats($values):
    ($values | map(select(. != null and (isinfinite | not) and (isnan | not))) | sort) as $sorted
    | if ($sorted | length) == 0 then null else {
        count: ($sorted | length),
        minimum: $sorted[0],
        p05: $sorted[((($sorted | length) - 1) * 0.05 | floor)],
        median: $sorted[((($sorted | length) - 1) * 0.50 | floor)],
        p95: $sorted[((($sorted | length) - 1) * 0.95 | floor)],
        maximum: $sorted[-1],
        mean: (($sorted | add) / ($sorted | length))
      } end;

  . as $journeys
  | [
      $journeys[]
      | .reportJSON[]
      | @base64d
      | fromjson
    ] as $reports
  | [
      $reports[].selectedCandidateEvidence.automaticMix[]
      | select(.measuredKickOverFoundationDB != null)
      | . as $mix
      | ($mix.gains[] | select(.role == "kick") | .gainDB) as $gain
      | {
          companion: .foundationCompanion,
          gainDB: $gain,
          requiredCorrectionDB:
            (.targetKickOverFoundationDB - .measuredKickOverFoundationDB),
          residualKickExcessDB:
            (.measuredKickOverFoundationDB + $gain -
              .targetKickOverFoundationDB)
        }
    ] as $controller
  | ([$controller[].gainDB] | min) as $minimumObservedCorrectionDB
  | [
      $reports[].selectedCandidateEvidence.stems[].roles[]
      | {
          role,
          activeLevelDBFS: (.activeRMS | db),
          onsetLevelDBFS: (.onsetRMS | db),
          peakDBFS: (.peak | db),
          occupancy,
          crestFactor
        }
    ] as $roles
  | ["kick", "foundation", "percussion", "upperTonal", "atmosphere"]
      as $roleOrder
  | [
      $reports[].selectedCandidateEvidence.stems[]
      | .roles as $barRoles
      | range(0; ($roleOrder | length)) as $leftIndex
      | range($leftIndex + 1; ($roleOrder | length)) as $rightIndex
      | $roleOrder[$leftIndex] as $leftRole
      | $roleOrder[$rightIndex] as $rightRole
      | first($barRoles[] | select(.role == $leftRole)) as $left
      | first($barRoles[] | select(.role == $rightRole)) as $right
      | select(
          $left.activeRMS > 0.000001 and $right.activeRMS > 0.000001 and
            $left.occupancy >= 0.02 and $right.occupancy >= 0.02
        )
      | {
          leftRole: $leftRole,
          rightRole: $rightRole,
          activeLevelDifferenceDB:
            (($left.activeRMS | db) - ($right.activeRMS | db))
        }
    ] as $activeRoleRelations
  | {
      schemaVersion: "autotechno-mix-balance-benchmark.v1",
      engineVersions: ([$journeys[].identity.engineVersion] | unique),
      qualitySchemaVersions:
        ([$journeys[].identity.qualitySchemaVersion] | unique),
      sourceJourneyCount: ($journeys | length),
      sourceReportCount: ($reports | length),
      kickFoundationController: {
        eligibleMeasurementCount: ($controller | length),
        minimumObservedCorrectionDB: $minimumObservedCorrectionDB,
        correctionDB: stats([$controller[].gainDB]),
        requiredCorrectionDB: stats([$controller[].requiredCorrectionDB]),
        residualKickExcessDB: stats([$controller[].residualKickExcessDB]),
        minimumObservedCorrectionCount:
          ([$controller[] | select(
            .gainDB == $minimumObservedCorrectionDB
          )] | length),
        minimumObservedUnresolvedCount:
          ([$controller[] | select(
            .gainDB == $minimumObservedCorrectionDB and
              (.residualKickExcessDB | fabs) > 0.35
          )] | length),
        byCompanion: (
          $controller
          | group_by(.companion)
          | map({
              key: .[0].companion,
              value: {
                count: length,
                requiredCorrectionDB: stats([.[].requiredCorrectionDB]),
                residualKickExcessDB: stats([.[].residualKickExcessDB])
              }
            })
          | from_entries
        )
      },
      roles: (
        $roles
        | group_by(.role)
        | map({
            key: .[0].role,
            value: {
              activeLevelDBFS: stats([.[].activeLevelDBFS]),
              onsetLevelDBFS: stats([.[].onsetLevelDBFS]),
              peakDBFS: stats([.[].peakDBFS]),
              occupancy: stats([.[].occupancy]),
              crestFactor: stats([.[].crestFactor])
            }
          })
        | from_entries
      ),
      activeRoleRelations: (
        $activeRoleRelations
        | group_by(.leftRole, .rightRole)
        | map({
            leftRole: .[0].leftRole,
            rightRole: .[0].rightRole,
            activeLevelDifferenceDB: stats([.[].activeLevelDifferenceDB])
          })
      )
    }
' "$@"
