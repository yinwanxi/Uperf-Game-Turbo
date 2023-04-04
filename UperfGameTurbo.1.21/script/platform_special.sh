#!/system/bin/sh
#
# Copyright (C) 2023 Ham Jin
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Runonce after boot, to speed up the transition of power modes in powercfg
BASEDIR="$(dirname "$(readlink -f "$0")")"
. "$BASEDIR"/pathinfo.sh
. "$BASEDIR"/libcommon.sh
. "$BASEDIR"/libpowercfg.sh
. "$BASEDIR"/libcgroup.sh
. "$BASEDIR"/libsysinfo.sh

# MTK specified
if [ "$(is_mtk)" = "true" ]; then
    if [ -d "/data/adb/modules/asoul_affinity_opt" ];then
        mask_val "0" /sys/module/mtk_fpsgo/parameters/boost_affinity
        mask_val "0" /sys/module/fbt_cpu/parameters/boost_affinity
        mask_val "0" /sys/kernel/fpsgo/minitop/enable
    else
        mask_val "1" /sys/module/mtk_fpsgo/parameters/boost_affinity
        mask_val "1" /sys/module/fbt_cpu/parameters/boost_affinity
        mask_val "1" /sys/kernel/fpsgo/minitop/enable
    fi
    mask_val "0" /sys/module/mtk_fpsgo/parameters/perfmgr_enable
    mask_val "0" /sys/module/mtk_core_ctl/parameters/policy_enable
    # FPSGO thermal
    mask_val "0" /sys/kernel/fpsgo/fbt/thrm_enable
    mask_val "95000" /sys/kernel/fpsgo/fbt/thrm_temp_th
    mask_val "-1" /sys/kernel/fpsgo/fbt/thrm_limit_cpu
    mask_val "-1" /sys/kernel/fpsgo/fbt/thrm_sub_cpu

    # Platform specified Config
    if [ -d "/proc/gpufreqv2" ]; then
        # Disabel auto voltage scaling by MTK
        lock_val "disable" /proc/gpufreqv2/aging_mode
        #Battery current limit
        lock_val "stop 1" /proc/mtk_batoc_throttling/battery_oc_protect_stop
        #echo "killing gpu thermal"
        for i in $(seq 0 10); do
            lock_val "$i 0 0" /proc/gpufreqv2/limit_table
        done
        lock_val "1 1 1" /proc/gpufreqv2/limit_table
        lock_val "3 1 1" /proc/gpufreqv2/limit_table
        lock_val "0" /sys/kernel/ged/hal/fastdvfs_mode
    else
        # Disabel auto voltage scaling by MTK
        lock_val "0" /proc/gpufreq/gpufreq_aging_enable
        # Enable CPU7 for MTK, MT6893 and before(need modify powerhal)
        mask_val "" /sys/devices/system/cpu/sched/cpu_prefer
        mask_val "" /sys/devices/system/cpu/sched/set_sched_isolation
        for i in $(seq 0 9); do
            mask_val "0" "$CPU"/cpu"$i"/sched_load_boost
            mask_val "$i" /sys/devices/system/cpu/sched/set_sched_deisolation
        done
        lock_val "0" /sys/devices/system/cpu/sched/hint_enable
        lock_val "65" /sys/devices/system/cpu/sched/hint_load_thresh
        #force use ppm
        echo "force uperf use PPM"
        lock_val "0 3200000" /proc/ppm/policy/hard_userlimit_max_cpu_freq
        lock_val "0 3200000" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        lock_val "1 3200000" /proc/ppm/policy/hard_userlimit_max_cpu_freq
        lock_val "1 3200000" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        lock_val "2 3200000" /proc/ppm/policy/hard_userlimit_max_cpu_freq
        lock_val "2 3200000" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        lock_val "0" /proc/ppm/cobra_limit_to_budget
        lock_val "0" /proc/ppm/cobra_budget_to_limit
        lock /proc/ppm/policy/*
        lock /proc/ppm/*
        for i in $(seq 0 8); do
            lock_val "$i 0 0" /proc/gpufreq/gpufreq_limit_table
        done
        mask_val "1 1 1" /proc/gpufreq/gpufreq_limit_table
        # MTK-EARA
        mask_val "0" /sys/kernel/eara_thermal/enable
    fi
else
    BUS_DIR="/sys/devices/system/cpu/bus_dcvs"
    for d in $(ls $BUS_DIR); do
        [ ! -f $BUS_DIR/$d/hw_max_freq ] && continue
        MAX_FREQ=$(cat $BUS_DIR/$d/hw_max_freq)

        for df in $(ls $BUS_DIR/$d); do
            lock_val "$MAX_FREQ" "$BUS_DIR/$d/$df/max_freq"
        done
    done

    MIN_PWRLVL=$(($(cat /sys/class/kgsl/kgsl-3d0/num_pwrlevels) - 1))
    mask_val "$MIN_PWRLVL" /sys/class/kgsl/kgsl-3d0/default_pwrlevel
    mask_val "$MIN_PWRLVL" /sys/class/kgsl/kgsl-3d0/min_pwrlevel
    mask_val "0" /sys/class/kgsl/kgsl-3d0/thermal_pwrlevel
    mask_val "0" /sys/class/kgsl/kgsl-3d0/bus_split
    mask_val "0" /sys/class/kgsl/kgsl-3d0/force_bus_on
    mask_val "0" /sys/class/kgsl/kgsl-3d0/force_clk_on
    mask_val "0" /sys/class/kgsl/kgsl-3d0/force_no_nap
    mask_val "0" /sys/class/kgsl/kgsl-3d0/force_rail_on
    mask_val "0" /sys/class/kgsl/kgsl-3d0/throttling
    mask_val "0" /proc/sys/walt/sched_boost
    mask_val "0" /sys/module/metis/parameters/cluaff_control
    mask_val "0" /sys/module/metis/parameters/mi_fboost_enable
    mask_val "0" /sys/module/metis/parameters/mi_freq_enable
    mask_val "0" /sys/module/metis/parameters/mi_link_enable
    mask_val "0" /sys/module/metis/parameters/mi_switch_enable
    mask_val "0" /sys/module/metis/parameters/mi_viptask
    mask_val "0" /sys/module/metis/parameters/mpc_fboost_enable
    mask_val "0" /sys/module/metis/parameters/vip_link_enable
    mask_val "0" /sys/module/perfmgr/parameters/perfmgr_enable
fi
# OPLUS
mask_val "0" /sys/module/cpufreq_bouncing/parameters/enable
mask_val "0" /proc/task_info/task_sched_info/task_sched_info_enable
mask_val "0" /proc/oplus_scheduler/sched_assist/sched_assist_enabled
for i in 0 1 2;do
    mask_val "$i,0,5,3000,3,2000,3,2000" /sys/module/cpufreq_bouncing/parameters/config
done
