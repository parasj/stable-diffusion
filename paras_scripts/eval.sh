#!/bin/bash
#SBATCH --job-name=stable_diffusion
#SBATCH --output=/home/eecs/paras/slurm/%j
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40
#SBATCH --mem=400000
#SBATCH --gres="gpu:1"
#SBATCH --time=125:00:00
#SBATCH --exclude=atlas,blaze,r16,havoc,freddie,steropes,bombe,ace,manchester

# check arguments, first arg is the prompt
# require one arg
[ -z "$PROMPT" ] && { echo "Need to set prompt"; exit 1; }
export PROMPT=${PROMPT:-""}
export HEIGHT=${HEIGHT:-"512"}
export WIDTH=${WIDTH:-"512"}
export CFGSCALE=${CFGSCALE:-"7.5"}
export N=${N:-"6"}
export STEPS=${STEPS:-"50"}


# from https://github.com/moby/moby/issues/2838#issuecomment-385145030
function docker() {
    case "$1" in
        run)
            shift
            if [ -t 1 ]; then # have tty
                command docker run --init -it "$@"
            else
                id=`command docker run -d --init "$@"`
                trap "command docker kill $id" INT TERM SIGINT SIGTERM
                command docker logs --follow $id
            fi
            ;;
        *)
            command docker "$@"
    esac
}

set -e

# set up data
rsync -av --progress models/ldm/stable-diffusion-v1/* /data/$USER/data_cache/stable-diffusion-v1/

echo "python scripts/txt2img.py --outdir /results --plms --precision autocast --n_samples $N -H $HEIGHT -W $WIDTH --scale $CFGSCALE --ddim_steps $STEPS --prompt '${PROMPT}'"

OUT_DIR=/data/$USER/stable_diffusion_results/`date +%Y%m%d%H%M%S`
mkdir -p $OUT_DIR
export PWD=`pwd`
export PROMPT_NO_SPACE=`echo $PROMPT | sed 's/ /_/g'`

trap 'echo "# $BASH_COMMAND"' DEBUG
docker build -t stablediffusion .
docker run -t --rm --init \
  --gpus="device=$CUDA_VISIBLE_DEVICES" \
  --ipc=host \
  --user="$(id -u):$(id -g)" \
  -v "/dev/hugepages:/dev/hugepages" \
  -v "$HOME/.netrc:/home/user/.netrc" \
  -v "/data/$USER/data_cache/stable-diffusion-v1:/app/models/ldm/stable-diffusion-v1" \
  -v "stablediffusion_cache:/home/user/.cache/" \
  -v "$OUT_DIR:/results" \
  --env="PYTHONPATH=/app" \
  stablediffusion python scripts/txt2img.py --outdir /results --precision autocast --plms --n_iter 1 --n_samples $N --scale $CFGSCALE --ddim_steps $STEPS --H $HEIGHT --W $WIDTH --prompt "$PROMPT"
trap - DEBUG

mkdir -p $HOME/stable_diffusion_results/all_prompts
cp $OUT_DIR/grid-0000.png $HOME/stable_diffusion_results/all_prompts/${PROMPT_NO_SPACE}.${N}_${STEPS}_${HEIGHT}x${WIDTH}.png
URL=$(./paras_scripts/imgur.sh $OUT_DIR/grid-0000.png)
~/bin/notify.py "$PROMPT done: $URL"