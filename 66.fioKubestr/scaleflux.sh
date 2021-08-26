#!/bin/bash

# put device name here to run fio test for
# multiple disks in parallel
# example disks=(sfdv0n1 sfdv1n1 nvme0n1 nvme1n1)
disks=(sfdv0n1)

# change the numbers below to control compressibility
# generated by fio. larger number means higher
# compressibility
comp_ratio=60
comp_opt_str="";

if [ "${comp_ratio}" != "" ];
then
    comp_opt_str=" --buffer_compress_chunk=4k --buffer_compress_percentage=${comp_ratio} "
fi

timestamp=`date +%Y%m%d_%H%M%S`

if [ ! -d "${timestamp}" ]; then mkdir ${timestamp}; fi

pid_list=""
for disk in ${disks[@]};
do
    iostat -dxmct 1 ${disk} > ${timestamp}/${disk}.iostat &
    fio ${comp_opt_str} \
        --filename=/dev/${disk} \
        --output=${timestamp}/${disk}.fio \
        ./baseline.fio &
    pid_list="${pid_list} $!"
done

wait ${pid_list}
pkill -9 iostat

pushd ${timestamp}
iofields="1,4-9,14"
cpufields="1-2,4"
for fiostat in `ls *.iostat`
do
    grep -m1 Device $fiostat | sed -r "s/\s+/,/g" | cut -d, -f ${iofields} > ${fiostat}_io.csv
    grep -e sfd -e nvme $fiostat | sed -r "s/\s+/,/g"  | cut -d, -f ${iofields} >> ${fiostat}_io.csv

    grep -m1 avg-cpu $fiostat | sed -r "s/\s+/,/g" | cut -d, -f ${cpufields} > ${fiostat}_cpu.csv
    grep -A1 avg-cpu $fiostat | grep -v \- | sed -r "s/\s+/,/g" | cut -d, -f ${cpufields} >> ${fiostat}_cpu.csv

    paste -d, ${fiostat}_io.csv ${fiostat}_cpu.csv > ${fiostat}.csv
    rm ${fiostat}_io.csv ${fiostat}_cpu.csv
done
popd