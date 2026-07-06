set confirm off
set pagination off
target extended-remote localhost:3333
monitor reset halt
info registers
info registers pc
detach
quit
