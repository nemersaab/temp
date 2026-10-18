#!/bin/bash
#SBATCH --job-name=vertex-cover
#SBATCH --account=nas83

#SBATCH --partition=cmps-ai
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32000
#SBATCH --gres=gpu:1 
#SBATCH --time=3-00:00:00

#SBATCH --mail-type=ALL
#SBATCH --mail-user=abc123@mail.aub.edu

## header: log the start date and the node(s) the job landed on
echo "job started on: $(date)"

cd $SLURM_SUBMIT_DIR

python ../../run_on_dataset.py
echo "job ended on: $(date)"
