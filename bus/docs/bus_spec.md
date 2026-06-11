# bus Spec

## 1. Purpose

`bus` provides the wasp1 AHB-Lite interconnect for two masters and the SoC
slave address map.

## 2. Required Masters

The bus must support two AHB-Lite master ports:

```text
m0 = core-side master
m1 = DMA master
```

## 3. Required Slaves

The bus must decode the address map defined in `wasp1_pkg.sv`:

```text
OTP
I-SRAM
D-SRAM
DMA registers
WDG
timer
interrupt controller
UART
I2C
GPIO
default error slave
```

## 4. Protocol Requirements

The bus must support selected AHB-Lite single transfers with:

```text
HADDR
HTRANS
HWRITE
HSIZE
HBURST
HPROT
HMASTLOCK
HWDATA
HRDATA
HREADY
HRESP
```

Unmapped selected transfers must route to the default error slave.

## 5. Arbitration Requirements

When only one master requests, that master must be granted.

When both masters request accepted transfers, arbitration must alternate grants
to avoid starvation.

A non-granted requesting master must see `HREADY=0`. An idle non-granted master
must see `HREADY=1` and `HRESP=OKAY`.

## 6. Error Requirements

The bus must report ERROR for:

```text
unmapped selected transfer
illegal multi-slave response selection
default slave selected active transfer
```

## 7. Verification Requirements

Verification must cover:

```text
all address regions
default decode
inactive decode
single-master grants
both-master arbitration
slave response muxing
ready-low stalls
error response forwarding
fabric integration
```
