v1:
1. Datapath moved from always @(*) to wire + assign
t_re, t_im, bf_e_re/im, bf_o_re/im, w_re_next, w_im_next were computed inside a combinational always @(*) block using reg declarations. They are now declared as wire with explicit assign statements. The intermediate 64-bit products (t_re_full, t_im_full, etc.) are also named wires. Numerically identical — same shift-after-accumulate form as the original.
2. idx_v = idx_u + half instead of base + k + half
idx_u is already base + k, so idx_v was recomputing that sum unnecessarily. Using idx_u directly removes one adder from the register-file read-address path.
3. Register files removed from the reset clause

v2:
Pipelining added
