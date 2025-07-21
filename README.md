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

## Output Structure

* `processed/<basename>_colmap/` – COLMAP data
* `pcd/<basename>_colmap_pcd/pointcloud/` – .ply point clouds
* `pcd/<basename>_colmap_pcd/poisson/` – .ply meshes

*Adjust paths and test with `--array=0-0` before full run.*
