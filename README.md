# CDC FIFO verification

Simple tests for SoCET's `socetlib_cdc_fifo`, the clock-domain-crossing FIFO in digital-lib (`cdc-fifo/`).

```
rtl/   the FIFO, copied unchanged from digital-lib cdc-fifo/src
tb/    tb_cdc_fifo.sv: the 4 tests
```

## Run

```bash
make             # Verilator 5.020 or newer
make DEPTH=4     # another FIFO depth (default 16)
make questa      # Questa on asicfab
```

## Tests

The write clock is 10 ns and the read clock is 7 ns. Every word written is saved in a queue, and every
read is checked against it.

| Test | Checks |
|---|---|
| `reset` | After reset, `rempty` = 1 and `wfull` = 0 |
| `write_read` | One word goes in and comes out unchanged |
| `fill_drain` | `wfull` = 1 after DEPTH writes. All words come out in order. `rempty` = 1 at the end |
| `simultaneous` | 50 words written and read at the same time, in order |

## Results

All 4 tests pass at `DEPTH` = 1, 4 and 16.

At `DEPTH=2`, `fill_drain` fails: `wfull` never goes high, so a third write overwrites unread data. The
cause is the full check in `socetlib_cdc_fifo.sv`. With `ADDR_WIDTH = 1`, it selects
`rptr_gray_sync2[ADDR_WIDTH-2:0]`, which is the invalid range `[-1:0]`. Verilator warns about it
(`SELRANGE`).
