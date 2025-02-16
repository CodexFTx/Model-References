#!/bin/bash

if [[ $DEBUG -eq 1 ]]; then
    set -x
    env
    #LOG_LEVEL:0 - TRACE, 1 - DEBUG, 2 - INFO, 3 - WARNING, 4 - ERROR, 5 - CRITICAL, 6 - OFF
    export LOG_LEVEL_ALL_HCL=2
else
    export LOG_LEVEL_ALL_HCL=6
fi

if [ -z $BASE_PATH ]; then
	BASE_PATH="$( cd "$(dirname "$(readlink -f ./defaults.cfg)" )" && pwd)"
	PYTHONPATH=${BASE_PATH}:$PYTHONPATH
fi

TRAIN_SCRIPT=${BASE_PATH}/TensorFlow/computer_vision/Resnets/resnet_keras/resnet_ctl_imagenet_main.py
PT_VERSION=`python3 -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")'`
TF_VERSION=`python3 -c "import tensorflow as tf; print(tf.__version__.replace('.', '_'))"`
PATCH_PATH=/usr/local/lib/python${PT_VERSION}/dist-packages/habana_frameworks/tensorflow/tf${TF_VERSION}/lib/habanalabs
# This is required for HW profiling but does not hurt so we add it always
export PYTHONPATH=${PATCH_PATH}:${PYTHONPATH}

# Fixed varaibles, not inherited from launcher
export TF_ALLOW_CONTROL_EDGES_IN_HABANA_OPS=1
export EXPERIMENTAL_PRELOADING=1
export ENABLE_TENSORBOARD=false
export REPORT_ACCURACY_METRICS=true
export DIST_EVAL=true
export ENABLE_DEVICE_WARMUP=true
export TF_DISABLE_MKL=1
export SYNTHETIC_DATA=${SYNTHETIC_DATA}

if [[ $MODELING -eq 1 ]]; then
    ENABLE_CHECKPOINT=true
else
    ENABLE_CHECKPOINT=false
fi
if [[ $TF_BF16_CONVERSION -eq 1 ]]; then
    DATA_TYPE="bf16"
else
    DATA_TYPE="fp32"
fi
if [[  ${NO_EVAL} -eq 1 ]]; then
    SKIP_EVAL=true
else
    SKIP_EVAL=false
fi
if [[ ${USE_LARS_OPTIMIZER} -eq 1 ]]; then
	OPTIMIZER="LARS"
else
	OPTIMIZER="SGD"
fi
if [[ ${USE_HOROVOD} -eq 1 ]]; then
	DIST_EVAL=true
	USE_HOROVOD='--use_horovod'
else
	DIST_EVAL=false
	USE_HOROVOD=''
fi
if [[ ${SYNTHETIC_DATA} -eq 1 ]]; then
	SYNTHETIC_DATA=true
fi
if [[ -n ${NUM_ACCUMULATION_STEPS} ]]; then
	NUM_ACCUMULATION_STEPS="--num_acc_steps=${NUM_ACCUMULATION_STEPS}"
else
	NUM_ACCUMULATION_STEPS=""
fi

if [[ -n ${JPEG_IMAGENET_DIR} ]]; then
    JPEG_IMAGENET_DIR="--jpeg_data_dir=${JPEG_IMAGENET_DIR}"
fi

if [[ $SIGNALING_FROM_GRAPH -eq 1 ]]; then
    export HOROVOD_FUSION_THRESHOLD=0
    export TF_USE_SIGNALING_FROM_ENCAP_OP=1
else
    export TF_USE_SIGNALING_FROM_ENCAP_OP=0
fi

# clear cache
PROC_FS=${PROC_FS:-"/proc"}
sync && echo 3 > $PROC_FS/sys/vm/drop_caches

