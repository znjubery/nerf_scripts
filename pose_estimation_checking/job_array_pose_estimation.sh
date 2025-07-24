#!/bin/bash
#SBATCH --job-name=ns_train_array
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:a100:1
#SBATCH --cpus-per-task=16
#SBATCH --mem=100G
#SBATCH --partition=nova
#SBATCH --account=baskarg-lab
#SBATCH --time=04:00:00
#SBATCH --array=0-3
#SBATCH --output=logs/array_train_%A_%a.out
#SBATCH --error=logs/array_train_%A_%a.err

# -----------------------
# LOAD ENVIRONMENT
# -----------------------
module load cuda
source activate /work/mech-ai/znjubery/conda_envs_znj/nerfstudio/

set -e  # Exit on any error

VIDEO_LIST="video_list.txt"
VIDEO_PATH=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "$VIDEO_LIST")

if [ -z "$VIDEO_PATH" ]; then
  echo "Error: No video found for task ID $SLURM_ARRAY_TASK_ID"
  exit 1
fi

# Number of frames per run and repetition count
NUM_FRAMES=400
REPS=2

# Base names
BASE_OUTPUT_DIR="video_output_400"
LOG_DIR="logs"
PLOT_SCRIPT="camera_pose_display_used_in_bash.py"
mkdir -p "${LOG_DIR}"

# Parameter arrays
MATCHING_METHODS=("sequential")
FEATURE_TYPES=("any")
MATCHER_TYPES=("any")
SFM_TOOLS=("colmap")
CAMERA_TYPES=("perspective" "pinhole")
NUM_DOWNSCALES=(3 2)

# Loop through all combinations
for matching_method in "${MATCHING_METHODS[@]}"; do
  for feature_type in "${FEATURE_TYPES[@]}"; do
    for matcher_type in "${MATCHER_TYPES[@]}"; do
      for sfm_tool in "${SFM_TOOLS[@]}"; do
        for camera_type in "${CAMERA_TYPES[@]}"; do
          for num_downscales in "${NUM_DOWNSCALES[@]}"; do

            refine_flags=""
            if [ "$sfm_tool" == "hloc" ]; then
              refine_flags="--refine-pixsfm"
            elif [ "$sfm_tool" == "colmap" ]; then
              refine_flags="--refine-intrinsics"
            fi

            for run_idx in $(seq 1 "${REPS}"); do
              video_basename=$(basename "$VIDEO_PATH" .mp4)
              output_dir="${BASE_OUTPUT_DIR}/${video_basename}_${matching_method}_${feature_type}_${matcher_type}_${sfm_tool}_${camera_type}_ds${num_downscales}_run${run_idx}"
              log_file="${LOG_DIR}/${video_basename}_${matching_method}_${camera_type}_run${run_idx}.log"

              echo "=================================================="
              echo "Job ID:           $SLURM_ARRAY_TASK_ID"
              echo "Video:            ${VIDEO_PATH}"
              echo "Output Dir:       ${output_dir}"
              echo "Log File:         ${log_file}"
              echo "=================================================="

              ns-process-data video \
                --data "${VIDEO_PATH}" \
                --matching-method "${matching_method}" \
                --feature-type "${feature_type}" \
                --matcher-type "${matcher_type}" \
                --sfm-tool "${sfm_tool}" \
                --camera-type "${camera_type}" \
                --num-downscales "${num_downscales}" \
                --num-frames-target "${NUM_FRAMES}" \
                ${refine_flags} \
                --output-dir "${output_dir}" \
                2>&1 | tee "${log_file}"

              echo "Finished processing: ${output_dir}"

              # ---------------------------
              # Run visualization script
              # ---------------------------
              TRANSFORM_JSON="${output_dir}/transforms.json"
              DEFAULT_IMG="${output_dir}.png"
              TOP_VIEW_IMG="${output_dir}_top.png"

              if [ -f "$TRANSFORM_JSON" ]; then
                echo "Running camera visualization..."
                python "$PLOT_SCRIPT" "$TRANSFORM_JSON" "$DEFAULT_IMG" "$TOP_VIEW_IMG"
                echo "Saved camera views to ${DEFAULT_IMG} and ${TOP_VIEW_IMG}"
              else
                echo "Warning: ${TRANSFORM_JSON} not found. Skipping visualization."
              fi

              echo
            done

          done
        done
      done
    done
  done
done

echo "All combinations completed for: $VIDEO_PATH"
