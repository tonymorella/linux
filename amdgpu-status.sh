#!/bin/bash
# FREE OF CHARGE dGPU MONITOR SCRIPT
DAMN_IGPU=$(lspci | grep -E "VGA|3D controller" | head -n 1 | grep -vE "NVIDIA|AMD" |wc -l)
AMDGPU_COUNT=`/usr/bin/lspci -n -v |egrep -ic "0300: 1002"`
NVIDIA_COUNT=`/usr/bin/lspci -n -v |egrep -ic "0300: 10de|0302: 10de"`
TOTAL_COUNT=$( expr $NVIDIA_COUNT + $AMDGPU_COUNT )
API_PORT=3333
CLAYMORE_API=$(echo '{"id":0,"jsonrpc":"2.0","method":"miner_getstat1"}' | nc localhost $API_PORT)
TOTAL_HASH=$(echo "${CLAYMORE_API}"|jq -r '.result[2] | split(";")[0]|tonumber / 1000')

Printer(){
        test -t 1 && echo -e "\033[1m $* \033[0m"
    }
## Kernel, Uptime, IP Address
KERNEL_VERSION=`uname -r`
UPTIME=`uptime -p`
ipAddress=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`

## LOAD DATA TO JSON
function show_amd_stats() {
x=0
while [ $x -lt $1 ]; do
if [ $DAMN_IGPU == 1 ]; then
        devid=$((x+1))
else
        devid=$x
fi
        if [ -f /sys/class/drm/card$devid/device/pp_table ]; then
                GPU_CORE=`cat /sys/class/drm/card$devid/device/pp_dpm_sclk |grep "*" | awk -F  " " '{print $2}' | tr -d 'Mhz' | tr '\n' ' '`
                GPU_MEMORY=`cat /sys/class/drm/card$devid/device/pp_dpm_mclk |grep "*" | awk -F  " " '{print $2}' | tr -d 'Mhz' | tr '\n' ' '`
        fi
#               ONLY IN 4.12+
        if [ -f /sys/kernel/debug/dri/$devid/amdgpu_pm_info ]; then
                GPU_POWER=`cat /sys/kernel/debug/dri/$devid/amdgpu_pm_info |grep '(average GPU)'|awk '{print $1}'| sed 's/ //g'`
                GPU_TEMP=`cat /sys/kernel/debug/dri/$devid/amdgpu_pm_info |grep 'GPU Temperature'|awk '{print $3}'| sed 's/ //g'`
        fi
         if [ -f /sys/class/drm/card$devid/device/hwmon/hwmon?/pwm1 ]; then
                GPU_FANSPEED=$(bc <<< "scale=2; (`cat /sys/class/drm/card$x/device/hwmon/hwmon?/pwm1`/255)*100" | cut -d \. -f 1)
        fi
        if [ -f /sys/kernel/debug/dri/$devid/amdgpu_pm_info ]; then
                GPU_VOLT=$(cat /sys/kernel/debug/dri/$devid/amdgpu_pm_info |grep 'GPU Voltage' | awk '{print $1}'| sed 's/ //g')
        fi
Printer "\tGPU$x:\t CoreClk: ${GPU_CORE}MHz   MemClk: ${GPU_MEMORY}MHz   Power: ${GPU_POWER}W    Voltage: ${GPU_VOLT}mV         Temp: ${GPU_TEMP}C    Fanspeed: ${GPU_FANSPEED}%"

x=$((x+1))
        TOTAL_GPU_PWR="${TOTAL_GPU_PWR} ${GPU_POWER}"
done
        MEM_WATTS=$(($AMDGPU_COUNT * 47))
        TOTAL_WATTS=$(echo $TOTAL_GPU_PWR $MEM_WATTS 50| xargs  | sed -e 's/\ /+/g' | bc)
        MINER_EFFICIENCY=$(echo $TOTAL_HASH $TOTAL_WATTS | awk '{print $1 / $2}')
if [ $AMDGPU_COUNT -gt 0 ]; then
        Printer "\n\tCurrent hashrate: ${TOTAL_HASH} MH/s"
        Printer "\tCurrent AMD Total Powerdraw: ${TOTAL_WATTS}W"
        Printer "\tEfficiency of Claymore Dual ETH Miner: $(printf "%0.2f" ${MINER_EFFICIENCY}) MH per WATT"
fi
}


function show_nvi_stats() {
 x=0
 while [ $x -lt $1 ]; do
        NVI_GET_INFO=$(/usr/bin/nvidia-smi -i $x --query-gpu=clocks.gr,clocks.mem,power.draw,pstate,fan.speed,temperature.gpu --format=csv,noheader,nounits)
        GPU_CORE=$(echo $NVI_GET_INFO | awk -F', ' '{print $1}')
        GPU_MEM=$(echo $NVI_GET_INFO | awk -F', ' '{print $2}')
        GPU_POWER=$(echo $NVI_GET_INFO | awk -F', ' '{print $3}')
        GPU_PSTATE=$(echo $NVI_GET_INFO | awk -F', ' '{print $4}')
        GPU_TEMP=$(echo $NVI_GET_INFO | awk -F', ' '{print $6}')
        GPU_FAN=$(echo $NVI_GET_INFO | awk -F', ' '{print $5}')


Printer "\tGPU$x:\t GfxCLK: ${GPU_CORE}MHz   MemClk: ${GPU_MEM}MHz   Power: ${GPU_POWER}W    Power State: ${GPU_PSTATE}        Temp: ${GPU_TEMP}C    Fanspeed: ${GPU_FAN}%"

x=$((x+1))
        TOTAL_GPU_PWR="${TOTAL_GPU_PWR} ${GPU_POWER}"
done
        TOTAL_WATTS=$(echo $TOTAL_GPU_PWR 50| xargs  | sed -e 's/\ /+/g' | bc)
        MINER_EFFICIENCY=$(echo $TOTAL_HASH $TOTAL_WATTS | awk '{print $1 / $2}')
if [ $NVIDIA_COUNT -gt 0 ]; then
        Printer "\n\tCurrent hashrate: ${TOTAL_HASH} MH/s"
        Printer "\tCurrent NVIDIA Total Powerdraw: ${TOTAL_WATTS}W"
        Printer "\tEfficiency of Claymore Dual ETH Miner: $(printf "%0.2f" ${MINER_EFFICIENCY}) MH per WATT"
fi
}

show_amd_stats $AMDGPU_COUNT
show_nvi_stats $NVIDIA_COUNT

Printer "\n\tShowing total of $TOTAL_COUNT GPU information"
Printer "\tOf which $AMDGPU_COUNT are AMD and $NVIDIA_COUNT are NVIDIA"
Printer "\n\tRig Kernel: $KERNEL_VERSION,\t Rig Uptime: $UPTIME,\t IP:  $ipAddress"
