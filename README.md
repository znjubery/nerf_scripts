# Nerfstudio Batch Processing Array

SLURM-based scripts for automating NeRF training and pose inspection workflows using Nerfstudio.

## 🔧 Folder Structure

```
nerf_scripts/
├── end2end_nerf_reconstruction/
│   ├── run_nerfstudio_array.sh
│   └── job_array_train_preset_intrinsics.sh
│   └── video_list.txt
├── pose_estimation_checking/
│   ├── camera_pose_display_used_in_bash.py
│   ├── job_array_pose_estimation.sh
│   └── video_list.txt
```

---

## 🚀 Quick Start: End-to-End NeRF Reconstruction

1. **List videos**

   ```bash
   find /path/to/videos -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.mkv" \) > end2end_nerf_reconstruction/video_list.txt
   ```

2. **Run SLURM job**

   ```bash
   cd end2end_nerf_reconstruction
   chmod +x run_nerfstudio_array.sh
   sbatch run_nerfstudio_array.sh
   ```

3. **Output Logs**

   * `logs/array_train_<JOBID>_<TASKID>.out` – stdout
   * `logs/array_train_<JOBID>_<TASKID>.err` – stderr

---

## 🧠 What It Does

### `run_nerfstudio_array.sh` (in `end2end_nerf_reconstruction/`)

Automates per-video processing via a SLURM array:

* **Environment Setup**: Loads CUDA and activates Nerfstudio conda env
* **Video Selection**: Indexes `video_list.txt` using `$SLURM_ARRAY_TASK_ID`
* **Rotation**: Uses `ffmpeg` to rotate last 20s of each clip
* **Preprocessing**: Runs `ns-process-data` to extract frames (\~70)
* **Training**: Uses `ns-train nerfacto` with 30,000 iters
* **Export**:

  * `ns-export pointcloud` → `pcd/<basename>_colmap_pcd/pointcloud/`
  * `ns-export poisson` → `pcd/<basename>_colmap_pcd/poisson/`

---

## 📁 Output Structure

* `processed/<basename>_colmap/` – COLMAP outputs
* `pcd/<basename>_colmap_pcd/pointcloud/` – point clouds (.ply)
* `pcd/<basename>_colmap_pcd/poisson/` – meshes (.ply)

---
## ⚙️ Parameters to Tune
Adjust values as needed for your test or full run.  
* `ffmpeg` rotation: `-sseof -20` (last 20s), `transpose=1` (orientation) 
* Frame extraction: `--num-frames-target 70`
* SLURM array range: `#SBATCH --array=0-N`

## 🔍 Pose Estimation Checking

Folder: `pose_estimation_checking/`

Tools to inspect and compare COLMAP camera pose estimation results using different settings.

### 📂 Contents

* `camera_pose_display_used_in_bash.py` – Visualizes or parses COLMAP pose outputs (can be used in scripts or interactively).
* `job_array_pose_estimation.sh` – SLURM array script for processing multiple videos with various COLMAP settings.
* `video_list.txt` – List of input video paths (generated manually).

### 🚀 Quick Start

1. **List videos**

   ```bash
   find /path/to/videos -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.mkv" \) > pose_estimation_checking/video_list.txt
   ```

2. **Run SLURM Job**

   ```bash
   cd pose_estimation_checking
   chmod +x job_array_pose_estimation.sh
   sbatch job_array_pose_estimation.sh
   ```

### 🧠 What It Does

The script:

* Selects videos from `video_list.txt` using `$SLURM_ARRAY_TASK_ID`
* Runs `ns-process-data` on each video using different COLMAP settings (e.g., with/without `--use-colmap-default-intrinsics`, etc.)
* Logs the COLMAP console output
* Extracts estimated camera poses (extrinsics) to a dedicated folder
* Visualizes the camera trajectories using `camera_pose_display_used_in_bash.py`

### 📌 Goal

To **compare different COLMAP settings** on your video dataset:

* Evaluate which settings produce the most accurate and stable camera poses
* Use visualizations and logs to guide selection of settings for NeRF training

