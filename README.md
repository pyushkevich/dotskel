DOTS Scripts
============

How to configure
----------------

* Create a file `config.sh`, you can copy it from `config.sh.template`
* Set `PATH` to point to directories containing the binary tools for your platform, e.g., `binaries/macos`
* Set `QVORONOI_BINARY` to point to the `qvoronoi` executable

How to set up directories
-------------------------
You should have the following directory structure:

* In the current directory (where the script is), create a directory `dots` and place all the files in the form `*_PMDots.nii.gz` there.
* For each dots rater, the input data must be organized in a directory that 
  * Contains an `All Snakes` folder with final segmentations (named `*${SUBJ}*_*${DOT}*.nii.gz"`)
  * Contains a `Manual Edits` folder with manual edits (named `*${SUBJ}*_manualedit_${DOT}.nii.gz`)
  * Contains a `Pancake Files` folder with pancake files (named `*${SUBJ}*_pancake_${DOT}.nii.gz`)
* For each dots rater, create an output directory

How to run
----------
To run analysis for one subject, run::

    bash dotskel.sh subj_thickness ROOTDIR SUBJID OUTPUTDIR

where
* `ROOTDIR` is the root input directory for that rater
* `SUBJID` is the subject ID in the format `INDD123456`
* `OUTPUTDIR` is the output directory for your rater

How to view outputs
-------------------
In the work directory, locate the folder::

    thickness/SUBJID/DOTID/

In ParaView, load the following files::

    XXX_bndmesh_raw.vtk      # Boundary of the pancake
    XXX_dotmesh.vtk          # Dot itself
    XXX_sphere.vtk           # Sphere used to measure thickness

The sphere should overlap the dot and be nicely fitted to the pancake.

To get the actual thickness measurement see `XXX_thkmax.txt` in same directory.


How to generate thickness statistics
------------------------------------

To get a table of thicknesses (2xradius) for each subject/dot, run::

    bash dotskel.sh stats_table OUTPUTDIR


