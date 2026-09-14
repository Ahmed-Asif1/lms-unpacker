# LMS Unpacker 📦

A lightweight, intelligent PowerShell utility designed to clean up messy ZIP file downloads from university Learning Management Systems (LMS). 

When downloading course materials, LMS platforms often bundle files into deeply nested, unnecessarily complex folder structures. This script automatically finds those ZIP files, extracts the actual documents, flattens the folder hierarchy, and cleans up the leftovers—saving you from endless clicking and dragging.

## Features
- **Smart Targeting:** Scans the directory it is run in and exactly one level deep (perfect for a main `Courses` folder with subject subfolders).
- **Intelligent Deduplication:** Compares SHA256 file hashes. If a downloaded file is identical to one you already have, it safely skips it.
- **Collision Handling:** If a new file shares a name with an existing file but contains *different* content, it automatically renames it (e.g., `lecture_1.pdf`) to prevent data loss.
- **Self-Cleaning:** Automatically deletes the original ZIP file and temporary extraction folders once finished.

## Usage

1. Place `Unpack-Lms.ps1` in your main directory (e.g., `COURSES/`).
2. Download your LMS ZIP files into their respective subject folders (e.g., `COURSES/Calculus/`).
3. Open PowerShell in your main directory and run the script:

```powershell
.\Unpack-Lms.ps1