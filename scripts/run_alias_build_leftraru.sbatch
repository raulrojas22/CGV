#!/bin/bash
#SBATCH --job-name=cgv_alias
#SBATCH --output=/home/rrojase/cgv/logs/cgv_alias_%j.out
#SBATCH --error=/home/rrojase/cgv/logs/cgv_alias_%j.err
#SBATCH --chdir=/home/rrojase/cgv
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --time=24:00:00

set -euo pipefail

mkdir -p logs data/alias_index

echo "Job ID: ${SLURM_JOB_ID:-manual}"
echo "CPUs: ${SLURM_CPUS_PER_TASK:-8}"
echo "Started: $(date)"

CGV_ALIAS_BUILD_WORKERS="${SLURM_CPUS_PER_TASK:-8}" \
CGV_ALIAS_SKIP_DOWNLOAD=1 \
bash scripts/run_alias_build_prefilter.sh

echo "Finished: $(date)"
