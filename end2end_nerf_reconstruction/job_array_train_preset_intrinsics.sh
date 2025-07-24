#!/bin/bash
#SBATCH --job-name=ns_train_array
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:a100:1
#SBATCH --cpus-per-task=16
#SBATCH --mem=100G
#SBATCH --partition=nova
#SBATCH --account=baskarg-lab
#SBATCH --time=00:50:00
#SBATCH --array=0-955
#SBATCH --output=logs/array_train_%A_%a.out
#SBATCH --error=logs/array_train_%A_%a.err

# -----------------------
# LOAD MODULES AND ENV
# -----------------------
module load cuda
source activate /work/mech-ai/znjubery/conda_envs_znj/nerfstudio/

# -----------------------
# DEBUG MODE
# -----------------------
DEBUG=true  # Set to false to disable debug output

INPUT_LIST="video_list.txt"
video=$(sed -n "$((SLURM_ARRAY_TASK_ID+1))p" "$INPUT_LIST")

if [ -z "$video" ]; then
    echo "? No video found for SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID, exiting."
    exit 1
fi

if [ ! -f "$video" ]; then
    echo "? Input video file does not exist: $video"
    exit 1
fi

video_name=$(basename "$video")
echo "?? Processing video:"
echo "   +- Full path : $video"
echo "   +- Filename  : $video_name"

if [ "$DEBUG" = true ]; then
    echo "?? DEBUG INFO:"
    echo "   +- SLURM_ARRAY_TASK_ID: $SLURM_ARRAY_TASK_ID"
    echo "   +- Extracted video path: $video"
    echo "   +- Base filename: $video_name"
    echo "   +- Input list: $INPUT_LIST"
fi

# -----------------------
# ROTATE VIDEO
# -----------------------
base=$(basename "$video" .MOV)
rotated_file="${base}_rotated.MOV"  # Save in current directory

if [ "$DEBUG" = true ]; then
    echo "   +- Rotated file target: $rotated_file"
fi

if [ ! -f "$rotated_file" ]; then
    echo "?? Rotating $video -> $rotated_file"
    ffmpeg -y -hide_banner -loglevel error -i "$video" -vf "transpose=1" -c:v libx264 -c:a aac "$rotated_file" > ffmpeg_log_${SLURM_ARRAY_TASK_ID}.txt 2>&1

    if [ ! -f "$rotated_file" ]; then
        echo "? ffmpeg failed to create rotated file: $rotated_file"
        #echo "?? Check ffmpeg_log_${SLURM_ARRAY_TASK_ID}.txt for details."
        exit 1
    fi
else
    echo "? Rotated video already exists: $rotated_file"
fi

# -----------------------
# PREPROCESS (COLMAP)
# -----------------------
base="${base// /_}"
output_dir="processed/${base}_colmap"
mkdir -p "$output_dir"

echo "?? Running ns-process-data..."
ns-process-data video --data "$rotated_file" --output-dir "$output_dir" --num-frames-target 70

# -----------------------
# ADD FIXED CAMERA INTRINSICS TO TRANSFORMS.JSON
# -----------------------
transforms_path="${output_dir}/transforms.json"
if [ -f "$transforms_path" ]; then
    echo "??? Updating camera intrinsics in transforms.json..."
    python3 - <<EOF
import json

path = "$transforms_path"
with open(path) as f:
    data = json.load(f)

fx, fy, cx, cy = 1837.99, 1837.64, 538.95, 756.95
distortion = dict(k1=0.0177, k2=0.1260, p1=-0.0439, p2=-0.0016)

for frame in data.get("frames", []):
    frame.update(dict(fl_x=fx, fl_y=fy, cx=cx, cy=cy, camera_model="OPENCV", **distortion))

data.update(dict(fl_x=fx, fl_y=fy, cx=cx, cy=cy, camera_model="OPENCV", **distortion))

with open(path, "w") as f:
    json.dump(data, f, indent=4)
EOF
else
    echo "?? transforms.json not found in $output_dir — skipping intrinsic update."
fi

# -----------------------
# TRAIN (NERFACTO)
# -----------------------
echo "?? Starting nerfacto training..."
ns-train nerfacto --data "$output_dir" --vis "viewer+wandb" \
    --pipeline.model.predict-normals True \
    --max-num-iterations 30000 \
    --viewer.quit-on-train-completion True

# -----------------------
# EXPORT (POINTCLOUD + POISSON)
# -----------------------
config_file=$(find outputs/$(basename "$output_dir") -type f -name "config.yml" | head -n 1)

if [ -z "$config_file" ]; then
    echo "?? Training complete but config.yml not found. Skipping export."
    exit 0
fi

export_dir="pcd/$(basename "$output_dir")_pcd"
mkdir -p "$export_dir"

echo "?? Exporting pointcloud..."
ns-export pointcloud --load-config "$config_file" \
    --output-dir "$export_dir/pointcloud" \
    --num-points 10000000 --remove-outliers True \
    --normal-method open3d --save-world-frame False \
    --obb_center 0 0 0 --obb_rotation 0 0 0 --obb_scale 1 1 1.5

echo "?? Exporting poisson mesh..."
ns-export poisson --load-config "$config_file" \
    --output-dir "$export_dir/poisson" \
    --remove-outliers True \
    --obb_center 0 0 0 --obb_rotation 0 0 0 --obb_scale 1 1 1.5

echo "? Completed full processing for: $video"
