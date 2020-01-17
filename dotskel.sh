#!/bin/bash
#set -x -e
source ./config.sh

# Compute the thickness of a dot
# parameters:
#   rootdir (directory containing all data for a rater)
#   specimen (numeric identifier, e.g. INDD117673)
#   dot id
#   workdir (root work directory)
function dot_thickness()
{
  # Read the input
  read ROOTDIR SUBJ DOT WROOT args <<< $@

  # In the work directory, create a folder for this dot
  WDIR=$WROOT/thickness/${SUBJ}/${DOT}

  # If the ID includes INDD, drop the INDD from the name, since it's not being
  # used to store the files
  SUBJ2=$(echo $SUBJ | sed -e "s/INDD//")

  # Define some files we will generate
  BNDMESH_RAW=$WDIR/${SUBJ}_${DOT}_bndmesh_raw.vtk
  BNDMESH_SMOOTH=$WDIR/${SUBJ}_${DOT}_bndmesh_smooth.vtk
  SKELETON=$WDIR/${SUBJ}_${DOT}_skeleton.vtk
  SKELTETRA=$WDIR/${SUBJ}_${DOT}_skeltetra.vtk
  BINSEG=$WDIR/${SUBJ}_${DOT}_binary.nii.gz
  THKMAP=$WDIR/${SUBJ}_${DOT}_thkmap.nii.gz
  CTRMAP=$WDIR/${SUBJ}_${DOT}_ctrmap.nii.gz
  DOTBIN=$WDIR/${SUBJ}_${DOT}_dotbin.nii.gz
  DOTMESH=$WDIR/${SUBJ}_${DOT}_dotmesh.vtk
  THKMAP_DOT=$WDIR/${SUBJ}_${DOT}_dot_thkmap.nii.gz
  CTRMAP_DOT=$WDIR/${SUBJ}_${DOT}_dot_ctrmap.nii.gz
  SPHERE=$WDIR/${SUBJ}_${DOT}_sphere.vtk
  THICKFILE=$WDIR/${SUBJ}_${DOT}_thkmax.txt

  # Get the label ID for this dot
  DOTVAL=$(cat ./dots.txt | grep -i " ${DOT}" | awk '{print $1}')

  # Locate the PMDOTS file for this subject
  PMDOTS=$(ls dots/${SUBJ}*_PMDots.nii.gz)
  if [[ ! -f $PMDOTS ]]; then
    echo "ERROR: Missing PMDots.nii.gz file for $SUBJ"
    return
  fi

  # Locate the manual edit file for this dot
  MANEDIT=$(find $ROOTDIR -iname "*${SUBJ2}*_manualedit_${DOT}.nii.gz" | tail -n 1)
  if [[ $MANEDIT && -f $MANEDIT ]]; then

    echo "Using MANUALEDIT $MANEDIT"

    # Create output directory
    mkdir -p $WDIR

    # When manual edit exists, it is used
    c3d "$MANEDIT" -thresh $DOTVAL $DOTVAL 1 0 -type uchar -o $BINSEG
    vtklevelset $BINSEG $BNDMESH_RAW 0.5 

  else

    # When no manual edit found, use the pancake file
    PANCAKE=$(find $ROOTDIR -iname "*${SUBJ2}*_pancake_${DOT}.nii.gz" | tail -n 1)

    if [[ $PANCAKE && -f $PANCAKE ]]; then

      echo "Using PANCAKE $PANCAKE"

      # Create output directory
      mkdir -p $WDIR

      # Pancake needs to be thresholded
      c3d "$PANCAKE" -thresh -inf 0 1 0 -type uchar -o $BINSEG
      vtklevelset "$PANCAKE" $BNDMESH_RAW 0.0

    else

      # Last place we look is the combined segmnetation file
      COMBSEG=$(find "$ROOTDIR/all snakes" -iname "*${SUBJ2}*_*${DOT}*.nii.gz")

      if [[ $COMBSEG && -f $COMBSEG ]]; then

        echo "Using COMBSEG $COMBSEG"

        # Create output directory
        mkdir -p $WDIR

        c3d "$COMBSEG" -thresh $DOTVAL $DOTVAL 1 0 -type uchar -o $BINSEG
        vtklevelset $BINSEG $BNDMESH_RAW 0.5 

      else

        echo "ERROR! No segmentatoin found for subject $SUBJ2, dot '${DOT}'"
        return

      fi

    fi
  fi

  # At this point, we have the binary image and the raw mesh. Smooth it
  mesh_smooth_curv -mu -0.51 -lambda 0.5 -iter 200 $BNDMESH_RAW $BNDMESH_SMOOTH

  # Compute the skeleton of the boundary mesh
  cmrep_vskel -Q $QVORONOI_BINARY -e 10 -p 1.2 \
    -d $SKELTETRA $BNDMESH_SMOOTH $SKELETON

  # Generate a thickness image
  tetfill -c VoronoiRadius $SKELTETRA $BINSEG $THKMAP
  tetfill -c VoronoiCenter $SKELTETRA $BINSEG $CTRMAP

  # Generate a mesh for the dot
  c3d $PMDOTS -thresh $DOTVAL $DOTVAL 1 0 -type uchar -o $DOTBIN
  vtklevelset $DOTBIN $DOTMESH 0.5

  # Filter the thickness and center maps by the dot
  c3d $THKMAP -dup $DOTBIN -int 0 -dilate 1 1x1x1 -reslice-identity -times -o $THKMAP_DOT
  c3d -mcs $CTRMAP $DOTBIN -int 0 -dilate 1 1x1x1 -popas D \
    -foreach -dup -push D -reslice-identity -times -endfor \
    -omc $CTRMAP_DOT
  
  # Compute the thickness for the dot
  skel_tetra_max_thick_sphere $THKMAP_DOT $CTRMAP_DOT $SPHERE > $THICKFILE
}

# Run all dots for a subject
function subj_thickness()
{
  # Read the input
  read ROOTDIR SUBJ WROOT args <<< $@

  # Parse all the available dots
  for dot in $(cat ./dots.txt  | awk '{print $2}'); do

    dot_thickness $ROOTDIR $SUBJ $dot $WROOT

  done
}

# Main entrypoint
cmd=${1?}
shift

if [[ $cmd == "dot" || $cmd == "dot_thickness" ]]; then
  dot_thickness "$@"
elif  [[ $cmd == "subj" || $cmd == "subj_thickness" ]]; then
  subj_thickness "$@"
else
  echo "Unknown command $cmd"
  exit -1
fi
