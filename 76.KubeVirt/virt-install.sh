virt-install \
--name=window10 --ram=4096 --cpu=host --vcpus=1 \
--os-type=windows --os-variant=win10 \
--disk path=windows_10_x64.qcow2,format=qcow2,bus=virtio \
--disk window10
--network network=default,model=virtio \
--graphics vnc,password=test,listen=0.0.0.0