TRAIN_COMMAND="python3 ${TRAIN_SCRIPT}
    --model_dir=${WORK_DIR}
    --data_dir=${IMAGENET_DIR}
    ${JPEG_IMAGENET_DIR}
    --batch_size=${BATCH_SIZE}
    --distribution_strategy=off
    --num_gpus=0
    --data_format=channels_last
    --train_epochs=${TRAIN_EPOCHS}
    --train_steps=${TRAIN_STEPS}
    --experimental_preloading=${EXPERIMENTAL_PRELOADING}
    --log_steps=${DISPLAY_STEPS}
    --steps_per_loop=${STEPS_PER_LOOP}
    --enable_checkpoint_and_export=${ENABLE_CHECKPOINT}
    --enable_tensorboard=${ENABLE_TENSORBOARD}
    --epochs_between_evals=${EPOCHS_BETWEEN_EVALS}
    --base_learning_rate=${BASE_LEARNING_RATE}
    --warmup_epochs=${WARMUP_EPOCHS}
    --optimizer=${OPTIMIZER}
    --lr_schedule=polynomial
    --label_smoothing=${LABEL_SMOOTH}
    --weight_decay=${WEIGHT_DECAY}
    $NUM_ACCUMULATION_STEPS
    --single_l2_loss_op
    ${USE_HOROVOD}
    --modeling=${MODELING}
    --data_loader_image_type=${DATA_TYPE}
    --dtype=${DATA_TYPE}
    --eval_offset_epochs=${EVAL_OFFSET_EPOCHS}
    --report_accuracy_metrics=${REPORT_ACCURACY_METRICS}
    --dist_eval=${DIST_EVAL}
    --target_accuracy=${STOP_THRESHOLD}
    --enable_device_warmup=${ENABLE_DEVICE_WARMUP}
    --lars_decay_epochs=${LARS_DECAY_EPOCHS}
    --momentum=${LR_MOMENTUM}
    --skip_eval=${SKIP_EVAL}
    --use_synthetic_data=${SYNTHETIC_DATA}
    --dataset_cache=${DATASET_CACHE}
    --num_train_files=${NUM_TRAIN_FILES}
    --num_eval_files=${NUM_EVAL_FILES}
"
echo ${TRAIN_COMMAND}

echo "[run] General Settings:"
echo "[run] RESNET_SIZE" $RESNET_SIZE
echo "[run] IMAGENET_DIR" $IMAGENET_DIR
echo "[run] BATCH_SIZE"  $BATCH_SIZE
echo "[run] NUM_WORKERS" $NUM_WORKERS
echo "[run] TRAIN_EPOCHS" $TRAIN_EPOCHS
echo "[run] TRAIN_STEPS" $TRAIN_STEPS
echo "[run] DISPLAY_STEPS" $DISPLAY_STEPS
echo "[run] USE_LARS_OPTIMIZER" $USE_LARS_OPTIMIZER
echo "[run] CPU_BIND_TYPE" $CPU_BIND_TYPE
echo "[run] EPOCHS_BETWEEN_EVALS" $EPOCHS_BETWEEN_EVALS
echo "[run] TRAIN_AND_EVAL" $TRAIN_AND_EVAL
echo "[run] TF_BF16_CONVERSION" $TF_BF16_CONVERSION
echo "[run] DATASET_CACHE" $DATASET_CACHE
echo "[run] USE_HOROVOD" $USE_HOROVOD
echo
echo "[run] Learning Setting:"
echo "[run] WEIGHT_DECAY" $WEIGHT_DECAY
echo "[run] NUM_ACCUMULATION_STEPS" $NUM_ACCUMULATION_STEPS
echo "[run] LABEL_SMOOTH" $LABEL_SMOOTH
echo "[run] BASE_LEARNING_RATE" $BASE_LEARNING_RATE
echo "[run] WARMUP_EPOCHS" $WARMUP_EPOCHS
echo "[run] USE_MLPERF" $USE_MLPERF
echo "[run] NO_EVAL" $NO_EVAL
echo "[run] STOP_THRESHOLD" $STOP_THRESHOLD
echo "[run] LR_MOMENTUM" $LR_MOMENTUM
echo "[run] EVAL_OFFSET_EPOCHS" $EVAL_OFFSET_EPOCHS
echo "[run] LARS_DECAY_EPOCHS" $LARS_DECAY_EPOCHS
echo "[run] SYNTHETIC_DATA" $SYNTHETIC_DATA

if [[ ! -z $USE_HOROVOD ]] && [[ $CPU_BIND_TYPE == "numa" ]]; then
	LOCAL_SNC_VALUE=$(( OMPI_COMM_WORLD_LOCAL_RANK ))
	if [[ $HLS_TYPE == "HLS2" ]]; then
		export NUMA_MAPPING_DIR=$BASE_PATH
		bash list_affinity_topology_bare_metal.sh
		CPU_RANGE=`cat $NUMA_MAPPING_DIR/.habana_moduleID$LOCAL_SNC_VALUE`
	fi
	LD_PRELOAD=${PRELOAD_PATH} numactl --physcpubind=${CPU_RANGE} ${TRAIN_COMMAND}
else
	LD_PRELOAD=${PRELOAD_PATH} ${TRAIN_COMMAND}
fi
