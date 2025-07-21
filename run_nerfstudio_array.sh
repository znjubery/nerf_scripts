#!/bin/bash
#SBATCH --job-name=ns_train_array
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:a100:1
#SBATCH --cpus-per-task=16
#SBATCH --mem=100G
#SBATCH --partition=nova
#SBATCH --reservation=baskar-202504
#SBATCH --account=baskarg-lab
#SBATCH --time=00:50:00
#SBATCH --array=0-999
#SBATCH --output=logs/array_train_%A_%a.out
#SBATCH --error=logs/array_train_%A_%a.err

# -----------------------
# LOAD MODULES AND ENV
# -----------------------
module load cuda
source activate /work/mech-ai/znjubery/conda_envs_znj/nerfstudio/

INPUT_LIST="video_list.txt"

video=$(sed -n "$((SLURM_ARRAY_TASK_ID+1))p" "$INPUT_LIST")

if [ -z "$video" ]; then
    echo "❌ No video found for SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID, exiting."
    exit 1
fi

echo "🎬 Processing: $video"

# -----------------------
# ROTATE VIDEO
# -----------------------
dir=$(dirname "$video")
base=$(basename "$video" .MOV)
rotated_file="${dir}/${base}_rotated.MOV"

if [ ! -f "$rotated_file" ]; then
    echo "🔄 Rotating $video -> $rotated_file"
    ffmpeg -y -sseof -20 -i "$video" -vf "transpose=1" -c:a copy "$rotated_file"
fi

# -----------------------
# PREPROCESS (COLMAP)
# -----------------------
base="${base// /_}"
output_dir="processed/${base}_colmap"
mkdir -p "$output_dir"

if [ ! -f "$output_dir/dataset.json" ]; then
    echo "📦 Running ns-process-data..."
    ns-process-data video --data "$rotated_file" --output-dir "$output_dir" --num-frames-target 70
fi

# -----------------------
# TRAIN (NERFACTO)
# -----------------------
echo "🚂 Starting nerfacto training..."
ns-train nerfacto --data "$output_dir" --vis "viewer+wandb" \
    --pipeline.model.predict-normals True \
    --max-num-iterations 30000 \
    --viewer.quit-on-train-completion True

# -----------------------
# EXPORT (POINTCLOUD + POISSON)
# -----------------------
config_file=$(find outputs/$(basename "$output_dir") -type f -name "config.yml" | head -n 1)

if [ -z "$config_file" ]; then
    echo "⚠️ Training complete but config.yml not found. Skipping export."
    exit 0
fi

export_dir="pcd/$(basename "$output_dir")_pcd"
mkdir -p "$export_dir"

echo "📦 Exporting pointcloud..."
ns-export pointcloud --load-config "$config_file" \
    --output-dir "$export_dir/pointcloud" \
    --num-points 10000000 --remove-outliers True \
    --normal-method open3d --save-world-frame False \
    --obb_center 0 0 0 --obb_rotation 0 0 0 --obb_scale 1 1 1.5

echo "🧱 Exporting poisson mesh..."
ns-export poisson --load-config "$config_file" \
    --output-dir "$export_dir/poisson" \
    --remove-outliers True \
    --obb_center 0 0 0 --obb_rotation 0 0 0 --obb_scale 1 1 1.5

echo "✅ Completed full processing for: $video"
