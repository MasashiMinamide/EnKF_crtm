#!/bin/bash
. util.sh
. config
#DATE_START=201508060000
#DATE_END=201508110000
#0. Calculate nested domain locations (centered over storm) and domain move steps
echo "  Calculating preset nesting..."
#Nested domain location i,j: calculate from tcvatils if first cycle, otherwise get from previous cycle outputs

./calc_ij_parent_start.sh $DATE_START ij_parent_start >& follow_storm.log
#Domain move steps
./calc_domain_moves.sh $DATE_START $DATE_END domain_moves >& follow_storm.log


