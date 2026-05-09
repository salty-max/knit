const core = @import("core");

/// Read one bit at `state.bit_offset` of `state.input[state.index]`,
/// big-endian-bit-order (MSB at offset 0). Returns the bit value
/// (0 or 1) without advancing the state. Caller must check
/// EOF before calling.
pub inline fn readBitBe(state: *const core.ParseState) u1 {
    const byte = state.input[state.index];
    const shift: u3 = 7 - state.bit_offset;
    return @truncate((byte >> shift) & 1);
}

/// Read one bit at `state.bit_offset` of `state.input[state.index]`,
/// little-endian-bit-order (LSB at offset 0). Returns 0 or 1.
pub inline fn readBitLe(state: *const core.ParseState) u1 {
    const byte = state.input[state.index];
    return @truncate((byte >> state.bit_offset) & 1);
}

/// Bits remaining from the cursor to end-of-input. Useful for
/// EOF checks before multi-bit reads.
pub fn bitsRemaining(state: *const core.ParseState) usize {
    if (state.index >= state.input.len) return 0;
    const full_bytes = state.input.len - state.index - 1;
    // @as: widen u3 → usize for the arithmetic (always safe — u3 fits trivially).
    return full_bytes * 8 + (8 - @as(usize, state.bit_offset));
}
