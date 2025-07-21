# Nerfstudio Batch Processing Array

A SLURM array script to rotate, preprocess, train, and export NeRF models from videos.

## Quick Start

1. **List videos**

   ```bash
   find /path/to/videos -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.mkv" \) > video_list.txt
   ```
2. **Script**

   * Name: `run_nerfstudio_array.sh`
   * Ensure `video_list.txt`, `logs/`, `processed/`, and `pcd/` exist.
   * Adjust SLURM directives (array range, partitions, account).
3. **Submit**

   ```bash
   chmod +x run_nerfstudio_array.sh
   sbatch run_nerfstudio_array.sh
   ```
4. **Logs**

   * `logs/array_train_<JOBID>_<TASKID>.out` (stdout)
   * `logs/array_train_<JOBID>_<TASKID>.err` (stderr)

## Script Overview

`run_nerfstudio_array.sh` automates per-video processing via a SLURM array:

* **SLURM Directives**: Job name, GPU (A100), CPUs (16), memory (100G), time (`00:50:00`), array indices, and log paths.
* **Environment**: Loads `cuda` module and activates the Nerfstudio Conda environment.
* **Video Selection**: Reads the video path from `video_list.txt` using `$SLURM_ARRAY_TASK_ID`.
* **Rotation**: Uses `ffmpeg` to rotate the last 20 seconds of the clip.
* **Preprocess (COLMAP)**: Runs `ns-process-data` to extract \~70 frames.
* **Training (Nerfacto)**: Executes `ns-train nerfacto` for 30,000 iterations with `viewer+wandb`.
* **Export**:

  * **Point Cloud**: `ns-export pointcloud` → `pcd/<basename>_colmap_pcd/pointcloud/`
  * **Poisson Mesh**: `ns-export poisson` → `pcd/<basename>_colmap_pcd/poisson/`

## Output Structure

* `processed/<basename>_colmap/` – COLMAP data
* `pcd/<basename>_colmap_pcd/pointcloud/` – .ply point clouds
* `pcd/<basename>_colmap_pcd/poisson/` – .ply meshes

## Adjust Parameters

ffmpeg rotation: -sseof -20 (last seconds), transpose=1 (orientation)

Frame count: --num-frames-target 70

Array range: #SBATCH --array=0-M or N-N

Adjust values as needed for your test or full run.
