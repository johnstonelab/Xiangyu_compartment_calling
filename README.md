###This is Xiangyu's instruction for high-resolution compartment calling in SJ lab.

#This pipeline utilizes POSSUM, which is a compartment-calling method (developed in doi: 10.1038/s41467-023-38429-1)


###Part1: Environment Set-up. Create a conda environment for compartment calling 

#This is needed for HMS O2 cluster:

#To login an interactive mode, you should adjust this based on your need and situation. The following code is for Xiangyu's O2 account

srun --pty -t 0-10:0 --mem 30G -c 6 --account=johnstone_sej9 -p interactive /bin/bash

module load conda/miniforge3/24.11.3-0

#If you are on your personal laptop, you can directly use conda on your laptop 

which conda

####Note: (you only need to create an environment once) 
git clone https://github.com/johnstonelab/Xiangyu_compartment_calling.git YOUR/DESTINATION

#example
git clone https://github.com/johnstonelab/Xiangyu_compartment_calling.git /n/data1/dfci/pathonc/johnstone/lab/xiangyu_compartment_tutorial/git_hub_version

#enter the directory
cd xiangyu_compartment_possum_whole

mamba env create -f xiangyu_SJlab_compartment_env.yml
####Note: (you only need to create an environment once)



conda info --envs

conda activate xiangyu_SJlab_compartment_env




###Part2: Call possum compartment scores (chrY and chrM are excluded)

#An examplary chromosome resolution file (for --chr-res) is in the cloned repository.

chmod +x xiangyu_compartment_possum_whole/bedGraphToBigWig

bash /path/to/possum_whole/directory/run_possumm_step2.sh \
  --chrom-sizes ... \
  --chr-res ... \
  --hic ... \
  --outdir ... \
  --possum-dir ...git_clone_destination... \
  --norm ...KR_or_others...


##################An example. Don't run it directly on your computer 
#examplary code

#note, if bedGraphToBigWig is not executable, do chmod +x once.
chmod +x /n/data1/dfci/pathonc/johnstone/lab/xiangyu_compartment_tutorial/git_hub_version/xiangyu_compartment_possum_whole/bedGraphToBigWig

bash /n/data1/dfci/pathonc/johnstone/lab/xiangyu_compartment_tutorial/git_hub_version/xiangyu_compartment_possum_whole/run_possumm_step2.sh \
  --chrom-sizes /n/data1/dfci/pathonc/johnstone/lab/xiangyu_compartment_tutorial/mm10.chrom.ordered.sizes \
  --chr-res /n/data1/dfci/pathonc/johnstone/lab/xiangyu_compartment_tutorial/git_hub_version/xiangyu_compartment_possum_whole/chr_resolution_mm10.chrom.ordered \
  --hic /n/data1/dfci/pathonc/johnstone/lab/xiangyu_compartment_tutorial/merge_Ctl_MicroC.hic  \
  --outdir /n/data1/dfci/pathonc/johnstone/lab/xiangyu_compartment_tutorial/test_dir \
  --possum-dir /n/data1/dfci/pathonc/johnstone/lab/xiangyu_compartment_tutorial/git_hub_version/xiangyu_compartment_possum_whole \
  --norm KR
##################An example. Don't run it directly on your computer 



#####Part 3 — Label chr sign (+ / -)
#If the direction of the compartment score is correct, use +; if the direction of the compartment score is the opposite, use -
#see an examplary file chr_sign_mm10.chrom.ordered




#####Part 4 — Generate adjusted bedgraph and bigwig files for further analysis

bash /path/to/possum_whole/directory/run_possumm_step4_adjust.sh \
  --chrom-sizes ... \
  --signs ... \
  --initial-bedgraph ... \
  --possum-dir ...git_clone_destination... \
  --outdir ...

##################An example. Don't run it directly on your computer.

bash /n/data1/dfci/pathonc/johnstone/lab/xiangyu_compartment_tutorial/git_hub_version/xiangyu_compartment_possum_whole/run_possumm_step4_adjust.sh \
  --chrom-sizes /n/data1/dfci/pathonc/johnstone/lab/xiangyu_compartment_tutorial/mm10.chrom.ordered.sizes \
  --signs /n/data1/dfci/pathonc/johnstone/lab/xiangyu_compartment_tutorial/git_hub_version/xiangyu_compartment_possum_whole/chr_sign_mm10.chrom.ordered \
  --initial-bedgraph /n/data1/dfci/pathonc/johnstone/lab/xiangyu_compartment_tutorial/test_dir/bedgraph_initial/merge_Ctl_MicroC.initial.bedgraph \
  --possum-dir /n/data1/dfci/pathonc/johnstone/lab/xiangyu_compartment_tutorial/git_hub_version/xiangyu_compartment_possum_whole \
  --outdir /n/data1/dfci/pathonc/johnstone/lab/xiangyu_compartment_tutorial/test_dir

##################An example. Don't run it directly on your computer.

conda deactivate
