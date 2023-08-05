#!/bin/bash

# This script copies common files between LCG font project repos.

# Copyright (c) 2023 SIL International  (https://www.sil.org)
# Released under the MIT License (http://opensource.org/licenses/MIT)

# Requires:
#   Related project repo clones are all siblings in the file tree.
#   Current working directory is the root folder of one of the related project repo clones

set -e

# Allow a -q to suppress most output

verbose=' -v '
while getopts 'qh' opt; do
  case "$opt" in
    q)
      verbose=
      ;;

    ?|h)
      echo "Usage: $(basename $0) [-q]"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

# Relative path to all repo clones of related projects:

repos=(
    ../font-charis
    ../font-doulos
    ../font-gentium
    ../font-andika
)

# Files to be copied:

# Caution: do not use wildcards unless you are very sure that the 
#    list of matching files is the same for every every repo!
files=(
    source/glyph_data.csv
    source/featureinfo.yaml
    source/opentype/main.feax
    source/opentype/gsub.feax
    source/opentype/gpos.feax
    source/opentype/gdef.feax
    source/opentype/featureinfo.xlsx
    tools/makeromanclasses.py
    tools/psfgenftml.py
    tools/ftml.xsl
    tools/ftml-smith.xsl
    tools/copy_common.sh
	tools/composer/glyph_data_to_gsi.py
	tools/composer/composer.pl
	tools/composer/gsi_dfltvars.xml
	tools/composer/updateTTfeatnames.py
)

# Make sure current working directory is the root one of the above repos
me=$(basename `pwd`)
if [[ ! " ${repos[@]} " =~ " ../$me " ]]; then
    echo "Please cd to root of the repo to use" $(basename "$0")
#    echo "then use ./tools/nameofscript.sh"
    echo "then use ./tools/copy_common.sh"
    exit 2  
fi

 # Iterate through repos and make sure none are behind their default remote.
 # If any are behind, list them and exit
for repo in "${repos[@]}"
do 
  if [[ "$repo" != "../$me" ]]; then
      cd $repo
      git fetch -q
      CURRENTBRANCH=$(git rev-parse --abbrev-ref HEAD)
      BEHINDCOUNT=$(git rev-list --count HEAD..@{u})
      if [[ "$BEHINDCOUNT" -ne "0" ]]; then
          echo "$repo $CURRENTBRANCH is behind remote origin/$CURRENTBRANCH by $BEHINDCOUNT commits."
          # The following line is a nice idea but unfortunately causes problems for
          # Windows users because that particular status command causes the git index to 
          # be re-written in Linux style. Commenting it out until we find a solution
          # [[ -n "$verbose" ]] && git status -s -b --show-stash --ahead-behind --renames
          echo "Please update the $repo repository by doing a git pull"
          NEEDSPULLING="true"
      else
          [[ -n "$verbose" ]] && echo "$repo $CURRENTBRANCH is current with remote origin/$CURRENTBRANCH."
      fi
  fi
done

# Set cwd back to the original repo
cd "../$me"

# Check if we need to ask for some repositories to be pulled before continuing.
if [[ $NEEDSPULLING = "true" ]]; then
    echo -e "\nOne or more related repositories are behind their remote."
    echo "Please bring them up to date first."
    exit 1
else
  # Iterate through repos, using each one (other than myself) as a destination
  for repo in "${repos[@]}"
    do 
        if [[ "$repo" != "../$me" ]]; then
        # Copy files from me to each repo
        echo "Sending files from $me to $repo"
        for file in "${files[@]}"
            do
                if cmp -s "$file" "$repo/$file" ; then
                    # Target copy is already up-to-date; output msg if in verbose mode
                    [[ -n "$verbose" ]] && echo "  already up to date: $repo/$file"
                else
                    # Target file needs updating
                    # Would use the simpler cp --parents here but not supported on macOS
                    mkdir -p `dirname "$repo/$file"` &&  cp $verbose -p "$file" "$_"
                fi
            done
            [[ -n "$verbose" ]] && echo -e "  Done"
        fi
    done
fi
