pub fn alignUpPow2(x: anytype, p: @TypeOf(x)) @TypeOf(x) {
    return (((x) + (p) - 1) & ~((p) - 1));
}
